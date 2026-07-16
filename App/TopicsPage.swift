import Algorithms
import ClusterKit
import Common
import Flow
import Foundation
import Logging
import OllamaKit
import SwiftData
import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

fileprivate enum ViewMode: Int {
    case groupList = 0
    case folders = 1
    case list = 2
}

struct TopicsPage: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.getRlamusClient) var getRlamusClient
    @Environment(\.errorHandler) var errorHandler
    @AppStorage("topicsPageViewMode") private var viewMode: ViewMode = .groupList
    @Query(sort: [SortDescriptor<TopicItem>(\.modification, order: .reverse)], animation: .default) var topics: [TopicItem]
    @Query(sort: [SortDescriptor<MemoryItem>(\.creation, order: .reverse)]) var memories: [MemoryItem]

    @State var indexing = true
    @State var takingTime = false

    var body: some View {
        Group {
            switch viewMode {
            case .groupList:
                groupList
            case .folders:
                folders
            case .list:
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                let picker =
                    Picker("View mode", selection: $viewMode) {
                        Label("Group list", systemImage: "rectangle.3.group")
                            .tag(ViewMode.groupList)
                        Label("List", systemImage: "list.bullet")
                            .tag(ViewMode.list)
                        Label("Topic", systemImage: "list.bullet.indent")
                            .tag(ViewMode.folders)
                    }
                #if os(macOS)
                    picker.pickerStyle(.tabs)
                #else
                    Menu("View mode", systemImage: "square.grid.2x2") {
                        picker
                    }
                #endif
            }
        }
        .task {
            takingTime = false
            try? await Task.sleep(for: .seconds(1))
            takingTime = true
        }
        .task {
            let result = await errorHandler.runCatching {
                indexing = true
                let memByID = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
                let rlamusClient = try await getRlamusClient()

                let embeddingModel = memories.max(by: { $0.creation < $1.creation })?.embeddingModel
                let backendName = embeddingModel?.backendName ?? rlamusClient.endpoint.absoluteString
                let outdated = memories.filter { memory in
                    if memory.summary == nil {
                        // it's incomplete
                        return false
                    }
                    if memory.embedding == nil {
                        return true
                    }
                    if let currentModel = memory.embeddingModel,
                       let embeddingModel {
                        return currentModel != embeddingModel
                    }
                    return false
                }
                if !outdated.isEmpty {
                    let (actualEmbeddingModel, items) = try await generateEmbeddings(outdated, client: rlamusClient, modelName: embeddingModel?.name)
                    
                    let embeddingModelItem = if let embeddingModel {
                        embeddingModel
                    } else {
                        try EmbeddingModelItem.fetchOrCreate(name: actualEmbeddingModel, backendName: backendName, context: modelContext)
                    }
                    for item in items {
                        let memory = memByID[item.memoryID]!
                        memory.embedding = item.embedding
                        memory.embeddingModel = embeddingModelItem
                    }
                }

                _ = await getTopics(memories, existing: topics, minSamples: 1, minClusterSize: 2)
                try modelContext.save()
            
            }
            if case let .failure(error) = result {
                appLogger.error("index failed", error: error)
            }
            indexing = false
        }
    }

    var groupList: some View {
        TopicsPageGroupListView(topics: topics, isIndexing: indexing && takingTime)
    }

    var folders: some View {
        TopicsPageFolderView(topics: topics, isIndexing: indexing && takingTime)
    }

    var list: some View {
        TopicsPageListView(memories: memories, isIndexing: indexing && takingTime)
    }
}

struct TopicsPageGroupListView: View {
    let topics: [TopicItem]
    let isIndexing: Bool

