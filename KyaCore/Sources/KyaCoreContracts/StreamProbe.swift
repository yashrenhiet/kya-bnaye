import Foundation
import KyaCore

/// Consumes a `watchAll()` stream in the background and hands its elements out
/// one at a time, failing (instead of hanging) when none arrives in time.
/// Dropping the probe cancels the consumer, which ends the subscription.
final class StreamProbe<Row: Sendable>: Sendable {
    private let buffer: StreamBuffer<[Row]>
    private let consumer: Task<Void, Never>
    private let timeout: Duration

    init(_ stream: AsyncThrowingStream<[Row], any Error>, timeout: Duration) {
        let buffer = StreamBuffer<[Row]>()
        self.buffer = buffer
        self.timeout = timeout
        consumer = Task {
            do {
                for try await element in stream {
                    await buffer.append(element)
                }
                await buffer.finish(reason: "stream finished")
            } catch {
                await buffer.finish(reason: "stream threw \(error)")
            }
        }
    }

    deinit {
        consumer.cancel()
    }

    /// The next element.
    func next(file: StaticString = #fileID, line: UInt = #line) async throws -> [Row] {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while true {
            switch await buffer.take() {
            case .element(let element):
                return element
            case .ended(let reason):
                throw ContractViolation(
                    "expected another element, but \(reason)", file: file, line: line)
            case .pending:
                guard clock.now < deadline else {
                    throw ContractViolation(
                        "no stream element within \(timeout)", file: file, line: line)
                }
                try await Task.sleep(for: .milliseconds(2))
            }
        }
    }

    /// Reads until an element satisfies `predicate` (streams may repeat or
    /// coalesce states), failing after `limit` non-matching elements.
    @discardableResult
    func next(
        where predicate: ([Row]) -> Bool,
        limit: Int = 20,
        file: StaticString = #fileID,
        line: UInt = #line
    ) async throws -> [Row] {
        for _ in 0..<limit {
            let element = try await next(file: file, line: line)
            if predicate(element) { return element }
        }
        throw ContractViolation(
            "no matching stream element within \(limit) elements", file: file, line: line)
    }
}

/// What ``StreamBuffer/take()`` found.
private enum Take<Element: Sendable>: Sendable {
    case element(Element)
    case ended(String)
    case pending
}

/// The elements received so far, and a read cursor.
private actor StreamBuffer<Element: Sendable> {
    private var elements: [Element] = []
    private var cursor = 0
    private var endReason: String?

    func append(_ element: Element) {
        elements.append(element)
    }

    func finish(reason: String) {
        endReason = reason
    }

    func take() -> Take<Element> {
        if cursor < elements.count {
            defer { cursor += 1 }
            return .element(elements[cursor])
        }
        if let endReason { return .ended(endReason) }
        return .pending
    }
}
