import XCTest
import CucumberSwift

final class cucumber_swiftTests: XCTestCase {
    func testRunAllScenarios() async throws {
        let bundle = Bundle.module
        guard let path = bundle.path(forResource: "Test", ofType: "feature") else {
            try cukeFail()
        }
        let cucumber = try Cucumber(hooks: AllHooks(url: URL(filePath: path)),
                                    reporter: DefaultReporter(snippetDialect: SnippetDialects.yaml),
                                    steps: Cucumber.globSteps)
        
        try await cucumber.run(URL(filePath: path))
    }
}

struct SetUrlHook : Hook {
    
    let url: URL
    @Scenario(\.file) var file: URL?
    
    func before() {
        file = url
    }
    
}

struct AllHooks : Hooks {
    let url : URL
    var hooks: [any Hook] {
        [SetUrlHook(url: url)]
    }
}

struct SomeError : LocalizedError {
    var errorDescription: String? {
        "Holy Smoke!"
    }
    var failureReason: String? {
        "A problem has transpired"
    }
}

extension StateContainer {
    @ContainerStorage var cucumber : Cucumber?
    @ContainerStorage var file : URL?
    @ContainerStorage var result : CukeResult?
}

struct BackgroundStep {
    func onRecognize() async throws {}
}

struct GivenCucumber {
    
    @Scenario(\.cucumber) var cucumber
    
    func onRecognize(cukeState: CukeState) throws {
        cucumber = try Cucumber()
        switch cukeState {
        case .unimplemented:
            ()
        case .pending:
            struct MatchAllPending : Step {
                var match : some Matcher { #Given(#/.*/#) { throw Pending()} }
            }
            cucumber!.register(MatchAllPending())
        case .implemented:
            struct MatchAllSucceed : Step {
                var match : some Matcher { #Match(#/.*/#) { } }
            }
            cucumber!.register(MatchAllSucceed())
        case .flawed:
            struct MatchAllFail : Step {
                var match : some Matcher { #Match(#/.*/#) { throw SomeError()} }
            }
            cucumber!.register(MatchAllFail())
        }
    }
    
}

public enum CukeResult : String {
    case printSnippets = "print snippets"
    case bePending = "be pending"
    case fail
    case work
}

struct CukeExpectation {
    
    @Required(\.result) var result
    
    func onRecognize(cukeResult: CukeResult) throws {
        try cukeAssertEqual(result, cukeResult)
    }
    
}

struct GivenDocString {
    
    @DocString var docString
    
    func onRecognize() throws {
        try cukeAssert(!docString.isEmpty)
    }
    
}

struct TestData : Codable {
    let example_data : String
}

struct GivenDataTable {
    
    @Examples var examples : [TestData]
    
    func onRecognize() throws {
        try cukeAssert(!examples.isEmpty)
    }
    
}

struct CukeReadsFile {
    
    @Required(\.cucumber) var cucumber
    @Required(\.file) var url
    @Scenario(\.result) var result
    
    func onRecognize() async throws {
        class Reporter : CukeReporter {
            var result : CukeResult = .fail
            func reportFinishedScenario(status: ScenarioState, elapsedTime: Duration, timeWithHooks: Duration) {
                switch status.state {
                case .success:
                    result = .work
                case .undefined:
                    ()
                case .pending:
                    result = .bePending
                case .failure:
                    result = .fail
                }
            }
            func onStepsUndefined(_ steps: [String]) {
                result = .printSnippets
            }
            func reportFeatureEnd(hadErrors: Bool) {}
        }
        let reporter = Reporter()
        cucumber.reporter = reporter
        try? await cucumber.run(url)
        result = reporter.result
    }
}

