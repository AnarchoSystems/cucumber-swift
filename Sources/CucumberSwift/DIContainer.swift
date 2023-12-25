//
//  DIContainer.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

public protocol DIContainerFactory {
    associatedtype Container : DIContainer
    func makeContainer() -> Container
}

public protocol DIContainer {
    func inject<S : Step>(into step: S) throws
}
