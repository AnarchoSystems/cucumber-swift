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

func Given<First, each Others>(_ regex: Regex<(First, repeat each Others)>, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, onRecognize: dropFirstArg(onRecognize))
}
func And<First, each Others>(_ regex: Regex<(First, repeat each Others)>, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, onRecognize: dropFirstArg(onRecognize))
}
func When<First, each Others>(_ regex: Regex<(First, repeat each Others)>, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, onRecognize: dropFirstArg(onRecognize))
}
func Then<First, each Others>(_ regex: Regex<(First, repeat each Others)>, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, onRecognize: dropFirstArg(onRecognize))
}
func But<First, each Others>(_ regex: Regex<(First, repeat each Others)>, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, onRecognize: dropFirstArg(onRecognize))
}
// "more generic keyword"
func Match<First, each Others>(_ regex: Regex<(First, repeat each Others)>, onRecognize: @escaping (repeat each Others) async throws -> Void) -> some Matcher {
    _Match(regex: regex, onRecognize: dropFirstArg(onRecognize))
}


struct _Match<T>: Matcher {
    let regex: Regex<T>
    let onRecognize: (T) async throws -> Void
    
    var regexText: String {
        "\(regex)"
    }
    
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
