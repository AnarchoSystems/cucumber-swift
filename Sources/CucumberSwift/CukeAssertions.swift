import Foundation
#if canImport(Testing)
import Testing
#endif

public enum CukeAssertionFailure: LocalizedError {
    case failed(message: String)

    public var errorDescription: String? {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

private func _cukeAssert(
    _ result: Bool,
    reporter: CukeReporter,
    message: @autoclosure () -> String,
    file: StaticString,
    line: UInt
) {
    let renderedMessage = result ? nil : message()
    if let renderedMessage {
        reporter.reportAssertionFailure(message: renderedMessage, file: file, line: line)
    }
    #if canImport(Testing)
    #expect(result)
    #else
    guard result else {
        preconditionFailure(renderedMessage ?? message())
    }
    #endif
}

public extension Step {
    func cukeExpect(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String = "Expectation failed",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        _cukeAssert(condition(), reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectEqual<T: Equatable>(
        _ lhs: @autoclosure () -> T,
        _ rhs: @autoclosure () -> T,
        _ message: @autoclosure () -> String = "Expected values to be equal",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let left = lhs()
        let right = rhs()
        _cukeAssert(left == right, reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectNotEqual<T: Equatable>(
        _ lhs: @autoclosure () -> T,
        _ rhs: @autoclosure () -> T,
        _ message: @autoclosure () -> String = "Expected values to differ",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let left = lhs()
        let right = rhs()
        _cukeAssert(left != right, reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectNil<T>(
        _ value: @autoclosure () -> T?,
        _ message: @autoclosure () -> String = "Expected value to be nil",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        _cukeAssert(value() == nil, reporter: reporter, message: message(), file: file, line: line)
    }

    @discardableResult
    func cukeExpectNotNil<T>(
        _ value: @autoclosure () -> T?,
        _ message: @autoclosure () -> String = "Expected value to be non-nil",
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> T {
        let actual = value()
        _cukeAssert(actual != nil, reporter: reporter, message: message(), file: file, line: line)
        return actual!
    }

    func cukeExpectContains<S: Sequence>(
        _ sequence: @autoclosure () -> S,
        _ element: @autoclosure () -> S.Element,
        _ message: @autoclosure () -> String = "Expected sequence to contain element",
        file: StaticString = #fileID,
        line: UInt = #line
    ) where S.Element: Equatable {
        let sequenceValue = Array(sequence())
        let elementValue = element()
        _cukeAssert(sequenceValue.contains(elementValue), reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectEmpty<S: Sequence>(
        _ sequence: @autoclosure () -> S,
        _ message: @autoclosure () -> String = "Expected sequence to be empty",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        _cukeAssert(Array(sequence()).isEmpty, reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectNotEmpty<S: Sequence>(
        _ sequence: @autoclosure () -> S,
        _ message: @autoclosure () -> String = "Expected sequence to be non-empty",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        _cukeAssert(!Array(sequence()).isEmpty, reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectGreaterThan<T: Comparable>(
        _ lhs: @autoclosure () -> T,
        _ rhs: @autoclosure () -> T,
        _ message: @autoclosure () -> String = "Expected lhs to be greater than rhs",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let left = lhs()
        let right = rhs()
        _cukeAssert(left > right, reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectLessThan<T: Comparable>(
        _ lhs: @autoclosure () -> T,
        _ rhs: @autoclosure () -> T,
        _ message: @autoclosure () -> String = "Expected lhs to be less than rhs",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let left = lhs()
        let right = rhs()
        _cukeAssert(left < right, reporter: reporter, message: message(), file: file, line: line)
    }

    func cukeExpectApproximatelyEqual<T: BinaryFloatingPoint>(
        _ lhs: @autoclosure () -> T,
        _ rhs: @autoclosure () -> T,
        tolerance: T = .ulpOfOne * 10,
        _ message: @autoclosure () -> String = "Expected values to be approximately equal",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let left = lhs()
        let right = rhs()
        _cukeAssert(abs(left - right) <= tolerance, reporter: reporter, message: message(), file: file, line: line)
    }
}
