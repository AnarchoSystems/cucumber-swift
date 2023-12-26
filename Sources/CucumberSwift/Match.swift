//
//  Match.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

public protocol Matcher {
    var regexText : String {get}
    func match(_ arg: String) throws -> Any?
    func invoke(with arg: Any) async throws
}

public extension Cucumber {
    
    static func match(_ regex: Regex<Substring>, onRecognize: @escaping () async throws -> Void) -> some Matcher {
        Match0(regex: regex, onRecognize: onRecognize)
    }
    
    static func match<Arg0>(_ regex: Regex<(Substring, Arg0)>, onRecognize: @escaping (Arg0) async throws -> Void) -> some Matcher {
        Match1(regex: regex, onRecognize: onRecognize)
    }
    
    static func match<Arg0, Arg1>(_ regex: Regex<(Substring, Arg0, Arg1)>, onRecognize: @escaping (Arg0, Arg1) async throws -> Void) -> some Matcher {
        Match2(regex: regex, onRecognize: onRecognize)
    }
    
    static func match<Arg0, Arg1, Arg2>(_ regex: Regex<(Substring, Arg0, Arg1, Arg2)>, onRecognize: @escaping (Arg0, Arg1, Arg2) async throws -> Void) -> some Matcher {
        Match3(regex: regex, onRecognize: onRecognize)
    }
    
    static func match<Arg0, Arg1, Arg2, Arg3>(_ regex: Regex<(Substring, Arg0, Arg1, Arg2, Arg3)>, onRecognize: @escaping (Arg0, Arg1, Arg2, Arg3) async throws -> Void) -> some Matcher {
        Match4(regex: regex, onRecognize: onRecognize)
    }
    
    static func match<Arg0, Arg1, Arg2, Arg3, Arg4>(_ regex: Regex<(Substring, Arg0, Arg1, Arg2, Arg3, Arg4)>, onRecognize: @escaping (Arg0, Arg1, Arg2, Arg3, Arg4) async throws -> Void) -> some Matcher {
        Match5(regex: regex, onRecognize: onRecognize)
    }
    
}

struct Match0 : Matcher {
    
    var regexText: String {
        "\(regex)"
    }
    
    let regex : Regex<Substring>
    let onRecognize : () async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        try await onRecognize()
    }
    
}

struct Match1<Arg0> : Matcher {
    
    var regexText: String {
        "\(regex)"
    }
    
    let regex : Regex<(Substring, Arg0)>
    let onRecognize : (Arg0) async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        let (_, arg0) = arg as! (Substring, Arg0)
        try await onRecognize(arg0)
    }
    
}

struct Match2<Arg0, Arg1> : Matcher {
    
    var regexText: String {
        "\(regex)"
    }
    
    let regex : Regex<(Substring, Arg0, Arg1)>
    let onRecognize : (Arg0, Arg1) async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        let (_, arg0, arg1) = arg as! (Substring, Arg0, Arg1)
        try await onRecognize(arg0, arg1)
    }
    
}

struct Match3<Arg0, Arg1, Arg2> : Matcher {
    
    var regexText: String {
        "\(regex)"
    }
    
    let regex : Regex<(Substring, Arg0, Arg1, Arg2)>
    let onRecognize : (Arg0, Arg1, Arg2) async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        let (_, arg0, arg1, arg2) = arg as! (Substring, Arg0, Arg1, Arg2)
        try await onRecognize(arg0, arg1, arg2)
    }
    
}

struct Match4<Arg0, Arg1, Arg2, Arg3> : Matcher {
    
    var regexText: String {
        "\(regex)"
    }
    
    let regex : Regex<(Substring, Arg0, Arg1, Arg2, Arg3)>
    let onRecognize : (Arg0, Arg1, Arg2, Arg3) async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        let (_, arg0, arg1, arg2, arg3) = arg as! (Substring, Arg0, Arg1, Arg2, Arg3)
        try await onRecognize(arg0, arg1, arg2, arg3)
    }
    
}

struct Match5<Arg0, Arg1, Arg2, Arg3, Arg4> : Matcher {
    
    var regexText: String {
        "\(regex)"
    }
    
    let regex : Regex<(Substring, Arg0, Arg1, Arg2, Arg3, Arg4)>
    let onRecognize : (Arg0, Arg1, Arg2, Arg3, Arg4) async throws -> Void
    
    func match(_ arg: String) throws -> Any? {
        try regex.wholeMatch(in: arg)?.output
    }
    
    func invoke(with arg: Any) async throws {
        let (_, arg0, arg1, arg2, arg3, arg4) = arg as! (Substring, Arg0, Arg1, Arg2, Arg3, Arg4)
        try await onRecognize(arg0, arg1, arg2, arg3, arg4)
    }
    
}
