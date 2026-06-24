import Foundation
import Gherkin

public protocol Step {
    var regexText: String { get }
    func match(_ step: PickleStep) throws -> (() async throws -> Void)?
    var reporter: any CukeReporter { get }
}