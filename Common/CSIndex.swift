import CoreSpotlight
import SwiftData

@MainActor
public let appMainIndex = CSSearchableIndex(name: "Main")

public protocol CSIndexRecord {
    associatedtype Data: CSIndexable
    var dataToken: DefaultHistoryToken { get }
    var date: Date { get }

    init(dataToken: DefaultHistoryToken, date: Date)
}

public protocol CSIndexable {
    associatedtype CSIndexID: Hashable
    var csIndexID: Self.CSIndexID { get }

    var searchableItem: CSSearchableItem { get }
}

public func updateCSIndex<Index>(_ csIndex: CSSearchableIndex,
                                 dataModelContext: ModelContext,
                                 indexModelContext: ModelContext,
                                 indexFetchDescriptor: FetchDescriptor<Index> = .init())
async throws -> DefaultHistoryToken?
    where Index: CSIndexRecord & PersistentModel, Index.Data: PersistentModel {
    let indexes = try indexModelContext.fetch(indexFetchDescriptor)
    var latestIndex: Index?
    for index in indexes {
        if let l = latestIndex, index.date > l.date {
            latestIndex = index
        } else {
            latestIndex = index
        }
    }

    if let latestIndex {
        // incremental index
        let last = latestIndex.dataToken
        let historyFetcher = HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate {
            $0.token > last
        })
        
        let transactions = try dataModelContext.fetchHistory(historyFetcher)
        guard let lastTransaction = transactions.last else {
            // no changes
            return nil
        }

        var toBeIndexed = Set<PersistentIdentifier>()
        var toBeRemoved = Set<PersistentIdentifier>()
        for transaction in transactions {
            for change in transaction.changes {
                switch change {
                case let .insert(historyInsert):
                    if historyInsert is any HistoryInsert<Index.Data> {
                        toBeIndexed.insert(historyInsert.changedPersistentIdentifier)
                    }
                case let .update(historyUpdate):
                    if historyUpdate is any HistoryUpdate<Index.Data> {
                        toBeIndexed.insert(historyUpdate.changedPersistentIdentifier)
                    }
                case let .delete(historyDelete):
                    if historyDelete is any HistoryDelete<Index.Data> {
                        toBeIndexed.remove(historyDelete.changedPersistentIdentifier)
                        toBeRemoved.insert(historyDelete.changedPersistentIdentifier)
                    }
                @unknown default:
                    fatalError()
                }
            }
        }

        let models = try dataModelContext.fetch(FetchDescriptor<Index.Data>())
        let modelsToBeIndexed = models.filter { toBeIndexed.contains($0.id) }
        let modelsToBeRemoved = models.filter { toBeRemoved.contains($0.id) }
        csIndex.beginBatch()
        try await csIndex.indexSearchableItems(modelsToBeIndexed.map { $0.searchableItem })
        try await csIndex.deleteSearchableItems(withIdentifiers: modelsToBeRemoved.map { $0.searchableItem.uniqueIdentifier })
        try await csIndex.endBatch(withClientState: .init())

        indexModelContext.delete(latestIndex)
        indexModelContext.insert(Index(dataToken: lastTransaction.token, date: .now))
        try? indexModelContext.save()
        return lastTransaction.token
    } else {
        // full scale index
        try await csIndex.deleteAllSearchableItems()
        let models = try dataModelContext.fetch(FetchDescriptor<Index.Data>())
        try await csIndex.indexSearchableItems(models.map { $0.searchableItem })
        
        var latestTransactionFetcher = HistoryDescriptor<DefaultHistoryTransaction>(sortBy: [.init(\.token, order: .reverse)])
        latestTransactionFetcher.fetchLimit = 1
        let latestTransaction = try dataModelContext.fetchHistory(latestTransactionFetcher).first
        if let latestTransaction {
            indexModelContext.insert(Index(dataToken: latestTransaction.token, date: .now))
            try indexModelContext.save()
        }
        return latestTransaction?.token
    }
}
