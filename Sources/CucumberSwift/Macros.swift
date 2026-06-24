import Foundation

public enum RowColMajor {
    case rowMajor
    case columnMajor
}

public enum StepArgDef {
    case none
    case docString
    case table(RowColMajor, hasHeader: Bool = true)
    public static var table: StepArgDef { .table(.rowMajor, hasHeader: true) }
}

@attached(accessor) @attached(peer, names: prefixed(__Key_))
public macro ContainerStorage() = #externalMacro(module: "CukeMacros", type: "ContainerStorageMacro")

@attached(peer, names: named(_pr_reporter), named(reporter), named(regexText), named(match))
public macro Given<Output>(_ pattern: Regex<Output>, _ stepArg: StepArgDef = .none) = #externalMacro(module: "CukeMacros", type: "GivenAttributeMacro")

@attached(peer, names: named(_pr_reporter), named(reporter), named(regexText), named(match))
public macro When<Output>(_ pattern: Regex<Output>, _ stepArg: StepArgDef = .none) = #externalMacro(module: "CukeMacros", type: "WhenAttributeMacro")

@attached(peer, names: named(_pr_reporter), named(reporter), named(regexText), named(match))
public macro Then<Output>(_ pattern: Regex<Output>, _ stepArg: StepArgDef = .none) = #externalMacro(module: "CukeMacros", type: "ThenAttributeMacro")