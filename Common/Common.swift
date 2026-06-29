//
//  Common.swift
//  Common
//
//  Created by Caturday Reed on 2026/6/17.
//

import Foundation

public func addMemory(url: URL, client: RlamusClient, registerForNotifications info: NotificationRegistration? = nil) async throws (CreateTaskError) -> MemoryItem {
    let taskID = try await client.createTask(url: url.absoluteString, registerForNotifications: info)
    let item = MemoryItem(url: url.absoluteString, taskID: taskID)
    return item
}
