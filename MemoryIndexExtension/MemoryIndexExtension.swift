//
//  MemoryIndexExtension.swift
//  MemoryIndexExtension
//
//  Created by Caturday Reed on 2026/6/20.
//

import CoreSpotlight
import Common
import SwiftData

class MemoryIndexExtension: CSIndexExtensionRequestHandler {

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        Task { @MainActor in
            do {
                try await searchableIndex.deleteAllSearchableItems()
                searchableIndex.beginBatch()
                let entities = try appModelContainer.mainContext
                    .fetch(FetchDescriptor<MemoryItem>())
                    .map { $0.searchableItem }
                try await searchableIndex.indexSearchableItems(entities)
                try await searchableIndex.endBatch(withClientState: Data())
                acknowledgementHandler()
            } catch {
                print("searchableIndex error: \(error)")
            }
        }
    }

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        acknowledgementHandler()
    }
}
