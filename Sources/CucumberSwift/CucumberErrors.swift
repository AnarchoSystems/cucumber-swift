import Foundation

public struct Pending : LocalizedError {
    public init() {}
    public var errorDescription: String {
        "Implementation pending"
    }
    public var failureReason: String {
        "Step is already declared, but not implemented yet"
    }
}

public struct CukeAssertionFailure : LocalizedError {
    public let errorDescription: String
    public init(errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

public func cukeAssert(_ pass: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Test failed!") throws {
    if pass() { return }
    throw CukeAssertionFailure(errorDescription: message())
}

public func cukeAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: @autoclosure () -> String) throws {
    if lhs == rhs { return }
    throw CukeAssertionFailure(errorDescription: message())
}

public func cukeAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) throws {
    try cukeAssertEqual(lhs, rhs, "\(lhs) is not equal to \(rhs)!")
}

public func cukeFail(_ message: @autoclosure () -> String = "Test failed!") throws -> Never {
    throw CukeAssertionFailure(errorDescription: message())
}
