import Foundation
import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct ContainerStoragePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [ContainerStorageMacro.self, MatchMacro.self]
}

enum MacroError : LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let string):
            return string
        }
    }
    var failureReason: String? {
        errorDescription
    }
}
