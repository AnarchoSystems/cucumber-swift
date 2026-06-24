# cucumber-swift

[![CI](https://github.com/AnarchoSystems/cucumber-swift/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AnarchoSystems/cucumber-swift/actions/workflows/ci.yml)

`cucumber-swift` is a lightweight BDD library for Swift packages. It parses `.feature` files in-process with the `gherkin` package, matches steps with Swift macros, and executes scenarios against a shared scenario container.

## Requirements

- Swift 6.0+
- macOS 13+

## Installation

Add the package to your `Package.swift` dependencies and test target:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MyPackage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/AnarchoSystems/cucumber-swift.git", branch: "main")
    ],
    targets: [
        .testTarget(
            name: "MyPackageTests",
            dependencies: [
                "CucumberSwift"
            ],
            resources: [
                .process("Features")
            ]
        )
    ]
)
```

## Define Steps

Each `Step` conformer has exactly one annotated method, using one of the attribute macros exported by `CucumberSwift`.

```swift
import CucumberSwift

struct GivenCounter: Step {
    @Required(\.reporter) var reporter
    @Scenario(\.counter) var counter

    @Given(/^a counter starting at (\d+)$/)
    func onRecognize(_ start: Int) {
        counter = start
    }
}

struct WhenCounterIncrements: Step {
    @Required(\.reporter) var reporter
    @Scenario(\.counter) var counter

    @When(/^I increment the counter$/)
    func onRecognize() {
        counter = (counter ?? 0) + 1
    }
}

struct ThenCounterEquals: Step {
    @Required(\.reporter) var reporter
    @Scenario(\.counter) var counter

    @Then(/^the counter should be (\d+)$/)
    func onRecognize(_ expected: Int) {
        cukeExpectEqual(counter, expected)
    }
}

extension StateContainer {
    @ContainerStorage var counter: Int?
}
```

The supported step-definition macros are:

- `@Given`
- `@When`
- `@Then`

Each macro accepts a `Regex` and, optionally, a `StepArgDef` to bind doc strings or tables.

## Use Scenario Data

`StateContainer` stores scenario-scoped values. Two property wrappers handle access inside steps:

- `@Scenario` reads and writes optional scenario state.
- `@Required` reads values that must already exist in the container.

Container storage keys are added with `@ContainerStorage` on a `StateContainer` extension.

## Read Step Arguments

In addition to regex captures, steps can bind Gherkin doc strings and data tables.

```swift
import CucumberSwift

struct Row: Codable, CodableDataTableDecodable {
    let name: String
    let age: Int
}

struct GivenDocString: Step {
    @Given(/^a docstring:$/, .docString)
    func onRecognize(_ value: String) {
        cukeExpect(!value.isEmpty)
    }
}

struct GivenPeopleTable: Step {
    @Given(/^the following people exist$/, .table(.rowMajor, hasHeader: true))
    func onRecognize(_ rows: [Row]) {
        cukeExpectGreaterThan(rows.count, 0)
    }
}
```

## Run Scenarios

`Cucumber` exposes static APIs for discovery and execution.

```swift
import CucumberSwift
import Foundation
import Testing

func findScenarios() throws -> [Pickle] {
    let featuresDirectory = Bundle.module.bundleURL.appending(path: "Features")
    return try Cucumber.findScenarios(in: featuresDirectory)
}

@Test(arguments: allScenarios())
func featureScenariosPass(scenario: Pickle) async throws {
    
    let steps = StepCollection(steps: [
        GivenCounter(),
        WhenCounterIncrements(),
        ThenCounterEquals(),
        GivenDocString(),
        GivenPeopleTable(),
    ])

    let container = StateContainer()
    
    try await Cucumber.run(scenario: scenario, on: container, using: steps)
}
```

`Cucumber.findScenarios(in:)` currently discovers `.feature` files in the directory you pass it and compiles them into `Pickle` values from the `gherkin` package.

## Reporting and Snippets

Every `StateContainer` has a `reporter`.

- `DefaultReporter()` prints human-readable scenario results.
- `NoReporter()` suppresses output.

You can inject your own reporter by conforming to `CukeReporter`.

## Assertions

`Step` gets helper assertions through protocol extensions:

- `cukeExpect`
- `cukeExpectEqual`
- `cukeExpectNotEqual`
- `cukeExpectNil`
- `cukeExpectNotNil`
- `cukeExpectContains`
- `cukeExpectEmpty`
- `cukeExpectNotEmpty`
- `cukeExpectGreaterThan`
- `cukeExpectLessThan`
- `cukeExpectApproximatelyEqual`

These helpers report through the configured `CukeReporter` and integrate with Swift Testing when available.

## Current Scope

The package currently documents and supports:

- Attribute-macro step definitions with `@Given`, `@When`, and `@Then`
- Static scenario discovery and execution through `Cucumber`
- Scenario-scoped dependency injection through `StateContainer`
- Snippet generation for undefined steps