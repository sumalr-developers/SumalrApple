import Algorithms
import ClusterKit
import Common
import Foundation
import Logging
import SwiftData
import SwiftUI

struct TopicView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.dismiss) var dismiss
    @State var showDeleteConfirmation = false

    let topic: TopicItem

    var body: some View {
        List {
            listItems
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Delete topic", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .confirmationDialog("Delete this topic?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        let result = errorHandler.runCatching {
                            modelContext.delete(topic)
                            try modelContext.save()
                            dismiss()
                        }
                        if case .failure = result {
                            modelContext.rollback()
                        }
                    }
                    Button(role: .cancel) {
                        showDeleteConfirmation = false
                    }
                } message: {
                    Text("This operation cannot be undone. Memories within this topic will not be affacted.")
                }
            }
        }
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
            #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Spacer()
                }
            #endif
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
