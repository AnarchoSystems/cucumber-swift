import Foundation
import Gherkin

let divider = "------------------------------------------------------------------------"

public struct ScenarioState {
    public let id: String
    public let name: String
    public let uri: String?
    public var steps: [Step] = []

    public init(id: String, name: String, uri: String? = nil) {
        self.id = id
        self.name = name
        self.uri = uri
    }

    public var state: State {
        if steps.contains(where: { $0.state == .failure }) {
            .failure
        }
        else if steps.contains(where: { $0.state == .pending }) {
            .pending
        }
        else if steps.contains(where: { $0.state == .undefined }) {
            .undefined
        }
        else {
            .success
        }
    }

    public struct Step {
        public let text: String
        public let location: Gherkin.Location?
        public let state: State
        public let error: Error?

        public static func success(_ text: String, location: Gherkin.Location? = nil) -> Step {
            .init(text: text, location: location, state: .success, error: nil)
        }

        public static func undefined(_ text: String, location: Gherkin.Location? = nil) -> Step {
            .init(text: text, location: location, state: .undefined, error: nil)
        }

        public static func pending(_ text: String, location: Gherkin.Location? = nil) -> Step {
            .init(text: text, location: location, state: .pending, error: nil)
        }

        public static func failure(_ text: String, location: Gherkin.Location? = nil, _ error: Error) -> Step {
            .init(text: text, location: location, state: .failure, error: error)
        }
    }

    public enum State: String {
        case success
        case undefined
        case pending
        case failure
    }
}

public protocol CukeReporter {
    func reportRunningScenario(status: ScenarioState)
    func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration)
    func onStepsUndefined(_ steps: [ScenarioState.Step])
    func reportAssertionFailure(message: String, file: StaticString, line: UInt)
}

public extension CukeReporter {
    func reportRunningScenario(status: ScenarioState) {}
    func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration) {}
    func onStepsUndefined(_ steps: [ScenarioState.Step]) {}
    func reportAssertionFailure(message: String, file: StaticString, line: UInt) {}
}

public struct NoReporter : CukeReporter {
    public init() {}
}

public protocol SnippetDialect {
    func generateSnippets(_ undefinedSteps: [ScenarioState.Step]) -> String
}

public struct SwiftSnippetDialect : SnippetDialect {
    public func generateSnippets(_ steps: [ScenarioState.Step]) -> String {
        steps.enumerated().map { index, step in
            let locationComment: String
            if let location = step.location {
                locationComment = "// line \(location.line), column \(location.column)"
            } else {
                locationComment = "// location unavailable"
            }

            return """

            \(locationComment)
            struct MyStep\(index): Step {
                @Given(#/^\(step.text)$/#)
                func onRecognize() throws {
                    throw Cucumber.Pending()
                }
            }

            """
        }
        .joined(separator: "\n")
    }
}

public struct YamlSnippetDialect : SnippetDialect {
    public func generateSnippets(_ steps: [ScenarioState.Step]) -> String {
        var snippet = "groupName: MyGroup\nsteps:\n"
        for (idx, step) in steps.enumerated() {
            snippet.append(" - step: \"^\(step.text)$\"\n   className: MyStep\(idx)\n")
        }
        return snippet
    }
}

public enum SnippetDialects {
    public static var swift : some SnippetDialect { SwiftSnippetDialect() }
    public static var yaml : some SnippetDialect { YamlSnippetDialect() }
}

public struct DefaultReporter : CukeReporter {
    public var dialect: SnippetDialect
    public init(snippetDialect: SnippetDialect = SnippetDialects.swift) {
        self.dialect = snippetDialect
    }
    public func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration) {
        let scenarioTitle = status.name.isEmpty ? status.id : status.name
        switch status.state {
        case .success:
            print("\tScenario \(scenarioTitle) passed after \(elapsedTime) (\(timeWithHooks) with hooks).\n\n")
        case .undefined:
            print("\tScenario \(scenarioTitle) has undefined steps.\n\n")
        case .pending:
            print("\tFull implementation of scenario \(scenarioTitle) pending.\n\n")
        case .failure:
            var report = "\tScenario \(scenarioTitle) failed after \(elapsedTime) (\(timeWithHooks) with hooks).\n\t\tDetails:\n"
            for step in status.steps {
                let locationText = step.location.map { " [\($0.line):\($0.column)]" } ?? ""
                report.append("\t\t - " + step.text + locationText + ": " + step.state.rawValue + "\n")
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
    public func onStepsUndefined(_ steps: [ScenarioState.Step]) {
        print("\(divider)\n\n\tUndefined steps:\n\n")
        print(dialect.generateSnippets(steps))
    }
    public func reportAssertionFailure(message: String, file: StaticString, line: UInt) {
        print("\tAssertion failed at \(file):\(line): \(message)\n")
    }
}
