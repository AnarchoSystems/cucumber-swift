import CucumberSwift
import Foundation
import Gherkin
import Testing

func allScenarios() -> [Pickle] {
    guard let path = Bundle.module.path(forResource: "Test", ofType: "feature") else {
        return []
    }

    let fileURL = URL(filePath: path)
    return (
        try? Cucumber.findScenarios(in: fileURL.deletingLastPathComponent())
            .filter { $0.uri == fileURL.absoluteString }
    ) ?? []
}

@Test(arguments: allScenarios())
func testRunAllScenarios(pickle: Pickle) async throws {
    let cucumber = StepCollection(
        steps: [
            BackgroundStep(),
            GivenCucumber(),
            CukeExpectation(),
            GivenDocString(),
            GivenDataTable(),
            CukeReadsFile(),
        ])

    let container = StateContainer()
    container.reporter = NoReporter()
    guard let fileURL = URL(string: pickle.uri) else {
        fatalError("Invalid pickle URI: \(pickle.uri)")
    }
    container.file = fileURL

    try await Cucumber.run(scenario: pickle, on: container, using: cucumber)
}

struct SomeError: LocalizedError {
    var errorDescription: String? {
        "Holy Smoke!"
    }

    var failureReason: String? {
        "A problem has transpired"
    }
}

extension StateContainer {
    @ContainerStorage var cucumber: StepCollection?
    @ContainerStorage var file: URL?
    @ContainerStorage var result: CukeResult?
}

public enum CukeState: String, CukeStringRawRepresentable {
    case unimplemented
    case pending
    case flawed
    case implemented
}

public struct BackgroundStep: Step {
    @Given(/^I am a background step$/)
    public func onRecognize() {}
}

public struct GivenCucumber: Step {
    @Scenario(\.cucumber) var cucumber

    @Given(/^a\/an (unimplemented|pending|flawed|implemented) cucumber$/)
    func onRecognize(_ state: CukeState) throws {
        switch state {
        case .unimplemented:
            cucumber = StepCollection()
        case .pending:
            struct MatchAllPending: Step {
                @Given(/^.*$/)
                func onRecognize() throws { throw Cucumber.Pending() }
            }
            cucumber = StepCollection(steps: [MatchAllPending()])
        case .implemented:
            struct MatchAllSucceed: Step {
                @Given(/^.*$/)
                func onRecognize() {}
            }
            cucumber = StepCollection(steps: [MatchAllSucceed()])
        case .flawed:
            struct MatchAllFail: Step {
                @Given(/^.*$/)
                func onRecognize() throws { throw SomeError() }
            }
            cucumber = StepCollection(steps: [MatchAllFail()])
        }
    }
}

public enum CukeResult: String, CukeStringRawRepresentable {
    case printSnippets = "print snippets"
    case bePending = "be pending"
    case fail
    case work
}

public struct CukeExpectation: Step {
    @Required(\.result) var result

    @Then(/^it should (print snippets|be pending|fail|work)$/)
    func onRecognize(_ cukeResult: CukeResult) {
        cukeExpectEqual(result, cukeResult)
    }
}

public struct GivenDocString: Step {
    @Given(/^a docstring:$/, .docString)
    func onRecognize(_ docString: String) {
        cukeExpect(!docString.isEmpty)
    }
}

public struct TestData: Codable, CodableDataTableDecodable {
    let example_data: String
}

public struct GivenDataTable: Step {
    @Given(/^a data table:$/, .table(.rowMajor, hasHeader:  true))
    func onRecognize(_ table: [TestData]) {
        cukeExpect(!table.isEmpty)
    }
}

private struct ExpectationProbe: Step {
    var regexText: String { "" }
    @Required(\.reporter) var reporter

    func match(_ step: PickleStep) -> (() async throws -> Void)? {
        nil
    }
}

@Test
func testCukeExpectHelpers() {
    let container = StateContainer()
    let probe = ExpectationProbe()
    try! container.inject(into: probe)

    probe.cukeExpect(true)
    probe.cukeExpectEqual(2 + 2, 4)
    probe.cukeExpectNotEqual(2 + 2, 5)
    probe.cukeExpectNil(Optional<Int>.none)
    let value = probe.cukeExpectNotNil("ok")
    #expect(value == "ok")
    probe.cukeExpectContains(["a", "b", "c"], "b")
    probe.cukeExpectEmpty([Int]())
    probe.cukeExpectNotEmpty([1])
    probe.cukeExpectGreaterThan(3, 2)
    probe.cukeExpectLessThan(2, 3)
    probe.cukeExpectApproximatelyEqual(0.3, 0.1 + 0.2, tolerance: 0.000_001)
}

public struct CukeReadsFile: Step {
    @Required(\.cucumber) var cucumber
    @Required(\.file) var url
    @Scenario(\.result) var result

    @When(/^cucumber reads this file$/)
    func onRecognize() async throws {
        final class Reporter: CukeReporter {
            var result: CukeResult = .fail

            func reportFinishedScenario(
                status: ScenarioState,
                elapsedTime: Duration,
                timeWithHooks: Duration
            ) {
                switch status.state {
                case .success:
                    result = .work
                case .undefined:
                    break
                case .pending:
                    result = .bePending
                case .failure:
                    result = .fail
                }
            }

            func onStepsUndefined(_ steps: [ScenarioState.Step]) {
                result = .printSnippets
            }
        }

        let stepReporter = Reporter()

        let nestedContainer = StateContainer()
        nestedContainer.reporter = stepReporter
        nestedContainer.file = url

        let scenarios = try Cucumber.findScenarios(in: url.deletingLastPathComponent())
            .filter { $0.uri == url.absoluteString }

        for scenario in scenarios {
            try? await Cucumber.run(scenario: scenario, on: nestedContainer, using: cucumber)
        }

        result = stepReporter.result
    }
}
