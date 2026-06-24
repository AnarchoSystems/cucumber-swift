# cucumber-swift Architecture

## Overview

`cucumber-swift` is a small execution engine around the `gherkin` parser. Its core job is to:

1. Load `.feature` files from disk.
2. Compile them into `Pickle` scenarios.
3. Match each Gherkin step against macro-generated Swift step definitions.
4. Execute matched closures against a scenario-scoped `StateContainer`.
5. Report success, pending work, failures, and undefined steps.

The current public surface is centered on static functions in `Cucumber`, macro-backed `Step` implementations, and `StepCollection` composition.

## Modules

### Cucumber

`Sources/CucumberSwift/Cucumber.swift`

`Cucumber` is a public enum that acts as the runtime entry point.

- `findScenarios(in:)` reads `.feature` files in a directory, parses them with `Gherkin.Parser`, and compiles them with `PickleCompiler`.
- `run(scenario:on:using:)` resolves matching step definitions, injects scenario state, executes step closures, and reports a `ScenarioState` through the configured reporter.
- `Pending` is a marker error for partially implemented scenarios.
- `CucumberError.noUniqueMatch` guards against ambiguous step definitions.

### Step and Macros

`Sources/CucumberSwift/Step.swift`

The `Step` protocol is intentionally small:

- `regexText`
- `match(_:)`
- `reporter`

Most consumers do not implement these members manually. Instead, the macros declared in `Sources/CucumberSwift/Macros.swift` generate the plumbing for a `Step` that has exactly one annotated method:

- `@Given`
- `@When`
- `@Then`
- `@ContainerStorage`

The macro implementation lives in the `CukeMacros` target.

### StepCollection

`Sources/CucumberSwift/StepCollection.swift`

`StepCollection` is a lightweight composition layer over one or more sets of steps. It stores closures that, given a `Pickle`, produce the `Step` instances available for that scenario.

This supports two patterns:

- Static registration with `StepCollection(steps: [...])`
- Scenario-dependent composition with `StepCollection { pickle in ... }`

### StateContainer

`Sources/CucumberSwift/StateContainer.swift`

`StateContainer` is the scenario-scoped dependency store. It holds values keyed by generated storage accessors and injects wrappers found by reflection.

The wrappers are:

- `@Scenario`: optional scenario-local state with read/write access
- `@Required`: required state that must already exist before the step runs

`StateContainer` also carries the active `reporter` through a `@ContainerStorage` extension.

### Reporting

`Sources/CucumberSwift/CukeReporter.swift`

Reporting is protocol-driven.

- `CukeReporter` defines hooks for scenario start, scenario completion, undefined steps, and assertion failures.
- `DefaultReporter` prints human-readable results and snippet suggestions.
- `NoReporter` suppresses output.
- `SnippetDialects.swift` and `.yaml` render undefined-step scaffolds in different formats.

`ScenarioState` is the canonical execution summary. Each step is recorded as `success`, `undefined`, `pending`, or `failure`, and the overall scenario state is derived from that list.

### Assertions

`Sources/CucumberSwift/CukeAssertions.swift`

Expectation helpers are implemented as protocol extensions on `Step`. They feed failures into the active reporter and then defer to Swift Testing when available.

### Type Conversion

`Sources/CucumberSwift/RegexArgDecodable.swift`

`Sources/CucumberSwift/StepArgDecodable.swift`

Argument conversion is split between regex captures and step-argument payloads such as doc strings and tables. These files define the decoding contracts used by macro-generated matchers.

## Execution Flow

```text
.feature file
  -> Gherkin.Parser
  -> PickleCompiler
  -> [Pickle]
  -> StepCollection produces candidate steps
  -> each PickleStep is matched against macro-generated handlers
  -> StateContainer injects reporter and scenario values
  -> matched closures execute
  -> CukeReporter receives status updates
```

The runtime records undefined steps before execution starts so reporters can emit snippet suggestions even when the scenario cannot complete successfully.

## Error Semantics

- No matching step records an `undefined` step.
- More than one matching step throws `CucumberError.noUniqueMatch`.
- Throwing `Cucumber.Pending()` records a `pending` step and stops the scenario.
- Any other thrown error records a failing step and rethrows.

## Package Layout

- `Sources/CucumberSwift`: public runtime API
- `Sources/CukeMacros`: macro expansion implementation
- `Tests/cucumber-swiftTests`: feature-driven and assertion-focused tests