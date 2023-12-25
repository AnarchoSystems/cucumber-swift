//
//  Match.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//


public struct Match<Args> {
    
    public let regex : Regex<Args>
    public let onRecognize : (Args) async throws -> Void
    
    public init(_ regex: Regex<Args>,
                onRecognize: @escaping (Args) async throws -> Void) {
        self.regex = regex
        self.onRecognize = onRecognize
    }
    
}
