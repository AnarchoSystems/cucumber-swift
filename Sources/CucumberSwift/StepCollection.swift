import Gherkin

public struct StepCollection {
    let computeStepDefs: [(Pickle) -> [any Step]]

    public init(_ closure: @escaping (Pickle) -> [StepCollection]) {
        self.computeStepDefs = [
            { (pickle : Pickle) in
                closure(pickle)
                    .flatMap { c in
                        c.computeStepDefs
                            .flatMap { f in f(pickle) }
                    }
            }
        ]
    }

    public init(_ collections: [StepCollection] = [], steps: [any Step] = []) {
        self.computeStepDefs =
            collections.flatMap { c in c.computeStepDefs } + steps.map { s in { (_: Pickle) in [s] } }
    }
}
