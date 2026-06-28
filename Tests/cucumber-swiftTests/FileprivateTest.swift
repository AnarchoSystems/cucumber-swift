import CucumberSwift

struct Foo: Step {

    @Scenario(\.cucumber) var cucumber

    @Given(/^Dummy step$/)
    func onRecognize() {}
}
