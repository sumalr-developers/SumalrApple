import Common
import CoreSpotlight
import Foundation
import Logging
import SwiftData

class TaskTracker {
    private let data = TaskTrackerData()
    let client: RlamusClient
    let memoryModelContext: ModelContext
    let csModelContext: ModelContext
    let csIndex: CSSearchableIndex

    init(rlamusClient: RlamusClient, memoryModelContext: ModelContext, csModelContext: ModelContext, csIndex: CSSearchableIndex) {
        client = rlamusClient
        self.memoryModelContext = memoryModelContext
        self.csModelContext = csModelContext
        self.csIndex = csIndex
    }

    func tracked(id: UUID, title: String?, creation: Date) async throws (PollTaskError) -> TrackedTask {
        if let task = data.tasks[id] {
            return task
        }

        let stale: RlamusTask = try await client.pollTask(id: id)
        let tracked = TrackedTask(value: stale, initialTitle: title, creation: creation)
        data.insertTask(tracked, id: id, job: createUpdatingJob(for: tracked))
        return tracked
    }

    func tracked(memory: MemoryItem) -> TrackedTask {
        let derivedTask = TrackedTask(memory: memory)
        if let task = data.tasks[memory.taskID] {
            if case .done = derivedTask.value.state {
                task._value = derivedTask.value
            }
            return task
        }

        if !memory.stale, case .done = derivedTask.value.state {
            return derivedTask
        }

        data.insertTask(derivedTask, id: memory.taskID, job: createUpdatingJob(for: derivedTask))
        return derivedTask
    }
    
    func reset(tracked: TrackedTask) async throws(PollTaskError) {
        if let job = data.jobs[tracked.value.id] {
            job.cancel()
        }
        data.updateJob(for: tracked.value.id, newValue: createUpdatingJob(for: tracked))
    }

    func pauseAll() async {
        for job in data.jobs.values {
            job.cancel()
        }
    }

    func resumeAll() async {
        for (id, task) in data.tasks {
            data.updateJob(for: id, newValue: createUpdatingJob(for: task))
        }
    }

    private func fetchMemory(_ taskID: UUID) throws -> MemoryItem? {
        try MemoryItem.fetch(taskID: taskID, modelContext: memoryModelContext)
    }

    private func createUpdatingJob(for tracked: TrackedTask) -> Task<Void, Never> {
        return Task.detached { [self] in
            var stream = client.streamTask(id: await tracked.value.id).makeAsyncIterator()
            do {
                while let next = try await stream.next() {
                    await MainActor.run {
                        tracked._value = next
                        if let memory = try? fetchMemory(tracked.id) {
                            memory.summary = next.summary
                            if let title = next.title {
                                memory.title = title
                            }
                            try? memoryModelContext.save()
                        }
                    }
                    if case .done = next.state {
                        Task { @MainActor in
                            do {
                                 _ = try await updateCSIndex(self.csIndex, dataModelContext: self.memoryModelContext, indexModelContext: self.csModelContext, indexFetchDescriptor: FetchDescriptor<CSMemory>())
                            } catch {
                                appLogger.error("failed to update CS index", error: error, function: "createUpdatingJob")
                            }
                        }
                        
                        break
                    }
                }
            } catch {
                await MainActor.run {
                    tracked._error = error
                }
            }
        }
    }
}

extension TaskTracker: Equatable {
    static func == (lhs: borrowing TaskTracker, rhs: borrowing TaskTracker) -> Bool {
        Unmanaged.passUnretained(lhs).toOpaque() == Unmanaged.passUnretained(rhs).toOpaque()
    }
}

@MainActor
fileprivate class TaskTrackerData {
    var tasks = [UUID: TrackedTask]()
    var jobs = [UUID: Task<Void, Never>]()

    deinit {
        for job in jobs.values {
            job.cancel()
        }
    }

    func insertTask(_ value: TrackedTask, id: UUID, job: Task<Void, Never>) {
        tasks[id] = value
        jobs[id] = job
    }

    func updateJob(for id: UUID, newValue: Task<Void, Never>) {
        jobs[id] = newValue
    }
}

@Observable
class TrackedTask: Identifiable {
    fileprivate var _value: RlamusTask
    fileprivate var _error: (any Error)?
    let initialTitle: String?
    let creation: Date

    var value: RlamusTask {
        _value
    }

    var title: String? {
        _value.title ?? initialTitle
    }

    var error: (any Error)? {
        _error
    }

    var summary: String? {
        _value.summary
    }

    var id: UUID {
        _value.id
    }

    var url: URL {
        _value.url
    }
    
    var progress: Float {
        let currentStep = switch value.state {
        case .`init`:
            0
        case .scraping:
            1
        case .summarizing:
            2
        case .done:
            3
        case .failed:
            3
        }
        return Float(currentStep) / 3
    }


    init(value: RlamusTask, initialTitle: String? = nil, creation: Date) {
        _value = value
        self.initialTitle = initialTitle
        self.creation = creation
    }

    convenience init(memory: MemoryItem) {
        let initialState: RlamusTaskState
        if let summary = memory.summary {
            initialState = .done(title: memory.title, summary: summary)
        } else {
            initialState = .`init`
        }
        self.init(value: RlamusTask(id: memory.taskID, url: URL(string: memory.url)!, state: initialState), initialTitle: memory.title, creation: memory.creation)
    }
}
