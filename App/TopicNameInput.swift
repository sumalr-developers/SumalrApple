import Common
import Foundation
import SwiftData
import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct TopicNameInput: View {
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
