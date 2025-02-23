import Foundation

// MARK: - Cucumber def

public struct Cucumber {
    
    private let hooks : any Hooks
    private var steps : [any Step] = []
    public var reporter : any CukeReporter
    let gherkinExeUrl : URL
    
    public init(hooks: any Hooks = NoHooks(), reporter: any CukeReporter = DefaultReporter(), steps: [any Step] = []) throws {
        self.hooks = hooks
        self.steps = steps
        self.reporter = reporter
        self.gherkinExeUrl = try Cucumber.findGherkin()
    }
    
    public init(hooks: Hooks = NoHooks(), reporter: any CukeReporter = DefaultReporter(), steps: (any Step)...) throws {
        try self.init(hooks: hooks, reporter: reporter, steps: steps)
    }
    
    public mutating func register(_ steps: (any Step)...) {
        self.steps.append(contentsOf: steps)
    }
    
}

// MARK: Run

public typealias TagMatcher = ([String]) -> Bool

extension Cucumber {
    
    public func run(_ url: URL, _ shouldRun: TagMatcher = {_ in true}) async throws {
        let data = try Gherkin(gherkinExeUrl).read(url)
        let documents = data.compactMap{if case .gherkinDocument(let doc) = $0 {return doc}; return nil}
        guard documents.count == 1 else {
            throw MultipleGherkinDocsRead()
        }
        var scenarioStates = [String : ScenarioState]()
        var time : Duration!
        reporter.reportFeatureBegin(feature: documents.first!.feature.name)
        let timeWithHooks = try await ContinuousClock().measure {
            if let glob = hooks.globalHook {
                do {
                    try await glob.before()
                }
                catch {
                    try await glob.after()
                    throw error
                }
            }
            do {
                time = try await ContinuousClock().measure {
                    for try envelope in data {
                        if let scenarioState = try await handleEnvelope(envelope, shouldRun) {
                            scenarioStates[scenarioState.id] = scenarioState
                        }
                    }
                }
            }
            catch {
                if let glob = hooks.globalHook {
                    try await glob.after()
                }
                throw error
            }
            let undefinedSteps = Set(scenarioStates.values.flatMap{$0.steps.lazy.filter{$0.state == .undefined}.map{$0.text}})
            if !undefinedSteps.isEmpty {
                reporter.onStepsUndefined(Array(undefinedSteps))
            }
            if let glob = hooks.globalHook {
                try await glob.after()
            }
        }
        reporter.reportFeatureEnd(feature: documents.first!.feature.name,
                                  hadErrors: scenarioStates.values.contains(where: {$0.state != .success}),
                                  elapsedTime: time,
                                  timeWithHooks: timeWithHooks)
    }
    
}

// MARK: - Helpers

private extension Cucumber {
    
    func handleEnvelope(_ envelope: Envelope, _ shouldRun: TagMatcher) async throws -> ScenarioState? {
        switch envelope {
        case .pickle(let pickle):
            if !shouldRun(pickle.tags) {
                return nil
            }
            return try await handlePickle(pickle)
        case .source, .gherkinDocument:
            return nil
        case .parseError(let error):
            throw error
        }
    }
    
    func handlePickle(_ pickle: Pickle) async throws -> ScenarioState {
        let hooks = self.hooks.hooks.filter{$0.shouldRun(pickle.tags)}
        let container = StateContainer()
        var scenarioState = ScenarioState(id: pickle.id + ": \"" + pickle.name + "\"")
        var time : Duration!
        let timeWithHooks = try await ContinuousClock().measure {
            var hooksToUndo : [any Hook] = []
            for hook in hooks {
                hooksToUndo.append(hook)
                do {
                    try container.inject(into: hook)
                    try await hook.before()
                }
                catch {
                    for hook in hooksToUndo.reversed() {
                        try await hook.after()
                    }
                    throw error
                }
            }
            time = await ContinuousClock().measure {
                for step in pickle.steps {
                    await tryExecutePickleStep(container, step: step, scenarioState: &scenarioState)
                    reporter.reportRunningScenario(status: scenarioState)
                }
            }
            for hook in hooks.reversed() {
                try await hook.after()
            }
        }
        reporter.reportFinishedScenario(status: scenarioState,
                                        elapsedTime: time,
                                        timeWithHooks: timeWithHooks)
        return scenarioState
    }
    
