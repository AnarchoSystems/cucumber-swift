import SwiftSyntax
import SwiftSyntaxMacros

public struct CukeExpectMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let positionalArguments = node.arguments.filter { $0.label == nil }

        guard let condition = positionalArguments.first?.expression else {
            throw MacroError.message("#cukeExpect requires a condition")
        }

        let message = positionalArguments.dropFirst().first?.expression.description
            ?? "\"Expectation failed\""
        let reporter = node.arguments.first(where: { $0.label?.text == "reporter" })?.expression.description
            ?? "reporter"
        let file = node.arguments.first(where: { $0.label?.text == "file" })?.expression.description
            ?? "#fileID"
        let line = node.arguments.first(where: { $0.label?.text == "line" })?.expression.description
            ?? "#line"

        return """
        ({
            #if canImport(Testing)
            #expect(\(raw: condition.description), ({
                let __cukeExpectationMessage = \(raw: message)
                \(raw: reporter).reportAssertionFailure(message: __cukeExpectationMessage, file: \(raw: file), line: \(raw: line))
                return Comment(rawValue: __cukeExpectationMessage)
            })())
            #else
            if !(\(raw: condition.description)) {
                let __cukeExpectationMessage = \(raw: message)
                \(raw: reporter).reportAssertionFailure(message: __cukeExpectationMessage, file: \(raw: file), line: \(raw: line))
                preconditionFailure(__cukeExpectationMessage)
            }
            #endif
        })()
        """
    }
}