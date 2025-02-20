# cucumber-swift

A very basic and mostly hobby implementation of cucumber for Swift.

## Caution

I did **not** implement a Swift library to parse Gherkin! You actually need a gherkin parser installed. You can build one from source, for instance, [here](https://github.com/cucumber/gherkin). After building an executable, you need to make sure it's in a folder on your PATH, or to be more specific: the PATH that your test application will see (which *might* differ from your path).

This also means that the implementation assumes unix conventions and that your application even has the right to run some other process.

## Showcase

Consider this gherkin:

```gherkin
Feature: Test a variety of gherkin features

    Rule: Cucumber works only when implemented
    
    Background:
        * I am a background step
    
    Scenario Outline: Docstring and Examples
        Given a/an <implemented> cucumber
        Given a docstring:
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
        | flawed        | fail           |
        | implemented   | work           |

    Scenario: No Bullshit
        Given a/an implemented cucumber
        When cucumber reads this file
        Then it should work
```

This file (called "Test.feature") lives in my test sources and I told the package manager to copy it into the bundled resources:

```swift
let package = Package(
    ...
    targets: [
        ...
        .testTarget(name: "cucumber-swiftTests",
                    dependencies: ["CucumberSwift"],
                    resources: [.process("Test.feature")],
                    plugins: ["GenSteps"]) //notice also this one...
    ]
)
```

Now, in my test class, I did:

```swift
import XCTest
import CucumberSwift

final class cucumber_swiftTests: XCTestCase {
    func testRunAllScenarios() async throws {
        let bundle = Bundle.module
        guard let path = bundle.path(forResource: "Test", ofType: "feature") else {
            try cukeFail()
        }
        let cucumber = try Cucumber(reporter: DefaultReporter(snippetDialect: SnippetDialects.yaml))
        
        try await cucumber.run(URL(filePath: path))
    }
}
```

And I got the following console output:

```bash
Running feature "Test a variety of gherkin features"...
------------------------------------------------------------------------

	Scenario 28: "Docstring and Examples" has undefined steps.

	Scenario 35: "Docstring and Examples" has undefined steps.

	Scenario 42: "Docstring and Examples" has undefined steps.

	Scenario 49: "Docstring and Examples" has undefined steps.

	Scenario 54: "No Bullshit" has undefined steps.

------------------------------------------------------------------------

	Undefined steps:

groupName: MyGroup
steps:
 - step: "^I am a background step$"
   className: MyStep0
 - step: "^cucumber reads this file$"
   className: MyStep1
 - step: "^a/an implemented cucumber$"
   className: MyStep2
 - step: "^a docstring:$"
   className: MyStep3
 - step: "^it should work$"
   className: MyStep4
 - step: "^it should print snippets$"
   className: MyStep5
 - step: "^it should be pending$"
   className: MyStep6
 - step: "^a/an unimplemented cucumber$"
   className: MyStep7
 - step: "^it should fail$"
   className: MyStep8
 - step: "^a/an flawed cucumber$"
   className: MyStep9
 - step: "^a data table:$"
   className: MyStep10
 - step: "^a/an pending cucumber$"
   className: MyStep11

------------------------------------------------------------------------

Feature Test a variety of gherkin features completed with errors.
Total duration: 0.0003445 seconds.
Time with hooks: 0.000436791 seconds.
```

If you put these in a .yml file in your test target's source directory (or any target's source directory if the target uses the "GenSteps" plugin), a bunch of extensions will be generated - extensions for step types that you now need to implement!

