import Foundation
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftSyntax

public struct MatchMacro : ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax,
                                 in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard node.arguments.count == 2 || (node.arguments.count == 1 && node.trailingClosure != nil) else {
            throw MacroError.message("Match macro needs exactly two arguments")
        }
        guard let regex = node.arguments.first?.expression.as(RegexLiteralExprSyntax.self) else {
            throw MacroError.message("First argument needs to be a regex literal")
        }
        guard let body = node.arguments.last?.expression.as(ClosureExprSyntax.self) ?? node.trailingClosure else {
            throw MacroError.message("Second argument needs to be a closure")
        }
        
        let stringifiedRegex = regex.regex.text
        
        return 
            """
            Match(\(raw: regex.description),\n"\(raw: stringifiedRegex)")\(raw: body.description).erased()
            """
    }
    
}
