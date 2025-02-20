import Foundation
import Yams

// MARK: - Main

@main
struct RunGenSteps {
    
    static func main() throws {
        
        guard CommandLine.arguments.count >= 3 else {
            print("Usage: RunGenSteps <source.yml>... <output.swift>")
            exit(EXIT_FAILURE)
        }
        
        let sources = CommandLine.arguments.dropFirst().dropLast().map{URL(string: $0)!}
        
        let target = URL(string: CommandLine.arguments.last!)!
        
        var stepDict = [String : Steps]()
        
        for source in sources {
            var steps = try YAMLDecoder().decode(Steps.self, from: Data(contentsOf: source))
            if steps.steps == nil {
                steps.steps = []
            }
            if steps.types == nil {
                steps.types = []
            }
            if stepDict[steps.groupName] == nil {
                stepDict[steps.groupName] = steps
                continue
            }
            stepDict[steps.groupName]!.steps!.append(contentsOf: steps.steps!)
            stepDict[steps.groupName]!.types!.append(contentsOf: steps.types!)
        }
        
        var content =
"""
// AUTOMATICALLY GENERATED FILE
// DO NOT MODIFY

import CucumberSwift

"""
        
        for steps in stepDict.values.sorted(by: {$0.groupName < $1.groupName})
        {
            let next =
"""

// MARK: - \(steps.groupName)

public extension Cucumber {
    static var \(steps.groupName) : [any Step] {
        [
            \(steps.steps?.lazy.map{$0.className + "()"}.joined(separator: ", ") ?? "")
        ]
    }
}

\(steps.stepDefs)
\(try steps.typeDefs())
"""
            
            content.append(next)
            
        }
        
        try content.write(to: target, atomically: true, encoding: .utf8)
        
    }
    
}

// MARK: - helper types

struct Steps : Decodable {
    let groupName : String
    var steps : [Step]?
    var types : [TypeDef]?
}

struct Step : Decodable {
    let step : String
    let className : String
    let arguments : [Arg]?
}

struct Arg : Decodable {
    var name : String
    var type : String
}

enum ArgType {
    case string
    case int
    case float
    case other(String)
}

struct TypeDef : Decodable {
    let name : String
    let kind : Kind?
    var cases : [String]?
    var external : Bool?
}

enum Kind : String, Decodable {
    case `enum`
}

// MARK: helper methods

extension Steps {
    
    var stepDefs : String {
        guard let steps, !steps.isEmpty else {return ""}
        let result =
"""
// MARK: - \(groupName) Defs

\(steps.map(\.printed).joined(separator: "\n"))
"""
        return result
    }
    
    func typeDefs() throws -> String {
        guard let types, !types.isEmpty else {return ""}
        let defs = try types.compactMap{try $0.maybeDef()}
        guard !defs.isEmpty else {return ""}
        let result =
"""
    // MARK: - \(groupName) Types

\(defs.joined(separator: "\n"))
"""
        
        return result
    }
}

extension TypeDef {
    
    func maybeDef() throws -> String? {
        
        if let external, external {
            return nil
        }
        
        guard let kind, case .enum = kind else {
            print("Only enums supported for non-external types")
            exit(EXIT_FAILURE)
        }
        
        guard let cases, !cases.isEmpty else {
            print("Non-external enum needs at least one case")
            exit(EXIT_FAILURE)
        }
        
        let result =
"""
public enum \(name) : String {
    case \(cases.map{"\($0)"}.joined(separator: ", "))
}
"""
        return result
    }
    
    
}

extension Step {
    var printed : String {
"""

// MARK: \(className)

public protocol I\(className) : Step {
    func onRecognize(\(arguments?.map{arg in "\(arg.name): \(arg.argType.swiftType)"}.joined(separator: ", ") ?? "")) async throws
}

extension \(className) : I\(className) {
    public var match : some Matcher {
        #Match(#/\(step)/#) {
            // we do a cast here just to suppress warnings......
            try await (self as any I\(className)).onRecognize(\(argInvocations))
        }
    }
}
"""
    }
    
    var argInvocations : String {
        arguments?.enumerated().map{idx, arg in
            switch arg.argType {
            case .string:
                "\(arg.name): String($\(idx))"
            case .int:
                "\(arg.name): Int(String($\(idx)))!"
            case .float:
                "\(arg.name): Float(String($\(idx)))!"
            case .other(let name):
                "\(arg.name): \(name)(rawValue: String($\(idx)))!"
            }
        }.joined(separator: ", ") ?? ""
    }
}

extension Arg {
    var argType : ArgType {
        switch type {
        case "string":
            return .string
        case "int":
            return .int
        case "float":
            return .float
        default:
            return .other(type)
        }
    }
}

extension ArgType {
    var swiftType: String {
        switch self {
        case .string:
            return "String"
        case .int:
            return "Int"
        case .float:
            return "Float"
        case .other(let type):
            return type
        }
    }
}
