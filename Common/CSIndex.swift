import CoreSpotlight
import SwiftData

@MainActor
public let appMainIndex = CSSearchableIndex(name: "Main")

public protocol CSIndexRecord: Identifiable where ID == Self.Data.CSIndexID {
    associatedtype Data: CSIndexable
    var indexed: Bool { get set }
    
    init(id: Self.ID, indexed: Bool)
}

public protocol CSIndexable {
    associatedtype CSIndexID: Hashable
    var csIndexID: Self.CSIndexID { get }

    var searchableItem: CSSearchableItem { get }
}

public func updateCSIndex<Index>(_ csIndex: CSSearchableIndex,
                                 dataModelContext: ModelContext, dataFetchDescriptor: FetchDescriptor<Index.Data> = .init(),
                                 indexModelContext: ModelContext, indexFetchDescriptor: FetchDescriptor<Index> = .init())
async throws where Index: CSIndexRecord & PersistentModel {
    let index = try indexModelContext.fetch(indexFetchDescriptor)
    let data = try dataModelContext.fetch(dataFetchDescriptor)
    var notIndexed = Set<Index.ID>(data.map { $0.csIndexID })
    var newData = Set(notIndexed)
    for indice in index {
        newData.remove(indice.id)
        if indice.indexed {
            notIndexed.remove(indice.id)
        } else {
            var indice = indice
            indice.indexed = true
        }
    }
    for newDatum in newData {
        indexModelContext.insert(Index(id: newDatum, indexed: true))
    }
    do {
        try await csIndex.indexSearchableItems(data.filter { notIndexed.contains($0.csIndexID) }.map { $0.searchableItem })
    } catch {
        indexModelContext.rollback()
        throw error
    }
    try indexModelContext.save()
}
