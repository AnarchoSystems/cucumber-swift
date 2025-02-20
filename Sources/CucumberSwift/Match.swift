public protocol Matcher {
    var regexText: String { get }
    func match(_ arg: String) throws -> Any?
    func invoke(with arg: Any) async throws
}

func dropFirstArg<First, each Others>(_ closure: @escaping (repeat each Others) async throws -> Void) -> (First, repeat each Others) async throws -> Void {
    return { (_: First, pack: repeat each Others) -> Void in
        try await closure(repeat each pack)
    }
}

public func Match<First, each Others>(_ regex: Regex<(First, repeat each Others)>, _ text: String, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, regexText: text, onRecognize: dropFirstArg(onRecognize))
}

public extension Matcher {
    func erased() -> ErasedMatcher {
        .init(wrapped: self)
    }
}

struct _Match<T>: Matcher {
    let regex: Regex<T>
    let regexText: String
    let onRecognize: (T) async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        guard let tuple = arg as? T else {
            fatalError("Type mismatch")
        }
        try await onRecognize(tuple)
    }
}

public struct ErasedMatcher : Matcher {
    let wrapped : any Matcher
}

public extension ErasedMatcher {
    
    var regexText: String {
        wrapped.regexText
    }
    
    func match(_ arg: String) throws -> Any? {
        try wrapped.match(arg)
    }
    
    func invoke(with arg: Any) async throws {
        try await wrapped.invoke(with: arg)
    }
    
}
