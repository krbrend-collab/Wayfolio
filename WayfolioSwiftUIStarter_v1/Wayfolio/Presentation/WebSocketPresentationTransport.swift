import Foundation

final class WebSocketPresentationTransport: PresentationEventTransport, @unchecked Sendable {
    private let url: URL
    private let session: URLSession
    private let lock = NSLock()
    private var socket: URLSessionWebSocketTask?

    init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func events() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let socket = session.webSocketTask(with: url)
            lock.withLock { self.socket = socket }
            socket.resume()

            let task = Task {
                do {
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        switch message {
                        case .data(let data):
                            continuation.yield(data)
                        case .string(let string):
                            continuation.yield(Data(string.utf8))
                        @unknown default:
                            continue
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                socket.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    func disconnect() async {
        let socket = lock.withLock {
            defer { self.socket = nil }
            return self.socket
        }
        socket?.cancel(with: .normalClosure, reason: nil)
    }
}
