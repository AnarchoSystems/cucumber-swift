public protocol Hook {
    func shouldRun(_ tags: [String]) -> Bool
    func before() async throws
    func after() async throws
}

public extension Hook {
    func shouldRun(_ tags: [String]) -> Bool {true}
    func before() {}
    func after() {}
}

public protocol Hooks {
    /// Runs before/after the entire test suite
    /// - Warning: @Scenario and @Required will *not* be injected here and shouldRun will be ignored
    var globalHook : (any Hook)? { get }
    var hooks : [any Hook] {get}
}

public extension Hooks {
    var globalHook : (any Hook)? { nil }
    var hooks : [any Hook] {[]}
}

public struct NoHooks : Hooks {
    public init() {}
}
