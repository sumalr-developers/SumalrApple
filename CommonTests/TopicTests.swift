import Common
import Foundation
import SwiftData
import Testing

struct TopicTests {
    @Test("Topic merge results are sensible", arguments: [
        // Level 1 nesting
        (
            [[1.0], [1.1], [0.9], [100], [100.1], [99.9]],
            [Node(id: 100, data: [0]), Node(id: 101, data: [3])],
            [Node(id: 100, data: [0, 1, 2]), Node(id: 101, data: [3, 4, 5])]
        ),
        // Level 2 nesting
        (
            [[1.0], [1.1], [0.9], [100], [100.1], [99.9], [100.3], [100.5], [100.7], [100.9], [101], [101.1]],
            [Node(id: 100, data: [0]), Node(id: 101, data: [3], children: [
                Node(id: 102, data: [5]),
                Node(id: 103, data: [8]),
                Node(id: 104, data: [11]),
            ])],
            [Node(id: 100, data: [0, 1, 2]), Node(id: 101, data: [3, 4, 5, 6, 7, 8, 9, 10, 11], children: [
                Node(id: 102, data: [3, 4, 5]),
                Node(id: 103, data: [6, 7, 8]),
                Node(id: 104, data: [9, 10, 11]),
            ])]
        ),
    ])
    func mergeTopics(embeddings: [[Float]], hierarchy: [Node], expected: [Node]) async {
        let memories = embeddings.enumerated().map { offset, fa in
            let r = MemoryItem(url: "uri://\(offset)", taskID: UUID())
            r.embedding = fa
            return r
        }
        let memOffsetById = Dictionary(uniqueKeysWithValues: memories.enumerated().map { offset, mem in (mem.id, offset) })
        var topics = [Int: TopicItem]()
        for node in hierarchy {
            let topic = TopicItem(node: node, memories: memories, map: &topics)
            topics[node.id] = topic
        }
        _ = await getTopics(memories, existing: topics.values, minSamples: 2, minClusterSize: 2)
        func matchNode(topic: TopicItem, matching: Node) {
            let memoryIDs = (topic.memories ?? []).map { memOffsetById[$0.id]! }.sorted()
            #expect(memoryIDs == matching.data.sorted(), "matching node \(matching.id)")
            #expect((topic.children?.count ?? 0) == matching.children.count)
            for child in matching.children {
                let childTopic = topics[child.id]!
                matchNode(topic: childTopic, matching: child)
            }
        }

        for node in expected {
            matchNode(topic: topics[node.id]!, matching: node)
        }
    }
}

extension TopicItem {
    convenience init(node: Node, memories: [MemoryItem], map: inout Dictionary<Int, TopicItem>) {
        self.init(memories: node.data.map { memories[$0] })
        map[node.id] = self
        children = node.children.map { TopicItem(node: $0, memories: memories, map: &map) }
    }
}

final class Node: Sendable {
    let id: Int
    let data: Set<Int>
    let children: [Node]

    init<DataSet, Children>(id: Int, data: DataSet, children: Children = [])
        where DataSet: Sequence, DataSet.Element == Int,
        Children: Sequence, Children.Element == Node {
        self.id = id
        self.data = Set(data)
        self.children = Array(children)
    }
}
