//
//  Step.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

public protocol Step {
    associatedtype Args
    var match : Match<Args> {get}
}
