import Foundation
import Gherkin

public protocol StateKey {
    associatedtype Value
}

public extension StateContainer {
    @ContainerStorage var reporter: CukeReporter = DefaultReporter()
}

public final class StateContainer {
    fileprivate var values: [String: Any] = [:]

    public init() {}

    public subscript<Key: StateKey>(_ key: Key.Type) -> Key.Value? {
        get {
            values[String(describing: key)] as? Key.Value
        }
        set {
            values[String(describing: key)] = newValue
        }
    }

    public func inject(into step: Any) throws {
        for (_, child) in Mirror(reflecting: step).children {
            if let cuke = child as? ContainerValue {
                try cuke.setContainer(self)
            }
        }
    }
}

protocol ContainerValue {
    func setContainer(_ container: StateContainer) throws
}

@propertyWrapper
public class Scenario<Value>: ContainerValue {

    let keyPath: WritableKeyPath<StateContainer, Value?>
    weak var container: StateContainer?

    func setContainer(_ container: StateContainer) {
        self.container = container
    }

    public init(_ keyPath: WritableKeyPath<StateContainer, Value?>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value? {
        get {
            container![keyPath: keyPath]
        }
        set {
            guard nil != newValue else {
                fatalError("Cannot unset scenario values")
            }
            container![keyPath: keyPath] = newValue
        }
    }
}

@propertyWrapper
public class Required<Value>: ContainerValue {
    private let optionalKeyPath: WritableKeyPath<StateContainer, Value?>?
    private let requiredKeyPath: WritableKeyPath<StateContainer, Value>?
    private let isAvailable: (StateContainer) -> Bool
    weak var container: StateContainer?

    func setContainer(_ container: StateContainer) throws {
        guard isAvailable(container) else {
            fatalError("This property is required")
        }
        self.container = container
    }

    public init(_ keyPath: WritableKeyPath<StateContainer, Value?>) {
        optionalKeyPath = keyPath
        requiredKeyPath = nil
        isAvailable = { state in state[keyPath: keyPath] != nil }
    }

    public init(_ keyPath: WritableKeyPath<StateContainer, Value>) {
        optionalKeyPath = nil
        requiredKeyPath = keyPath
        isAvailable = { _ in true }
    }

    public var wrappedValue: Value {
        get {
            guard let container else {
                fatalError("Container not injected")
            }
            if let requiredKeyPath {
                return container[keyPath: requiredKeyPath]
            }
            guard let optionalKeyPath, let value = container[keyPath: optionalKeyPath] else {
                fatalError("This property is required")
            }
            return value
        }
        set {
            guard var container else {
                fatalError("Container not injected")
            }
            if let requiredKeyPath {
                container[keyPath: requiredKeyPath] = newValue
            }
            else if let optionalKeyPath {
                container[keyPath: optionalKeyPath] = newValue
            }
        }
    }
}

