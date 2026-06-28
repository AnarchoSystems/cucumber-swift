import SwiftSyntax
import SwiftSyntaxMacros

private struct StepMethodMacro {
    private static func regexPatternText(from regexLiteral: String) throws -> String {
        let trimmed = regexLiteral.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MacroError.message("Step macro requires a non-empty regex literal")
        }

        let hashCount = trimmed.prefix { $0 == "#" }.count
        let startSlashIndex = trimmed.index(trimmed.startIndex, offsetBy: hashCount)
        guard startSlashIndex < trimmed.endIndex, trimmed[startSlashIndex] == "/" else {
            throw MacroError.message("Unsupported regex literal form")
        }

        let endHashStart = trimmed.index(trimmed.endIndex, offsetBy: -hashCount)
        guard endHashStart > startSlashIndex else {
            throw MacroError.message("Unsupported regex literal form")
        }

        let closingSlashIndex = trimmed.index(before: endHashStart)
        guard trimmed[closingSlashIndex] == "/" else {
            throw MacroError.message("Unsupported regex literal form")
        }

        let patternStart = trimmed.index(after: startSlashIndex)
        return String(trimmed[patternStart..<closingSlashIndex])
    }

    private static func swiftStringLiteral(_ value: String) -> String {
        var escaped = "\""
        for char in value {
            switch char {
            case "\\":
                escaped += "\\\\"
            case "\"":
                escaped += "\\\""
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                escaped.append(char)
            }
        }
        escaped += "\""
        return escaped
    }

    private enum StepArgKind {
        case none
        case docString
        case table(tableMajor: String, hasHeader: Bool)

        private static func parseRowColMajor(_ expression: ExprSyntax?) throws -> String {
            guard let expression else {
                return ".rowMajor"
            }

            if let member = expression.as(MemberAccessExprSyntax.self) {
                switch member.declName.baseName.text {
                case "rowMajor":
                    return ".rowMajor"
                case "columnMajor":
                    return ".columnMajor"
                default:
                    break
                }
            }

            throw MacroError.message("Unsupported RowColMajor. Use .rowMajor or .columnMajor")
        }

        private static func parseBool(_ expression: ExprSyntax?) throws -> Bool {
            guard let expression else {
                return true
            }

            if let boolLiteral = expression.as(BooleanLiteralExprSyntax.self) {
                return boolLiteral.literal.tokenKind == .keyword(.true)
            }

            throw MacroError.message("Unsupported hasHeader value. Use true or false")
        }

        static func parse(_ expression: ExprSyntax?) throws -> StepArgKind {
            guard let expression else {
                return .none
            }

            if let member = expression.as(MemberAccessExprSyntax.self) {
                switch member.declName.baseName.text {
                case "none":
                    return .none
                case "docString":
                    return .docString
                case "table":
                    return .table(tableMajor: ".rowMajor", hasHeader: true)
                default:
                    break
                }
            }

            if let call = expression.as(FunctionCallExprSyntax.self),
               let calledMember = call.calledExpression.as(MemberAccessExprSyntax.self),
               calledMember.declName.baseName.text == "table"
            {
                let positional = call.arguments.first(where: { $0.label == nil })?.expression
                let labeledHasHeader = call.arguments.first(where: { $0.label?.text == "hasHeader" })?.expression
                let major = try parseRowColMajor(positional)
                let hasHeader = try parseBool(labeledHasHeader)
                return .table(tableMajor: major, hasHeader: hasHeader)
            }

            throw MacroError.message("Unsupported StepArgDef. Use .none, .docString, or .table(...)")
        }
    }

    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.message("Step attribute macros can only be applied to functions")
        }

        guard let args = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = args.first else {
            throw MacroError.message("Step macro requires a static string pattern")
        }

        guard firstArg.expression.as(RegexLiteralExprSyntax.self) != nil else {
            throw MacroError.message("Step macro requires a regex literal pattern, e.g. @Given(/^I have (\\d+) cukes$/)")
        }

        let regexLiteral = firstArg.expression.description
        let regexPattern = try regexPatternText(from: regexLiteral)
        let regexPatternLiteral = swiftStringLiteral(regexPattern)
        let stepArgKind = try StepArgKind.parse(args.dropFirst().first?.expression)

        let funcName = function.name.text
        let isAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrowing = function.signature.effectSpecifiers?.throwsClause != nil

        let parameters = Array(function.signature.parameterClause.parameters)
        let parameterCount = parameters.count
        let usesStepArgument: Bool = {
            switch stepArgKind {
            case .none:
                return false
            case .docString, .table:
                return true
            }
        }()

        if usesStepArgument, parameterCount == 0 {
            throw MacroError.message("StepArgDef requires at least one method parameter")
        }

        let captureParams: [FunctionParameterSyntax] = !usesStepArgument
            ? parameters
            : Array(parameters.dropLast())

        let captureDecodeLines: [String] = captureParams.enumerated().map { idx, param in
            let name = param.secondName?.text ?? param.firstName.text
            let type = param.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let captureIndex = idx + 1
            return """
            let \(name): \(type) = try \(type).decode(from: match.output.\(captureIndex))
            """
        }

        let callArgs = parameters.map { param in
            let externalName = param.firstName.text
            let localName = param.secondName?.text ?? externalName

            if externalName == "_" {
                return localName
            }

            return "\(externalName): \(localName)"
        }.joined(separator: ", ")
        let callPrefix = "\(isThrowing ? "try " : "")\(isAsync ? "await " : "")"
        let needsMatchBinding = !captureDecodeLines.isEmpty

        let decodeCapturesBlock = captureDecodeLines.joined(separator: "\n                ")

        let stepArgumentDecodeBlock: String = {
            guard usesStepArgument else { return "" }
            guard let last = parameters.last else { return "" }

            let name = last.secondName?.text ?? last.firstName.text
            let type = last.type.description.trimmingCharacters(in: .whitespacesAndNewlines)

            switch stepArgKind {
            case .none:
                return ""
            case .docString:

                return """
                guard let docString = stepArgument.docString else {
                    throw CukeError.stepArgumentTypeMismatch(expected: "docString for \(type)")
                }
                let __decoded_\(name): [\(type)] = try \(type).decode(
                    from: docString.content,
                    mediatype: docString.mediaType
                )
                guard let \(name) = __decoded_\(name).first else {
                    throw CukeError.docStringDecodingError("No decoded docstring value for \(type)")
                }
            """
            case let .table(tableMajor, hasHeader):
               
                return """
                guard let dataTable = stepArgument.dataTable else {
                    throw CukeError.stepArgumentTypeMismatch(expected: "dataTable for \(type)")
                }
                let \(name): \(type) = try \(last.type.description.trimmingCharacters(in: .whitespacesAndNewlines)).fromDataTable(
                    dataTable,
                    options: StepArgDecodeOptions(tableMajor: \(tableMajor), hasHeader: \(hasHeader))
                )
            """
            }
        }()

        let stepArgumentTarget = parameters.last?.type.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "argument"
        let preDecodeBody: String = !usesStepArgument
            ? """
                \(decodeCapturesBlock)
            """
            : """
                guard let stepArgument = step.argument else {
                    throw CukeError.stepArgumentMissing(expected: "\(stepArgumentTarget)")
                }
                \(stepArgumentDecodeBlock)
                \(decodeCapturesBlock)
            """

        let invokeBody = "\(callPrefix)self.\(funcName)(\(callArgs))"

        let matchGuard = needsMatchBinding
            ? "guard let match = step.text.wholeMatch(of: \(regexLiteral)) else { return nil }"
            : "guard step.text.wholeMatch(of: \(regexLiteral)) != nil else { return nil }"

        let preDecodeCanThrow = usesStepArgument || !captureDecodeLines.isEmpty

        let matchDecl: String = preDecodeCanThrow
            ? """
            public func match(_ step: PickleStep) throws -> (() async throws -> Void)? {
                \(matchGuard)
                do {
                    \(preDecodeBody)
                    return {
                        \(invokeBody)
                    }
                }
                catch let cukeError as CukeError {
                    throw CukeError.stepDecodingError(step: step.text, regex: regexText, reason: String(describing: cukeError))
                }
                catch {
                    throw CukeError.stepDecodingError(step: step.text, regex: regexText, reason: String(describing: error))
                }
            }
            """
            : """
            public func match(_ step: PickleStep) -> (() async throws -> Void)? {
                \(matchGuard)
                return {
                    \(invokeBody)
                }
            }
            """

        // Build Required(\StateContainer.reporter) storage and a public facade property.
        let keyPath = KeyPathExprSyntax(
            components: KeyPathComponentListSyntax([
                .init(component: .property(KeyPathPropertyComponentSyntax(
                    declName: DeclReferenceExprSyntax(baseName: "StateContainer")
                ))),
                .init(
                    period: .periodToken(),
                    component: .property(KeyPathPropertyComponentSyntax(
                    declName: DeclReferenceExprSyntax(baseName: "reporter")
                    ))
                )
            ])
        )

        let requiredInit = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: "Required"),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax([
                .init(expression: ExprSyntax(keyPath))
            ]),
            rightParen: .rightParenToken()
        )

        let reporterBackingDecl = VariableDeclSyntax(
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax([
                .init(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("_pr_reporter")),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(trailingTrivia: .space),
                        value: ExprSyntax(requiredInit)
                    )
                )
            ])
        )

        let getAccessor = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    .init(item: .expr(ExprSyntax(MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: "_pr_reporter"),
                        period: .periodToken(),
                        declName: DeclReferenceExprSyntax(baseName: "wrappedValue")
                    ))))
                ])
            )
        )

        let setAccessor = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.set),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    .init(item: .expr(ExprSyntax(SequenceExprSyntax(
                        elements: ExprListSyntax([
                            ExprSyntax(MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: "_pr_reporter"),
                                period: .periodToken(),
                                declName: DeclReferenceExprSyntax(baseName: "wrappedValue")
                            )),
                            ExprSyntax(AssignmentExprSyntax(equal: .equalToken())),
                            ExprSyntax(DeclReferenceExprSyntax(baseName: "newValue"))
                        ])
                    ))))
                ])
            )
        )

        let reporterFacadeDecl = VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([
                .init(name: .keyword(.public), trailingTrivia: .space)
            ]),
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax([
                .init(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("reporter")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: IdentifierTypeSyntax(name: "any CukeReporter")
                    ),
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .accessors(AccessorDeclListSyntax([
                            getAccessor,
                            setAccessor
                        ]))
                    )
                )
            ])
        )

        let regexTextDecl = "public var regexText: String { \(regexPatternLiteral) }"
        
        return [
            DeclSyntax(reporterBackingDecl),
            DeclSyntax(reporterFacadeDecl),
            DeclSyntax(stringLiteral: regexTextDecl),
            DeclSyntax(stringLiteral: matchDecl)
        ]
    }
}

public struct GivenAttributeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try StepMethodMacro.expansion(of: node, providingPeersOf: declaration, in: context)
    }
}

public struct WhenAttributeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try StepMethodMacro.expansion(of: node, providingPeersOf: declaration, in: context)
    }
}

public struct ThenAttributeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try StepMethodMacro.expansion(of: node, providingPeersOf: declaration, in: context)
    }
}
