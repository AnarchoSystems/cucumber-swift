import XCTest
@testable import CucumberSwift

final class cucumber_swiftTests: XCTestCase {
    func testExample() async throws {
        let bundle = Bundle.module
        guard let path = bundle.path(forResource: "Test", ofType: "feature") else {
            return XCTFail()
        }
        let cucumber = Cucumber(FakeDI(theFile: URL(filePath: path)),
                                steps: GivenCucumber(), CukeExpectation(), GivenDocString(), GivenDataTable(), CukeReadsFile())
        try await cucumber.run(URL(filePath: path))
    }
}

class Ref<T> {
    var val : T!
    init(val: T? = nil) {
        self.val = val
    }
}

@propertyWrapper
class Cuke {
    var ref = Ref<Cucumber>()
    var wrappedValue : Cucumber {
        ref.val
    }
}

@propertyWrapper
class TestResult {
    var ref = Ref<CukeResult>()
    var wrappedValue : CukeResult {
        get{
            ref.val
        }
        set {
            ref.val = newValue
        }
    }
}

@propertyWrapper
class TheFile {
    var wrapped : URL?
    var wrappedValue : URL {
        wrapped!
    }
}

struct EmptyDIContainerFacotry : DIContainerFactory {
    func makeContainer() -> some DIContainer {
        struct Ctr : DIContainer {
            func inject<S>(into step: S) throws where S : Step {}
        }
        return Ctr()
    }
}

struct FakeDI : DIContainer, DIContainerFactory {
    
    func makeContainer() -> some DIContainer {
        FakeDI(theFile: theFile)
    }
    
    let cukeUnderTest = Ref(val: Cucumber(EmptyDIContainerFacotry()))
    let result = Ref(val: CukeResult.fail)
    let theFile : URL
    
    func inject<S>(into step: S) throws where S : CucumberSwift.Step {
        for (_, child) in Mirror(reflecting: step).children {
            if let cuke = child as? Cuke {
                cuke.ref = cukeUnderTest
            }
            else if let res = child as? TestResult {
                res.ref = result
            }
            else if let url = child as? TheFile {
                url.wrapped = theFile
            }
        }
    }
    
}

enum CukeState : String {
    case unimplemented, pending, implemented, flawed
}

struct SomeError : Error {}

struct GivenCucumber : Step {
    
    @Cuke var cucumber
    
    var match : some Matcher {
        Given(#/a/an (unimplemented|pending|flawed|implemented) cucumber/#) {cukeState in
            switch CukeState(rawValue: String(cukeState))! {
            case .unimplemented:
                ()
            case .pending:
                struct MatchAllPending : Step {
                    var match : some Matcher { Given(#/(.*)/#) {_ in throw CucumberError.pending} }
                }
                cucumber.register(MatchAllPending())
            case .implemented:
                struct MatchAllSucceed : Step {
                    var match : some Matcher { Given(#/(.*)/#) {_ in } }
                }
                cucumber.register(MatchAllSucceed())
            case .flawed:
                struct MatchAllFail : Step {
                    var match : some Matcher { Given(#/(.*)/#) {_ in throw SomeError()} }
                }
                cucumber.register(MatchAllFail())
            }
        }
    }
    
}

enum CukeResult : String {
    case printSnippets = "print snippets"
    case bePending = "be pending"
    case fail
    case work
}

struct CukeExpectation : Step {
    
    @TestResult var result
    
    var match : some Matcher {
        Then(#/it should (print snippets|be pending|fail|work)/#) {arg in
            XCTAssertEqual(result, CukeResult(rawValue: String(arg))!)
        }
    }
    
}

struct GivenDocString : Step {
    
    @DocString var docString
    
    var match : some Matcher {
        Given(#/a docstring:/#) {
            XCTAssert(!docString.isEmpty)
        }
    }
}

struct TestData : Codable {
    let example_data : String
}

struct GivenDataTable : Step {
    
    @Examples var examples : [TestData]
    
    var match : some Matcher {
        Given(#/a data table:/#) {
            XCTAssert(!examples.isEmpty)
        }
    }
}

struct CukeReadsFile : Step {
    
    @Cuke var cucumber
    @TheFile var url
    @TestResult var result
    
    var match : some Matcher {
        When(#/cucumber reads this file/#) {
            class Reporter : CukeReporter {
                var result : CukeResult = .fail
                func reportScenario(status: ScenarioState, isFinished: Bool) {
                    guard isFinished else {return}
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
            }
            let reporter = Reporter()
            cucumber.reporter = reporter
            try await cucumber.run(url)
            result = reporter.result
        }
    }
}
