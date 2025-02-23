import Foundation

public struct Pending : LocalizedError {
    public init() {}
    public var errorDescription: String? {
        "Implementation pending"
    }
    public var failureReason: String? {
        "Step is already declared, but not implemented yet"
    }
}

public struct CukeAssertionFailure : LocalizedError {
    public let errorDescription: String?
    public init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

public func cukeAssert(_ pass: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Test failed!") throws {
    if pass() { return }
    throw CukeAssertionFailure(message())
}

public func cukeAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: @autoclosure () -> String) throws {
    if lhs == rhs { return }
    throw CukeAssertionFailure(message())
}

public func cukeAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) throws {
    try cukeAssertEqual(lhs, rhs, "\(lhs) is not equal to \(rhs)!")
}

@discardableResult
public func cukeAssertNotNil<T>(_ value: T?, _ message: @autoclosure () -> String = "Value is nil!") throws -> T {
    if let value { return value }
    throw CukeAssertionFailure(message())
}

public func cukeAssertNil<T>(_ value: T?, _ message: @autoclosure () -> String = "Value is not nil!") throws {
    if case .none = value { return }
    throw CukeAssertionFailure(message())
}

@discardableResult
public func cukeAssertNoThrow<T>(_ expr: @autoclosure () throws -> T, message: @autoclosure () -> String = "Expression threw an error!") throws -> T {
    do {
        return try expr()
    }
    catch {
        throw CukeAssertionFailure(message() + "\nError: \(error.localizedDescription)")
    }
}

public func cukeAssertThrow<T, E: Error>(_ expr: @autoclosure () throws -> T, _ type: E.Type = E.self, message: @autoclosure () -> String = "Expected an error, but got none!") throws {
    do {
        _ = try expr()
        throw CukeAssertionFailure(message())
    }
    catch let err as E {
        _ = err
    }
    catch {
        throw CukeAssertionFailure("Expression threw error of unexpected type: \(error.localizedDescription)")
    }
}

public func cukeFail(_ message: @autoclosure () -> String = "Test failed!") throws -> Never {
    throw CukeAssertionFailure(message())
}
