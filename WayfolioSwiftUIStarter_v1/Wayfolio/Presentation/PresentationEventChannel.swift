import Foundation

protocol PresentationEventTransport: Sendable {
    func events() -> AsyncThrowingStream<Data, Error>
    func disconnect() async
}

/// A presentation-only stream. Consumers can render or play commands but cannot
/// use this API to write campaign state back to the DM.
actor PresentationEventChannel {
    private let transport: any PresentationEventTransport
    private let decoder: JSONDecoder

    init(transport: any PresentationEventTransport) {
        self.transport = transport
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func events() -> AsyncThrowingStream<PresentationEvent, Error> {
        let transport = transport
        let decoder = decoder

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in transport.events() {
                        try Task.checkCancellation()
                        continuation.yield(try decoder.decode(PresentationEvent.self, from: data))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func disconnect() async {
        await transport.disconnect()
    }
}
