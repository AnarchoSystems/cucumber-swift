import Foundation
import Gherkin

public protocol StepDecorator: Step {
    var decoratedStep: any Step { get }
    init(_ decoratedStep: any Step)
    func run(_ stepCode: () async throws -> Void, _ matchedText: String) async throws
}

extension StepDecorator {
    public var regexText: String { decoratedStep.regexText }
    public func match(_ step: PickleStep) throws -> (() async throws -> Void)? {
        guard let stepCode = try decoratedStep.match(step) else { return nil }
        return {
            try await self.run(stepCode, step.text)
        }
    }
    public var reporter: any CukeReporter {
        decoratedStep.reporter
    }
}

extension StepCollection {
    public func map<Decorator: StepDecorator>(_ decorator: Decorator.Type) -> StepCollection {
        return StepCollection { pickle in
            self.computeStepDefs.map { f in StepCollection(steps: f(pickle).map(Decorator.init)) }
        }
    }
}
