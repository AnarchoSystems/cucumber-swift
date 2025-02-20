import Foundation

@attached(accessor) @attached(peer, names: prefixed(__Key_))
public macro ContainerStorage() = #externalMacro(module: "CukeMacros", type: "ContainerStorageMacro")

@freestanding(expression)
public macro Given<First, each T>(_ pattern: Regex<(First, repeat each T)>, closure: @escaping (repeat each T) async throws -> Void) -> ErasedMatcher
= #externalMacro(module: "CukeMacros", type: "MatchMacro")

@freestanding(expression)
public macro And<First, each T>(_ pattern: Regex<(First, repeat each T)>, closure: @escaping (repeat each T) async throws -> Void) -> ErasedMatcher
= #externalMacro(module: "CukeMacros", type: "MatchMacro")

@freestanding(expression)
public macro When<First, each T>(_ pattern: Regex<(First, repeat each T)>, closure: @escaping (repeat each T) async throws -> Void) -> ErasedMatcher
= #externalMacro(module: "CukeMacros", type: "MatchMacro")

@freestanding(expression)
public macro Then<First, each T>(_ pattern: Regex<(First, repeat each T)>, closure: @escaping (repeat each T) async throws -> Void) -> ErasedMatcher
= #externalMacro(module: "CukeMacros", type: "MatchMacro")

@freestanding(expression)
public macro But<First, each T>(_ pattern: Regex<(First, repeat each T)>, closure: @escaping (repeat each T) async throws -> Void) -> ErasedMatcher
= #externalMacro(module: "CukeMacros", type: "MatchMacro")
@freestanding(expression)

// more generic keyword
public macro Match<First, each T>(_ pattern: Regex<(First, repeat each T)>, closure: @escaping (repeat each T) async throws -> Void) -> ErasedMatcher
= #externalMacro(module: "CukeMacros", type: "MatchMacro")
