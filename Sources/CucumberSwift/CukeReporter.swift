import Foundation

let divider = "------------------------------------------------------------------------"

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
        public let error : Error?
        public static func success(_ text: String) -> Step {
            .init(text: text, state: .success, error: nil)
        }
        public static func undefined(_ text: String) -> Step {
            .init(text: text, state: .undefined, error: nil)
        }
        public static func pending(_ text: String) -> Step {
            .init(text: text, state: .pending, error: nil)
        }
        public static func failure(_ text: String, _ error: Error) -> Step {
            .init(text: text, state: .failure, error: error)
        }
    }
    
    public enum State : String {
        case success
        case undefined
        case pending
        case failure
    }
}

public protocol CukeReporter {
    func reportFeatureBegin(feature: String)
    func reportRunningScenario(status: ScenarioState)
    func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration)
    func onStepsUndefined(_ steps: [String])
    func reportFeatureEnd(feature: String, hadErrors: Bool, elapsedTime: Duration, timeWithHooks: Duration)
}

public extension CukeReporter {
    func reportFeatureBegin(feature: String) {}
    func reportRunningScenario(status: ScenarioState) {}
    func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration) {}
    func onStepsUndefined(_ steps: [String]) {}
    func reportFeatureEnd(feature: String, hadErrors: Bool, elapsedTime: Duration, timeWithHooks: Duration) {}
}

public struct NoReporter : CukeReporter {}

public protocol SnippetDialect {
    func generateSnippets(_ undefinedSteps: [String]) -> String
}

public struct SwiftSnippetDialect : SnippetDialect {
    public func generateSnippets(_ steps: [String]) -> String {
        
        var snippet = ""
        
        for (idx, undefinedStep) in steps.enumerated() {
            let next =
    """
    
        struct MyStep\(idx) : Step {
            var match : some Matcher {
                #Given(#/^\(undefinedStep)$/#) {
                    throw CucumberError.pending
                }
            }
        }
    
    """
            snippet.append(next)
        }
        
        return snippet
    }
}

public struct YamlSnippetDialect : SnippetDialect {
    public func generateSnippets(_ steps: [String]) -> String {
        var snippet = "groupName: MyGroup\nsteps:\n"
        for (idx, step) in steps.enumerated() {
            snippet.append(" - step: \"^\(step)$\"\n   className: MyStep\(idx)\n")
        }
        return snippet
    }
}

public enum SnippetDialects {
    public static var swift : some SnippetDialect { SwiftSnippetDialect() }
    public static var yaml : some SnippetDialect { YamlSnippetDialect() }
}

public struct DefaultReporter : CukeReporter {
    public var dialect : SnippetDialect
    public init(snippetDialect: SnippetDialect = SnippetDialects.swift) {
        self.dialect = snippetDialect
    }
    public func reportFeatureBegin(feature: String) {
        print("\nRunning feature \"\(feature)\"...\n\(divider)\n\n")
    }
    public func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration) {
        switch status.state {
        case .success:
            print("\tScenario \(status.id) passed after \(elapsedTime) (\(timeWithHooks) with hooks).\n\n")
        case .undefined:
            print("\tScenario \(status.id) has undefined steps.\n\n")
        case .pending:
            print("\tFull implementation of scenario \(status.id) pending.\n\n")
        case .failure:
            var report = "\tScenario \(status.id) failed after \(elapsedTime) (\(timeWithHooks) with hooks).\n\t\tDetails:\n"
            for step in status.steps {
                report.append("\t\t - " + step.text + ": " + step.state.rawValue + "\n")
                if let error = step.error {
                    if let localizedErr = error as? LocalizedError {
                        report.append("\t\t\t - Error: \(localizedErr.errorDescription ?? localizedErr.localizedDescription)\n")
                        if let reason = localizedErr.failureReason {
                            report.append("\t\t\t - Reason: \(reason)\n")
                        }
                    }
                    report.append("\t\t\t - Reason: \(error.localizedDescription)\n")
                }
            }
            report.append("\n")
            print(report)
        }
    }
    public func onStepsUndefined(_ steps: [String]) {
        
        print("\(divider)\n\n\tUndefined steps:\n\n")
        
        print(dialect.generateSnippets(steps))
    }
    public func reportFeatureEnd(feature: String, hadErrors: Bool, elapsedTime: Duration, timeWithHooks: Duration) {
        print("\n\(divider)\n\nFeature \(feature) completed \(hadErrors ? "with errors" : "successfully").\nTotal duration: \(elapsedTime).\nTime with hooks: \(timeWithHooks).\n\n")
        if hadErrors {
            exit(EXIT_FAILURE)
        }
    }
}
