
public protocol StateKey {
    associatedtype Value
}

public class StateContainer {
    fileprivate var values : [String : Any] = [:]
    public init() {}
    public subscript<Key : StateKey>(_ key: Key.Type) -> Key.Value? {
        get {
            values[String(describing: key)] as? Key.Value
        }
        set {
            values[String(describing: key)] = newValue
        }
    }
    func inject(into step: Any) throws {
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
public class Scenario<Value> : ContainerValue {
    
    let keyPath : WritableKeyPath<StateContainer, Value?>
    weak var container : StateContainer?
    
    func setContainer(_ container: StateContainer) {
        self.container = container
    }
    
    public init(_ keyPath: WritableKeyPath<StateContainer, Value?>) {
        self.keyPath = keyPath
    }
    
    public var wrappedValue : Value? {
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
public class Required<Value> : ContainerValue {
    
    let keyPath : WritableKeyPath<StateContainer, Value?>
    weak var container : StateContainer?
    
    func setContainer(_ container: StateContainer) throws {
        guard nil != container[keyPath: keyPath] else {
            fatalError("This property is required")
        }
        self.container = container
    }
    
    public init(_ keyPath: WritableKeyPath<StateContainer, Value?>) {
        self.keyPath = keyPath
    }
    
    public var wrappedValue : Value {
        get {
            container![keyPath: keyPath]!
        }
        set {
            container![keyPath: keyPath] = newValue
        }
    }
    
}
