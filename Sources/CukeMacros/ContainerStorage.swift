import Foundation
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftSyntax

public struct ContainerStorageMacro: AccessorMacro, PeerMacro {
    
    struct ExpData {
        let keyName : String
        let typeName : String
        let initializerValue : String?
    }
    
    static func extract(from decl: some DeclSyntaxProtocol) throws -> ExpData {
        guard let decl = decl.as(VariableDeclSyntax.self),
              let theBinding = decl.bindings.first,
                decl.bindings.count == 1 else {
            throw MacroError.message("@ContainerStorage can only be applied to member variables.")
        }
        
        guard decl.bindingSpecifier.text == "var" else {
            throw MacroError.message("@ContainerStorage must be used with 'var' keyword.")
        }
        
        guard let identifier = theBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            throw MacroError.message("@ContainerStorage can only be applied to single variable member variables.")
        }
        
        guard var typeDescr = theBinding.typeAnnotation?.type.description else {
            throw MacroError.message("@ContainerStorage requires a type annotation")
        }
        
        if let match = try #/Optional<(.*)>/#.wholeMatch(in: typeDescr) {
            typeDescr = String(match.output.1)
        }
        else if let match = try #/(.*)\?/#.wholeMatch(in: typeDescr) {
            typeDescr = String(match.output.1)
        }
        
        let keyName = "__Key_" + identifier
        return ExpData(keyName: keyName, typeName: typeDescr, initializerValue: theBinding.initializer?.value.description)
    }
    
    public static func expansion(of node: AttributeSyntax,
                                 providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        
        let expData = try extract(from: declaration)
        
        return [
            """
            struct \(raw: expData.keyName) : StateKey {
                typealias Value = \(raw: expData.typeName)
            }
            """
        ]
    }
    
    
    public static func expansion(of node: AttributeSyntax,
                                 providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        
        
        let expData = try extract(from: declaration)
        
        return [
                """
                get { self[\(raw: expData.keyName).self]\(raw: expData.initializerValue.map{"?? " + $0} ?? "") }
                set { self[\(raw: expData.keyName).self] = newValue }
                """
        ]
        
    }
}
