import Common
import Foundation
import Logging
import SwiftData

class TaskTracker {
    private let data = TaskTrackerData()
    let getClient: @Sendable () async throws (CancellationError) -> RlamusClient
    let modelContext: ModelContext

    init(getClient: @escaping @Sendable () async throws (CancellationError) -> RlamusClient, modelContext: ModelContext) {
        self.getClient = getClient
        self.modelContext = modelContext
    }
    
    func tracked(id: UUID, title: String?, creation: Date) async throws (TaskTrackingError) -> TrackedTask {
        if let task = data.tasks[id] {
            return task
        }

        let client: RlamusClient
        do {
            client = try await getClient()
        } catch {
            throw .clientCreationCanceled
        }
        let stale: RlamusTask
        do throws (PollTaskError) {
            stale = try await client.pollTask(id: id)
        } catch {
            throw .poll(error)
        }
        let tracked = TrackedTask(value: stale, initialTitle: title, creation: creation)
        data.insertTask(tracked, id: id, job: createUpdatingJob(for: tracked, tracker: self))
        return tracked
    }

    func tracked(memory: MemoryItem) -> TrackedTask {
        if let task = data.tasks[memory.taskID] {
            return task
        }

        let initialState: RlamusTaskState
        if let summary = memory.summary {
            initialState = .done(title: memory.title, summary: summary)
        } else {
            initialState = .`init`
        }
        appLogger.debug("created new tracked task for \(memory.taskID)")
        let task = TrackedTask(value: RlamusTask(id: memory.taskID, url: URL(string: memory.url)!, state: initialState), initialTitle: memory.title, creation: memory.creation)
        if case .done = initialState {
            return task
        }
        
        data.insertTask(task, id: memory.taskID, job: createUpdatingJob(for: task, tracker: self))
        return task
    }

    func pauseAll() async {
        for job in data.jobs.values {
            job.cancel()
        }
    }

    func resumeAll() async throws (TaskTrackingError) {
        for (id, task) in data.tasks {
            data.updateJob(for: id, newValue: createUpdatingJob(for: task, tracker: self))
        }
    }
}

enum TaskTrackingError: Error {
    case clientCreationCanceled
    case poll(PollTaskError)
}

func createUpdatingJob(for tracked: TrackedTask, tracker: TaskTracker) -> Task<Void, Never> {
    return Task.detached {
        let client: RlamusClient
        do {
            client = try await tracker.getClient()
        } catch {
            await MainActor.run {
                tracked._error = error
            }
            return
        }
        var stream = client.streamTask(id: await tracked.value.id).makeAsyncIterator()
        do {
            while let next = try await stream.next() {
                await MainActor.run {
                    tracked._value = next
                    if let memory = try? MemoryItem.fetch(taskID: tracked.value.id, modelContext: tracker.modelContext) {
                        memory.summary = next.summary
                        if let title = next.title {
                            memory.title = title
                        }
                        try? tracker.modelContext.save()
                    }
                }
                if case .done = next.state {
                    do {
                        // delete from server for privacy
                        try await client.deleteTask(id: tracked.id)
                    } catch {
                        let taskID = await tracked.id.uuidString
                        await appLogger.info("failed to delete after pull", error: error, metadata: ["taskID": .string(taskID)])
                    }
                }
            }
        } catch {
            await MainActor.run {
                tracked._error = error
            }
        }
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
class TrackedTask {
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

    init(value: RlamusTask, initialTitle: String? = nil, creation: Date) {
        _value = value
        self.initialTitle = initialTitle
        self.creation = creation
    }
}