    func tryExecutePickleStep(_ container: StateContainer, step: PickleStep, scenarioState: inout ScenarioState) async {
        do {
            let matches = try steps.compactMap{stp in try stp.match.match(step.text).map{match in (stp, match)}}
            if matches.isEmpty {
                scenarioState.steps.append(.undefined(step.text))
                // add to undefined steps
            }
            if matches.count > 1 {
                throw InternalCucumberError.ambiguousMatch(matches.map{arg in arg.0.match.regexText})
            }
            guard scenarioState.state == .success else {
                return
            }
            let (stp, match) = matches.first!
            try container.inject(into: stp)
            if let argument = step.argument {
                try stp.readArgs(args: argument)
            }
            try await stp.match.invoke(with: match)
            scenarioState.steps.append(.success(step.text))
        }
        catch let error as Pending {
            _ = error
            scenarioState.steps.append(.pending(step.text))
        }
        catch {
            scenarioState.steps.append(.failure(step.text, error))
        }
    }
    
    static func findGherkin() throws -> URL {
        let mgr = FileManager.default
        guard let path : [URL] = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").lazy.map(String.init).compactMap(URL.init(string:)) else {
            throw InternalCucumberError.pathNotDefined
        }
        for dir in path {
            let url = dir.appending(path: "gherkin")
            if mgr.fileExists(atPath: url.absoluteString) {
                return url
            }
        }
        throw InternalCucumberError.couldNotFindGherkin(path: path)
    }
    
}

public struct MultipleGherkinDocsRead : LocalizedError {
    public let errorDescription: String? = "Found multiple Gherkin documents"
}

public enum InternalCucumberError : LocalizedError {
    case ambiguousMatch([String])
    case pathNotDefined
    case couldNotFindGherkin(path: [URL])
    public var errorDescription: String? {
        switch self {
        case .ambiguousMatch:
            "Multiple Steps Match"
        case .pathNotDefined:
            "$PATH Not Defined"
        case .couldNotFindGherkin:
            "Gherkin not found"
        }
    }
    public var failureReason: String? {
        switch self {
        case .ambiguousMatch(let array):
            "Possible Steps:\n" + array.map{"  - " + $0}.joined(separator: "\n")
        case .pathNotDefined:
            "Your environment does not seem to contain $PATH"
        case .couldNotFindGherkin(let path):
            "Searching in the following directories:\n" + path.map{"  - " + $0.absoluteString}.joined(separator: "\n")
        }
    }
}

// MARK: - Helper types

extension Step {
    func readArgs(args: PickleArg) throws {
        for (_, child) in Mirror(reflecting: self).children {
            if let reader = child as? PickleArgReader {
                try reader.read(from: args)
            }
        }
    }
}

protocol PickleArgReader {
    func read(from arg: PickleArg) throws
}

@propertyWrapper
public class DocString : PickleArgReader {
    private var wrapped : String?
    public var wrappedValue : String {
        wrapped!
    }
    public init() {}
    func read(from arg: PickleArg) throws {
        guard case .docString(let string) = arg else {
            throw InvalidPickleArg.expectedDocString
        }
        wrapped = string
    }
}

@propertyWrapper
public class ExampleList : PickleArgReader {
    private var wrapped : [[String]]?
    public var wrappedValue : [[String]] {
        wrapped!
    }
    public init() {}
    func read(from arg: PickleArg) throws {
        guard case .dataTable(let dataTable) = arg else {
            throw InvalidPickleArg.expectedDataTable
        }
        wrapped = dataTable.asLists()
    }
}

@propertyWrapper
public class ExampleMap : PickleArgReader {
    var wrapped : [[String : String]]?
    public var wrappedValue : [[String : String]] {
        wrapped!
    }
    public init() {}
    func read(from arg: PickleArg) throws {
        guard case .dataTable(let dataTable) = arg else {
            throw InvalidPickleArg.expectedDataTable
        }
        wrapped = dataTable.asMaps()
    }
}

@propertyWrapper
public class Examples<T : Codable> : PickleArgReader {
    var wrapped : [T]?
    public var wrappedValue : [T] {
        wrapped!
    }
    public init() {}
    func read(from arg: PickleArg) throws {
        guard case .dataTable(let dataTable) = arg else {
            throw InvalidPickleArg.expectedDataTable
        }
        wrapped = try dataTable.typed(T.self)
    }
}

public enum InvalidPickleArg : LocalizedError {
    case expectedDocString
    case expectedDataTable
    public var errorDescription: String? {
        "Unexpected Argument Type"
    }
    public var failureReason: String? {
        switch self {
        case .expectedDocString:
            "Expected a docstring"
        case .expectedDataTable:
            "Expected a data table"
        }
    }
}
