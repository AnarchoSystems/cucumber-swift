//
//  Cucumber.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

import Foundation

public struct ScenarioState {
    public let id : String
    public var steps : [Step] = []
    public init(id: String) {
        self.id = id
    }
    public var state : State {
        if steps.contains(where: {$0.state == .failure}) {
            .failure
        }
        else if steps.contains(where: {$0.state == .pending}) {
            .pending
        }
        else if steps.contains(where: {$0.state == .undefined}) {
            .undefined
        }
        else {
            .success
        }
    }
    
    public struct Step {
        public let text : String
        public let state : State
        public init(text: String, state: State) {
            self.text = text
            self.state = state
        }
    }
    
    public enum State {
        case success
        case undefined
        case pending
        case failure
    }
}

public protocol CukeReporter : Actor {
    func reportScenario(status: ScenarioState, isFinished: Bool)
    func onStepsUndefined(_ steps: [String])
}

public extension CukeReporter {
    func onStepsUndefined(_ steps: [String]) {
        for (idx, undefinedStep) in steps.enumerated() {
            let snippet =
"""

struct MyStep\(idx) : Step {
    var match : some Matcher {
        Cucumber.match(#/\(undefinedStep)/#) {
            throw CucumberError.pending
        }
    }
}

"""
            print(snippet)
        }
    }
}

public actor DefaultReporter : CukeReporter {
    public func reportScenario(status: ScenarioState, isFinished: Bool) {}
}

public class Cucumber {
    
    private let DI : () -> any DIContainer
    private var steps : [any Step] = []
    public var reporter : CukeReporter = DefaultReporter()
    private var scenarioStates : [String : ScenarioState] = [:]
    
    init<DI : DIContainerFactory>(_ diFactory: DI, steps: [any Step] = []) {
        self.DI = diFactory.makeContainer
        self.steps = steps
    }
    
    convenience init<DI : DIContainerFactory>(_ diFactory: DI, steps: (any Step)...) {
        self.init(diFactory, steps: steps)
    }
    
    public func register(_ step: (any Step)...) {
        steps.append(contentsOf: step)
    }
    
    public func run(_ url: URL) async throws {
        for try await envelope in try Gherkin().stream(url) {
            try await handleEnvelope(envelope)
        }
        let undefinedSteps = Set(scenarioStates.values.flatMap{$0.steps.lazy.filter{$0.state == .undefined}.map{$0.text}})
        if !undefinedSteps.isEmpty {
            await reporter.onStepsUndefined(Array(undefinedSteps))
        }
        scenarioStates = [:]
    }
    
    private func handleEnvelope(_ envelope: Envelope) async throws {
        switch envelope {
        case .pickle(let pickle):
            await handlePickle(pickle)
        case .source:
            ()
        case .gherkinDocument:
            ()
        case .parseError(let error):
            throw error
        }
    }
    
    private func handlePickle(_ pickle: Pickle) async {
        let container = DI()
        var scenarioState = ScenarioState(id: pickle.id)
        for step in pickle.steps {
            await tryExecutePickleStep(container, step: step, scenarioState: &scenarioState)
            await reportScenario(scenarioState)
        }
        await reportScenario(scenarioState, finish: true)
    }
    
    private func tryExecutePickleStep(_ container: any DIContainer, step: PickleStep, scenarioState: inout ScenarioState) async {
        do {
            let matches = try steps.compactMap{stp in try stp.match.match(step.text).map{match in (stp, match)}}
            if matches.isEmpty {
                scenarioState.steps.append(.init(text: step.text,
                                                 state: .undefined))
                // add to undefined steps
            }
            if matches.count > 1 {
                throw InternalCucumberError.ambiguousMatch(matches.map{arg in arg.0.match.regexText})
            }
            guard scenarioState.state == .success else {
                return
            }
            let (stp, match) = matches.first!
            try stp.inject(from: container)
            if let argument = step.argument {
                try stp.readArgs(args: argument)
            }
            try await stp.match.invoke(with: match)
        }
        catch CucumberError.pending {
            scenarioState.steps.append(.init(text: step.text, state: .pending))
        }
        catch {
            scenarioState.steps.append(.init(text: step.text, state: .failure))
        }
    }
    
    private func reportScenario(_ scenarioState: ScenarioState, finish: Bool = false) async {
        await reporter.reportScenario(status: scenarioState, isFinished: finish)
        if finish {
            self.scenarioStates[scenarioState.id] = scenarioState
        }
    }
    
}

enum InternalCucumberError : Error {
    case ambiguousMatch([String])
}

public enum CucumberError : Error {
    case pending
}

extension Step {
    func inject(from container: any DIContainer) throws {
        try container.inject(into: self)
    }
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

public enum InvalidPickleArg : Error {
    case expectedDocString
    case expectedDataTable
}
