import Foundation
import Gherkin

// MARK: - Cucumber def

final class ReportWrapper: CukeReporter {
    var failed = false
    var message = ""
    let original: any CukeReporter
    init(original: any CukeReporter) {
        self.original = original
    }
    func reportRunningScenario(status: ScenarioState) {
        original.reportRunningScenario(status: status)
    }
    func reportAssertionFailure(message: String, file: StaticString, line: UInt) {
        self.failed = true
        self.message = message
        self.original.reportAssertionFailure(message: message, file: file, line: line)
    }
    func onStepsUndefined(_ steps: [ScenarioState.Step]) {
        original.onStepsUndefined(steps)
    }
    func reportFinishedScenario(
        status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration
    ) {
        original.reportFinishedScenario(
            status: status, elapsedTime: elapsedTime, timeWithHooks: timeWithHooks)
    }
}

struct DebugError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    var localizedDescription: String { message }
}

public enum Cucumber {

    public static func findScenarios(in directory: URL) throws -> [Pickle] {
        let parser = Parser()
        let compiler = PickleCompiler()
        return try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )
        .lazy
        .filter { $0.pathExtension == "feature" }
        .flatMap { url in
            let content = try String(contentsOf: url)
            let gherkinDocument = try parser.parse(source: content)
            return compiler.compile(document: gherkinDocument, uri: url.absoluteString)
        }
    }

    public static func run(
        scenario: Pickle,
        on container: StateContainer,
        using collection: StepCollection
    ) async throws {
        let start = ContinuousClock.now
        let availableSteps = collection.computeStepDefs.flatMap { f in f(scenario) }
        let stepLocations = try? stepLocationMap(for: scenario)
        var didReportFinished = false

        func reportFinished(status: ScenarioState) {
            guard !didReportFinished else {
                return
            }
            didReportFinished = true
            let elapsed = start.duration(to: ContinuousClock.now)
            container.reporter.reportFinishedScenario(
                status: status,
                elapsedTime: elapsed,
                timeWithHooks: elapsed
            )
        }

        let reporter = ReportWrapper(original: container.reporter)
        defer {
            container.reporter = reporter.original
        }
        container.reporter = reporter

        var status = ScenarioState(id: scenario.id, name: scenario.name, uri: scenario.uri)
        var stepsToUse: [(Any, () async throws -> Void, PickleStep)] = []
        var missingSteps: [ScenarioState.Step] = []

        for pickleStep in scenario.steps {
            var matchingSteps: [(String, Any, () async throws -> Void)] = []
            for stepDef in availableSteps {
                if let match = try stepDef.match(pickleStep) {
                    matchingSteps.append((stepDef.regexText, stepDef, match))
                }
            }

            guard matchingSteps.count <= 1 else {
                throw CucumberError.noUniqueMatch(
                    step: pickleStep.text,
                    matches: matchingSteps.map { $0.0 }
                )
            }

            guard let matchedStep = matchingSteps.first else {
                let location = stepLocations?[pickleStep.astNodeIds.first ?? ""]
                let undefinedStep = ScenarioState.Step.undefined(
                    pickleStep.text, location: location)
                missingSteps.append(undefinedStep)
                status.steps.append(undefinedStep)
                continue
            }

            stepsToUse.append((matchedStep.1, matchedStep.2, pickleStep))
        }

        if !missingSteps.isEmpty {
            container.reporter.onStepsUndefined(missingSteps)
        }

        container.reporter.reportRunningScenario(status: status)
        defer {
            reportFinished(status: status)
        }

        for (stepDef, runStep, pickleStep) in stepsToUse {
            do {
                try container.inject(into: stepDef)
                try await runStep()
                if reporter.failed {
                    status.steps.append(
                        ScenarioState.Step.failure(
                            pickleStep.text,
                            location: stepLocations?[pickleStep.astNodeIds.first ?? ""],
                            DebugError(message: reporter.message)))
                } else {
                    status.steps.append(
                        ScenarioState.Step.success(
                            pickleStep.text,
                            location: stepLocations?[pickleStep.astNodeIds.first ?? ""]
                        ))
                }
            } catch is Pending {
                status.steps.append(
                    ScenarioState.Step.pending(
                        pickleStep.text, location: stepLocations?[pickleStep.astNodeIds.first ?? ""]
                    ))
                return
            } catch {
                status.steps.append(
                    ScenarioState.Step.failure(
                        pickleStep.text,
                        location: stepLocations?[pickleStep.astNodeIds.first ?? ""],
                        error))
                throw error
            }
        }
    }

    private static func stepLocationMap(for scenario: Pickle) throws -> [String: Gherkin.Location] {
        guard let url = URL(string: scenario.uri) else {
            return [:]
        }

        let source = try String(contentsOf: url)
        let document = try Parser().parse(source: source)
        guard let feature = document.feature else {
            return [:]
        }

        var locations: [String: Gherkin.Location] = [:]

        func record(step: Gherkin.Step) {
            locations[step.id] = step.location
        }

        func walkFeatureChildren(_ children: [Gherkin.FeatureChild]) {
            for child in children {
                if let background = child.background {
                    background.steps.forEach(record)
                }
                if let scenario = child.scenario {
                    scenario.steps.forEach(record)
                }
                if let rule = child.rule {
                    walkRuleChildren(rule.children)
                }
            }
        }

        func walkRuleChildren(_ children: [Gherkin.RuleChild]) {
            for child in children {
                if let background = child.background {
                    background.steps.forEach(record)
                }
                if let scenario = child.scenario {
                    scenario.steps.forEach(record)
                }
            }
        }

        walkFeatureChildren(feature.children)
        return locations
    }

    public struct Pending: Error {
        public init() {}
    }

    public enum CucumberError: Error {
        case noUniqueMatch(step: String, matches: [String])
    }
}
