# cucumber-swift

A very basic and mostly hobby implementation of cucumber for Swift.

Note: I did not implement a Swift library to parse Gherkin, you actually need a gherkin parser installed. You can build one from source, for instance, [here](https://github.com/cucumber/gherkin). After obtaining an executable, you need to install it in /usr/local/bin (i.e., only unix is supported right now, and only with this specific installation path).

Currently, this is very much WIP (and remember, this is hobby, so I don't work very hard on it all the time), but I felt that a little demo could be published. There seems to be a small hard to reproduce concurrency-related bug, but for the most part, this implementation does what it should.

## Showcase

Consider this gherkin:

```gherkin
Feature: Test a variety of gherkin features

    Rule: Cucumber works only when implemented

    Scenario Outline: Docstring and Examples
        Given a/an <implemented> cucumber
        * a docstring:
        """
        Some long text
        """
        And a data table:
        | example_data |
        | whatever     |
        | 0            |
        When cucumber reads this file
        Then it should <work>
        Examples:
        | implemented   | work           |
        | unimplemented | print snippets |
        | pending       | be pending     |
        | flawed        | fail           |
        | implemented   | work           |

```

This file lives in my test sources and I told the package manager to copy it into the bundled resources:

```swift
let package = Package(
    ...
    targets: [
        ...
        .testTarget(
            name: "cucumber-swiftTests",
            dependencies: ["CucumberSwift"],
            resources: [.process("Test.feature")]),
    ]
)
```

Now, in my test class, I did:

```swift
import XCTest
@testable import CucumberSwift

final class cucumber_swiftTests: XCTestCase {
    func testExample() async throws {
        let bundle = Bundle.module
        guard let path = bundle.path(forResource: "Test", ofType: "feature") else {
            return XCTFail()
        }
        let cucumber = Cucumber(FakeDI(theFile: URL(filePath: path)),
                                steps: [])
        try await cucumber.run(URL(filePath: path))
    }
}
```

And I got the following console output:

```bash
struct MyStep0 : Step {
    var match : some Matcher {
        Given(#/a data table:/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep1 : Step {
    var match : some Matcher {
        Given(#/a/an implemented cucumber/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep2 : Step {
    var match : some Matcher {
        Given(#/it should work/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep3 : Step {
    var match : some Matcher {
        Given(#/it should print snippets/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep4 : Step {
    var match : some Matcher {
        Given(#/a/an unimplemented cucumber/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep5 : Step {
    var match : some Matcher {
        Given(#/a/an flawed cucumber/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep6 : Step {
    var match : some Matcher {
        Given(#/a/an pending cucumber/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep7 : Step {
    var match : some Matcher {
        Given(#/it should fail/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep8 : Step {
    var match : some Matcher {
        Given(#/cucumber reads this file/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep9 : Step {
    var match : some Matcher {
        Given(#/it should be pending/#) {
            throw CucumberError.pending
        }
    }
}


struct MyStep10 : Step {
    var match : some Matcher {
        Given(#/a docstring:/#) {
            throw CucumberError.pending
        }
    }
}
```

These steps will already compile. For further details (for example which property wrappers get you access to the doc string and the data table), see the test file. For a working and compatible DI container, you may want to check out [Dependencies](https://github.com/AnarchoSystems/Dependencies).

## To Be Done

Right now, you can report your test results using the CukeReporter protocol (which only actors can conform to). However, this only works correctly for failing tests if they failed through a thrown error. An XCTest failure will not be considered a failure from cucumber's point of view.

Conversely, a thrown error in a cucumber step will not cause an XCTest to fail.

This is not very desirable and needs to change.

Then there's of course the bug mentioned earlier that I still need to reproduce and catch.

And oh, right now, only macOS is supported actually, because I rely on the Process API rather than a Swift parser for gherkin. I'd love to change that, too, though this seems rather challenging.
