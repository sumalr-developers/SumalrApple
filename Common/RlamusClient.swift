import EventSource
import Foundation
import HTTPTypes
import HTTPTypesFoundation

public struct RlamusClient: Sendable {
    public var endpoint: URL
    public var urlSession: URLSession

    public init(endpoint: URL, urlSession: URLSession = .shared) {
        self.endpoint = endpoint
        self.urlSession = urlSession
    }

    public func verify() async throws (VerifyError) {
        if endpoint.scheme == nil {
            throw .invalidEndpoint
        }
        let request = HTTPRequest(url: endpoint)
        let (data, res): (Data, HTTPResponse)
        do {
            (data, res) = try await urlSession.data(for: request)
        } catch {
            throw .io(error)
        }
        guard res.status == .ok else {
            throw .unexpectedStatus(res.status)
        }

        guard let signatures = String(data: data, encoding: .utf8)?.split(separator: " "),
              signatures.first == "rlamus-server",
              let apiSignature = signatures.first(where: { $0.starts(with: "api:") }),
              let apiVersion = Int(apiSignature[apiSignature.index(apiSignature.startIndex, offsetBy: 4)...])
        else {
            throw .invalidServer(compatVersion: nil)
        }
        guard apiVersion == 1 else {
            throw .invalidServer(compatVersion: nil)
        }
    }

    public func createTask(url: String) async throws (CreateTaskError) -> UUID {
        var request = HTTPRequest(method: .post, url: endpoint.appending(component: "task"))
        request.headerFields[.contentType] = "application/x-www-form-urlencoded"

        let (data, res): (Data, HTTPResponse)
        do {
            (data, res) = try await urlSession.upload(for: request, from: "url=\(url.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)".data(using: .utf8)!)
        } catch {
            throw .io(error)
        }

        if res.status != .created {
            throw CreateTaskError.unexpectedStatus(res.status)
        }

        guard let stringData = String(data: data, encoding: .ascii),
              let uuid = UUID(uuidString: stringData) else {
            throw .invalidResponse
        }
        return uuid
    }

    public func pollTask(id: UUID) async throws (PollTaskError) -> RlamusTask? {
        let request = HTTPRequest(url: endpoint.appending(components: "task", id.uuidString))
        let (data, res): (Data, HTTPResponse)
        do {
            (data, res) = try await urlSession.data(for: request)
        } catch {
            throw .io(error)
        }

        if res.status == .notFound {
            throw .notFound
        }

        do {
            return try JSONDecoder().decode(RlamusTask.self, from: data)
        } catch {
            throw .parse(error)
        }
    }

    public func streamTask(id: UUID) -> AsyncThrowingStream<RlamusTask, Error> {
        AsyncThrowingStream<RlamusTask, Error> { continuation in
            Task.detached {
                let request = HTTPRequest(url: endpoint.appending(components: "task", id.uuidString, "sse"))
                let (stream, res): (URLSession.AsyncBytes, HTTPResponse)
                do {
                    (stream, res) = try await urlSession.bytes(for: request)
                } catch {
                    continuation.finish(throwing: StreamTaskError.io(error))
                    return
                }
                if res.status != .ok {
                    continuation.finish(throwing: StreamTaskError.unexpectedStatus(res.status))
                    return
                }

                let decoder = JSONDecoder()
                do {
                    for try await event in stream.events {
                        switch event.event {
                        case "update":
                            let task = try decoder.decode(RlamusTask.self, from: Data(event.data.utf8))
                            continuation.yield(with: .success(task))
                        default:
                            break
                        }
                    }
                } catch {
                    continuation.finish(throwing: StreamTaskError.invalidResponse)
                }
            }
        }
    }

    func deleteTask(id: UUID) async throws (DeleteTaskError) {
        let request = HTTPRequest(method: .delete, url: endpoint.appending(components: "task", id.uuidString))
        let (_, res): (Data, HTTPResponse)
        do {
            (_, res) = try await urlSession.data(for: request)
        } catch {
            throw .io(error)
        }
        if res.status == .notFound {
            throw .notFound
        } else if res.status != .ok {
            throw .unexpectedStatus(res.status)
        }
    }
}

public enum VerifyError: Error {
    case io(any Error)
    case invalidEndpoint
    case unexpectedStatus(HTTPResponse.Status)
    case invalidServer(compatVersion: Int?)
}

public enum CreateTaskError: Error {
    case io(any Error)
    case unexpectedStatus(HTTPResponse.Status)
    case invalidResponse
}

public enum PollTaskError: Error {
    case io(any Error)
    case notFound
    case parse(any Error)
}

public enum StreamTaskError: Error {
    case io(any Error)
    case unexpectedStatus(HTTPResponse.Status)
    case invalidResponse
}

public enum DeleteTaskError: Error {
    case io(any Error)
    case notFound
    case unexpectedStatus(HTTPResponse.Status)
}