    var body: some View {
        List {
            if isIndexing {
                IndexingBanner()
            }
            ForEach(topics) { topic in
                Section {
                    TopicView(topic: topic).listItems
                } header: {
                    TopicNameInput(topic: topic)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

struct TopicsPageFolderView: View {
    @Environment(\.modelContext) var modelContext

    let topics: [TopicItem]
    let isIndexing: Bool

    var body: some View {
        List {
            if isIndexing {
                IndexingBanner()
            }

            Section("User-defined") {
                ForEach(topics.filter { $0.isUserDefined }) { topic in
                    folderFor(topic: topic)
                }
            }

            Section("Automatic") {
                OutlineGroup(topics.filter { !$0.isUserDefined && $0.parent == nil }, children: \.children) { childTopic in
                    folderFor(topic: childTopic)
                }
            }
        }
        .listStyle(.plain)
    }

    func folderFor(topic: TopicItem) -> some View {
        NavigationLink {
            TopicView(topic: topic)
        } label: {
            Label(topic.name ?? String(localized: "Unnamed topic"), systemImage: "puzzlepiece.extension")
                .padding(.vertical, 4)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { @MainActor in
                        modelContext.delete(topic)
                    }
                }
        }
    }
}

struct TopicsPageListView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.errorHandler) var errorHandler

    @State var editMode = false

    let memories: [MemoryItem]
    let isIndexing: Bool

    var body: some View {
        List {
            if isIndexing {
                IndexingBanner()
            }
            ForEach(memories) { memory in
                #if os(macOS)
                    let spacing: CGFloat = 4
                #else
                    let spacing: CGFloat = 12
                #endif
                VStack(alignment: .leading, spacing: spacing) {
                    Link(destination: DeepLink.memory(taskID: memory.taskID).url) {
                        Text(memory.title ?? String(localized: "Unnamed memory"))
                    }
                    .buttonStyle(.plain)

                    EditSection(editMode: editMode, memory: memory)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .toolbar {
            if editMode {
                ToolbarItem(placement: .navigation) {
                    Button("Discard") {
                        withAnimation {
                            editMode.toggle()
                            modelContext.rollback()
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if editMode {
                    Button("Done", systemImage: "checkmark") {
                        _ = errorHandler.runCatching {
                            try modelContext.save()
                            withAnimation {
                                editMode.toggle()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Edit") {
                        withAnimation {
                            editMode.toggle()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private struct EditSection: View {
        @Namespace var acrossEditModes
        @Environment(\.modelContext) var modelContext
        @Environment(\.openURL) var openURL

        @State var newTopicNameBuffer = ""
        @FocusState var newTopicInputFocused

        let editMode: Bool
        let memory: MemoryItem

        var body: some View {
            if editMode {
                ForEach(memory.topics ?? []) { topic in
                    HStack(spacing: 0) {
                        Button {
                            if let offset = memory.topics!.firstIndex(of: topic) {
                                memory.topics!.remove(at: offset)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .padding(.vertical, 4)
                                .padding(.trailing, 8)
                                .background {
                                    Rectangle()
                                        .foregroundStyle(.background)
                                        .opacity(0.01)
                                }
                        }
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                        .disabled(!topic.isUserDefined)

                        Text(topic.name ?? String(localized: "Unnamed topic"))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .matchedGeometryEffect(id: topic.id, in: acrossEditModes)
                }
                HStack(spacing: 0) {
                    Button {
                        _ = addTopic(name: newTopicNameBuffer)
                        newTopicNameBuffer = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .padding(.vertical, 4)
                            .padding(.trailing, 8)
                            .background {
                                Rectangle()
                                    .foregroundStyle(.background)
                                    .opacity(0.01)
                            }
                    }
                    .foregroundStyle(.green)
                    .buttonStyle(.plain)

                    TextField("Unnamed topic", text: $newTopicNameBuffer)
                        .focused($newTopicInputFocused)
                        .onAppear {
                            newTopicNameBuffer = ""
                        }
                        .textFieldStyle(.plain)
                        .onSubmit {
                            _ = addTopic(name: newTopicNameBuffer)
                            newTopicNameBuffer = ""
                            newTopicInputFocused = true
                        }
                }
            } else {
                if let topics = memory.topics, !topics.isEmpty {
                    HFlow {
                        ForEach(topics) { topic in
                            Button {
                                openURL(DeepLink.topic(id: topic.id).url)
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "puzzlepiece.extension")
                                    Text(topic.name ?? String(localized: "Unnamed topic"))
                                }
                            }
                            .buttonStyle(.plain)
                            .matchedGeometryEffect(id: topic.id, in: acrossEditModes)
                        }
                    }
                }
            }
        }

        func addTopic(name: String) -> TopicItem {
            var topicFetcher = FetchDescriptor<TopicItem>(predicate: #Predicate { $0.name == name || (name.isEmpty && $0.name == nil) })
            topicFetcher.fetchLimit = 1

            if let existing = (try? modelContext.fetch(topicFetcher))?.first {
                if existing.isUserDefined {
                    if existing.memories != nil {
                        existing.memories?.append(memory)
                    } else {
                        existing.memories = [memory]
                    }
                    return existing
                } else if let duplicated = memory.topics?.first(where: { $0.name == name || (name.isEmpty && $0.name == nil) }) {
                    return duplicated
                }
            }
            return TopicItem(name: name.isEmpty ? nil : name, isUserDefined: true, memories: [memory])
        }
    }
}

struct TopicView: View {
    let topic: TopicItem
    var body: some View {
        List {
            listItems
        }
        .listStyle(.plain)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Binding(get: {
                topic.name ?? String(localized: "Unnamed topic")
            }, set: { newValue in
                topic.name = newValue
            }))
        #elseif os(macOS)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    TopicNameInput(topic: topic)
                        .foregroundStyle(.primary)
                        .frame(minWidth: 120)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        #endif
    }

    var listItems: some View {
        ForEach(topic.memories?.sorted(by: { $0.creation > $1.creation }) ?? []) { memory in
            Link(destination: DeepLink.memory(taskID: memory.taskID).url) {
                SearchPage.CandidateItem(memory)
            }
            .buttonStyle(.plain)
        }
    }
}

fileprivate struct TopicNameInput: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.errorHandler) var errorHandler

    let topic: TopicItem

    @State private var nameBuffer = ""

    var body: some View {
        TextField("Unnamed topic", text: $nameBuffer)
        #if os(iOS)
            .introspect(.textField, on: .iOS(.v13...)) { textField in
                textField.clearButtonMode = .whileEditing
            }
        #endif
            .textFieldStyle(.plain)
            .submitLabel(.done)
            .onAppear {
                nameBuffer = topic.name ?? ""
            }
            .onChange(of: nameBuffer, initial: false) { _, newValue in
                topic.name = newValue.isEmpty ? nil : newValue
            }
            .onSubmit {
                _ = errorHandler.runCatching {
                    topic.name = nameBuffer.trimmingCharacters(in: .whitespaces)
                    if topic.name?.isEmpty == true {
                        topic.name = nil
                        nameBuffer = String(localized: "Unnamed topic")
                    }
                    try modelContext.save()
                }
            }
    }
}

fileprivate struct IndexingBanner: View {
    var body: some View {
        Text("Indexing your memories, during which this list may be outdated...")
            .listRowSeparator(.hidden)
            .listRowInsets(.bottom, 4)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.background.secondary))
    }
}

fileprivate func generateEmbeddings(_ memoryItems: [MemoryItem], client: RlamusClient, modelName: String? = nil) async throws -> (String, [MemoryEmbeddingItem]) {
    let response = try await client.getEmbeddings(queries: memoryItems.compactMap { $0.summary })
    if let modelName, response.modelName != modelName {
        throw AssertModelNameError(expected: modelName, actual: response.modelName)
    }

    return (
        response.modelName,
        response.embeddings
            .enumerated()
            .map { offset, embedding in MemoryEmbeddingItem(memoryID: memoryItems[offset].id, embedding: embedding) }
    )
}

struct AssertModelNameError: Error, LocalizedError {
    let expected: String
    let actual: String

    var errorDescription: String? {
        String(localized: "Undesired model: expected \"\(expected)\", got \"\(actual)\"")
    }
}
