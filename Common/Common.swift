//
//  Common.swift
//  Common
//
//  Created by Caturday Reed on 2026/6/17.
//

import Foundation
import Realm
import RealmSwift

public func addMemory(url: URL, client: RlamusClient) async throws (CreateTaskError) -> MemoryItem {
    let item = MemoryItem(id: ObjectId.generate())
    item.url = url.absoluteString
    item.creation = .now
    item.taskID = try await client.createTask(url: url.absoluteString)
    return item
}