The yaml format is designed in such a way that it can be used in conjunction with the vscode extension [Cucumber (Gherkin) Full Support](https://marketplace.visualstudio.com/items?itemName=alexkrechik.cucumberautocomplete) in order to validate your .feature files. But it also provides some useful capabilities to make it work better with swift.

1. The global "groupName" property names an array full of ```any Step```s that can be passed to Cucumber. If you reuse the same group name in different yaml files, the steps will be merged into one array.
2. The "className" attribute allows you to specify the name of the ```Step``` class you want to define to handle this specific regex.
3. If you use capture groups, they will be automatically converted into arguments. You will, however, need to define the argument names and types in an additional "arguments" list in the same step.
4. Supported argument types at the moment are "string", "int", "float" (which will be converted to String, Int and Float) and anything defined in the global "types" property.
5. Types need a name and then either an "external: true" declaration (in which case, it is assumed they are defined elsewhere) or a "kind: enum" property ("enum" is currently the only supported kind) and an array called "cases" consisting of strings.
6. Currently, for any type other than String, Int and Float, conversion is handled by calling ```init?(rawValue:)``` and force-unwrapping, so make sure your type can handle all strings that can come out of a capture group.

This is what a somewhat more realistic yaml might look like:

```yaml
groupName: globSteps
steps:
    - step: "^a\/an (unimplemented|pending|flawed|implemented) cucumber$"
      className: GivenCucumber
      arguments:
        - name: cukeState
          type: CukeState
    - step: "^it should (print snippets|be pending|fail|work)$"
      className: CukeExpectation
      arguments:
        - name: cukeResult
          type: CukeResult
    - step: "^a docstring:$"
      className: GivenDocString
    - step: "^a data table:$"
      className: GivenDataTable
    - step: "^cucumber reads this file$"
      className: CukeReadsFile
    - step: "^I am a background step$"
      className: BackgroundStep
types:
    - name: CukeState
      kind: enum
      cases:
       - unimplemented
       - pending
       - flawed
       - implemented
    - name: CukeResult
      external: true
```

The "GenSteps" plugin will take care that all the step classes conform to the ```Step``` protocol. All you need to do is to implement the type-specific ```onRecognize``` method which is required by the generated ```IMyType``` protocols.

## Property Wrappers and Macros

CucumberSwift provides several property wrappers to read or write scenario data, doc strings and data tables. Additionally, some convenience macros are provided.

### @Scenario

The ```@Scenario``` property wrapper can be used with steps and with hooks and grants access to an object that lives only during the scenario. It's of optional type and initially ```nil```, but setting it to ```nil``` is undefined behavior. It is assumed that steps or hooks using ```@Scenario``` introduce the object if it wasn't there yet. In an "after" hook, you are allowed to perform cleanup so long as you don't set the property to nil. If cleanup is performed through a ```deinit```, you don't have to do anything as the objects won't be retained beyond the scope of the scenario.

### @Required

Just like ```@Scenario```, ```@Required``` can be used both by steps and by hooks, but it does not have optional type. It is assumed that other steps have already provided this property. This will already be checked during injection, so "oh, but I don't use it on this code path" is not an excuse. If your step or hook somehow has branching logic and the property in question only needs to exist on some branches, use ```@Scenario```.

### @DocString

If for whatever reason you want access to a doc string in a step, ```@DocString``` is your friend.

### @ExampleList, @ExampleMap and @Examples

When reading a data table in a step, there are three ways how you could represent this:
- An array of arrays of strings, that is ```[[String]]``` - if you want this, ```@ExampleList``` is your friend.
- An array of dictionaries, that is ```[[String : String]]``` - if for whatever reason you want this, you want ```@ExampleMap```. The first row will be used for keys.
- Any array of custom types where once again, the first row serves to provide the keys. For this, use ```@Examples```.

### Macros

You may wonder how to actually *define* objects for a scenario that you can access with ```@Scenario``` or ```@Required```. This is done with the ```@ContainerStorage``` macro:

```swift
extension StateContainer {
    @ContainerStorage var cucumber : Cucumber?
    @ContainerStorage var file : URL?
    @ContainerStorage var result : CukeResult?
}
```

In your steps/hooks, you can then declare

```swift
struct MyStep {
    @Scenario(\.cucumber) var cucumber 
    @Required(\.file) var file
    //...
}
```

The other family of macros are only relevant if you want to manually define steps without yaml and the "GenSteps" plugin. They provide the Gherkin verbs ```#Given```, ```#And```, ```#When```, ```#Then``` and ```#But``` (and an additional more neutral ```#Match```) and can be used like this:

```swift
struct MyStep : Step {

    var matcher : some Matcher {
      #Given(#/^Hello, (.*)&/#) {name in 
        // do something with name
      }
    }

}
```

The macro basically makes sure the regex text is also available in a meaningful way for debugging.

## Hooks

Hooks will run before and/or after your scenarios. You can use them to do some general setup. You can also restrict hooks to run only for certain tags.

Here's the relevant protocols to conform to:

```swift
public protocol Hook {
    func shouldRun(_ tags: [String]) -> Bool
    func before() async throws
    func after() async throws
}

public protocol Hooks {
    /// Runs before/after the entire test suite
    /// - Warning: @Scenario and @Required will *not* be injected here and shouldRun will be ignored
    var globalHook : (any Hook)? { get }
    var hooks : [any Hook] {get}
}
```

Note that the "before" calls will be done in order of declaration (for those hooks that match the tags) and the "after" calls will be done in reverse order.

## Installation

In your Package.swift, add

```
dependencies: [
    .package(url: "https://github.com/AnarchoSystems/cucumber-swift.git",
                            from: "0.1.0"),
    ]
```

## Disclaimer

No, I do not officially work with the cucumber community. This is just a hobby. If this package (or your fork) helps you in any way, good for you! If you have an issue, feel free to raise it.
