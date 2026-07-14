@testable import Common
import Foundation
import Testing

struct TaskTests {
    @Test("Decoding task JSON representations", arguments: [("""
        {
                "id": "f025320a-9cd1-4cce-94cc-8166090cf922",
                "url": "https://elfsternberg.com/blog/axum-sse-remote-heartbeat/",
                "state": {
                    "done": {
                        "title": "Elf Sternberg: Async Rust: Server-Side Events with a Remote Heartbeat",
                        "summary": "This article documents the development of an asynchronous Rust web application."
                    }
                }
        }
        """, Common.RlamusTask(id: UUID(uuidString: "f025320a-9cd1-4cce-94cc-8166090cf922")!, url: URL(string: "https://elfsternberg.com/blog/axum-sse-remote-heartbeat/")!, state: .embedding(title: "Elf Sternberg: Async Rust: Server-Side Events with a Remote Heartbeat", summary: "This article documents the development of an asynchronous Rust web application."))

    ), ("""
        {
                "id": "f025320a-9cd1-4cce-94cc-8166090cf922",
                "url": "https://elfsternberg.com/blog/axum-sse-remote-heartbeat/",
                "state": {
                    "done": {
                        "summary": "This article documents the development of an asynchronous Rust web application."
                    }
                }
        }
        """, Common.RlamusTask(id: UUID(uuidString: "f025320a-9cd1-4cce-94cc-8166090cf922")!, url: URL(string: "https://elfsternberg.com/blog/axum-sse-remote-heartbeat/")!, state: .embedding(title: nil, summary: "This article documents the development of an asynchronous Rust web application."))

    ), ("""
            {
                    "id": "389015FB-F4EB-42B7-8038-83B50D7EFB7C",
                    "url": "https://developer.apple.com/documentation/testing/parameterizedtesting",
                    "state": "init"
            }
        """,
        Common.RlamusTask(id: UUID(uuidString: "389015FB-F4EB-42B7-8038-83B50D7EFB7C")!, url: URL(string: "https://developer.apple.com/documentation/testing/parameterizedtesting")!, state: .`init`),
    )])
    func decoding(json: String, expectedResult: RlamusTask) async throws {
        let decoded = try JSONDecoder().decode(RlamusTask.self, from: json.data(using: .utf8)!)
        #expect(decoded == expectedResult)
    }
}
