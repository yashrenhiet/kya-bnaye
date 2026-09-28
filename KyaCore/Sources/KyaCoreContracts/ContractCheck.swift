// Executable repository contracts, independent of any test framework: each
// check throws a descriptive ``ContractFailure`` instead of calling XCTest or
// Swift Testing, so any test target can run them. Typical Swift Testing use in
// an adapter's test target:
//
//     @Test(arguments: RepositoryContracts.all())
//     func contract(_ check: ContractCheck<RepositorySet>) async throws {
//         try await check.run(against: { try makeSwiftDataRepositorySet() })
//     }

import Foundation
import KyaCore

/// A contract violation: which check failed, what was wrong, and where.
public struct ContractFailure: Error, Sendable, Equatable, CustomStringConvertible {
    /// The name of the failing ``ContractCheck``.
    public let check: String

    /// What went wrong, with the expected and actual values where relevant.
    public let message: String

    /// The contract source location that detected the failure, as
    /// `file:line`; empty when the subject threw an unexpected error.
    public let location: String

    /// Creates a failure.
    ///
    /// - Parameters:
    ///   - check: The failing check's name.
    ///   - message: What went wrong.
    ///   - location: Where it was detected, as `file:line`.
    public init(check: String, message: String, location: String) {
        self.check = check
        self.message = message
        self.location = location
    }

    /// `"<check>: <message> (<location>)"`, without the location when it is
    /// unknown.
    public var description: String {
        location.isEmpty ? "\(check): \(message)" : "\(check): \(message) (\(location))"
    }
}

/// One named behavioural check, run against a freshly made, empty subject
/// (a repository, or a whole ``RepositorySet``).
public struct ContractCheck<Subject: Sendable>: Sendable, CustomStringConvertible {
    /// What the check verifies, prefixed with the protocol it covers.
    public let name: String

    private let body: @Sendable (Subject) async throws -> Void

    /// Creates a check.
    ///
    /// - Parameters:
    ///   - name: What the check verifies.
    ///   - body: The check; throws on a violation.
    init(_ name: String, _ body: @escaping @Sendable (Subject) async throws -> Void) {
        self.name = name
        self.body = body
    }

    /// The check name, so parameterized tests show readable case names.
    public var description: String { name }

    /// Runs the check against a new subject from `make`.
    ///
    /// Precondition: `make` returns an **empty** subject that shares no state
    /// with subjects returned earlier.
    ///
    /// - Parameter make: Creates the subject under test.
    /// - Throws: ``ContractFailure`` if the subject violates the contract,
    ///   throws an unexpected error, or cannot be made.
    public func run(against make: () async throws -> Subject) async throws(ContractFailure) {
        do {
            try await body(try await make())
        } catch let violation as ContractViolation {
            throw ContractFailure(
                check: name, message: violation.message, location: violation.location)
        } catch {
            throw ContractFailure(
                check: name, message: "unexpected error: \(error)", location: "")
        }
    }

    /// Runs every check, each against its own fresh subject from `make`.
    ///
    /// - Parameters:
    ///   - checks: The checks to run.
    ///   - make: Creates an empty subject (see ``run(against:)``).
    /// - Returns: Every failure, in check order; empty when all checks pass.
    public static func failures(
        of checks: [ContractCheck<Subject>],
        against make: () async throws -> Subject
    ) async -> [ContractFailure] {
        var failures: [ContractFailure] = []
        for check in checks {
            do throws(ContractFailure) {
                try await check.run(against: make)
            } catch {
                failures.append(error)
            }
        }
        return failures
    }

    /// The same check, run against one part of a larger subject.
    ///
    /// - Parameter part: Extracts this check's subject from the larger one.
    /// - Returns: A check over the larger subject, with the same name.
    public func pulledBack<Whole: Sendable>(
        _ part: @escaping @Sendable (Whole) -> Subject
    ) -> ContractCheck<Whole> {
        let body = self.body
        return ContractCheck<Whole>(name) { whole in try await body(part(whole)) }
    }
}

/// A failed expectation inside a check body; ``ContractCheck/run(against:)``
/// turns it into a ``ContractFailure`` carrying the check name.
struct ContractViolation: Error {
    let message: String
    let location: String

    init(_ message: String, file: StaticString, line: UInt) {
        self.message = message
        location = "\(file):\(line)"
    }
}

/// Throws unless `condition` holds.
func expect(
    _ condition: Bool,
    _ message: @autoclosure () -> String,
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    if !condition { throw ContractViolation(message(), file: file, line: line) }
}

/// Throws unless `actual == expected`, reporting both values.
func expectEqual<Value: Equatable>(
    _ actual: Value,
    _ expected: Value,
    _ what: String,
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    try expect(
        actual == expected, "\(what): expected \(expected), got \(actual)", file: file,
        line: line)
}

/// Returns the wrapped value or throws.
func unwrap<Value>(
    _ value: Value?,
    _ what: String,
    file: StaticString = #fileID,
    line: UInt = #line
) throws -> Value {
    guard let value else { throw ContractViolation("\(what) is nil", file: file, line: line) }
    return value
}

/// Throws unless `operation` throws exactly `expected`.
func expectError<Failure: Error & Equatable>(
    _ expected: Failure,
    _ what: String,
    file: StaticString = #fileID,
    line: UInt = #line,
    _ operation: () async throws -> Void
) async throws {
    do {
        try await operation()
    } catch let error as Failure where error == expected {
        return
    } catch {
        throw ContractViolation(
            "\(what): expected \(expected), got \(error)", file: file, line: line)
    }
    throw ContractViolation("\(what): expected \(expected), nothing thrown", file: file, line: line)
}
