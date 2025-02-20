//
//  Gherkin.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

import Foundation

public struct Gherkin : Sendable {
    
    let gherkinURL : URL
    
    public init(_ url: URL) {
        self.gherkinURL = URL(fileURLWithPath: url.absoluteString)
    }
    
    public func read(_ url: URL) throws -> [Envelope] {
        try readFileData(file: url).map {str in
            let data = str.data(using: .utf8)!
            let decoder = JSONDecoder()
            return try decoder.decode(Envelope.self, from: data)
        }
    }
    
    @Sendable
    private func readFileData(file : URL) throws -> [String] {
        
        let process = Process()
        process.executableURL = gherkinURL
        
        process.arguments = [file.relativePath]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        let errPipe = Pipe()
        process.standardError = errPipe
        
        try process.run()
        
        process.waitUntilExit()
        
        guard process.terminationStatus == EXIT_SUCCESS else {
            
            if let data = try errPipe.fileHandleForReading.readToEnd(),
               let output = String(data: data, encoding: .utf8)
            {
                throw ProcessError(errorDescription: output)
            }
            else {
                throw ProcessError(errorDescription: "Unknown error")
            }
            
        }
        
        guard let data = try outputPipe.fileHandleForReading.readToEnd(),
              let output = String(data: data, encoding: .utf8) else {
            throw ProcessError(errorDescription: "Unknown error")
        }
        
        return output.split(separator: "\n").map(String.init)
        
    }
    
}

public struct ProcessError : LocalizedError {
    public let errorDescription: String
}
