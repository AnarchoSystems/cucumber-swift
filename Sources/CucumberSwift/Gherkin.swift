//
//  Gherkin.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

import Foundation

public struct Gherkin {
    
    public init() {}
    
    public func stream(_ url: URL) throws -> AsyncThrowingMapSequence<AsyncFlatMapSequence<AsyncThrowingStream<URL, Error>, AsyncThrowingStream<String, Error>>, Envelope> {
        try toAsyncStream(getfiles(in: url)).flatMap(streamFileData(file:)).map {str in
            let data = str.data(using: .utf8)!
            let decoder = JSONDecoder()
            return try decoder.decode(Envelope.self, from: data)
        }
    }
    
    private func toAsyncStream<T>(_ array: [T]) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream {continuation in
            for elem in array {
                continuation.yield(elem)
            }
            continuation.finish()
        }
    }
    
    private func getfiles(in url: URL) throws -> [URL] {
        if url.isFileURL {
            return [url]
        }
        else if url.hasDirectoryPath {
            let fileMgr = FileManager.default
            return fileMgr.enumerator(at: url,
                                      includingPropertiesForKeys: nil)!.compactMap{$0 as? URL}
        }
        return []
    }
    
    private func streamFileData(file : URL) -> AsyncThrowingStream<String, Error> {
        
        AsyncThrowingStream {continuation in
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/gherkin")
            
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            
            process.arguments = [file.relativePath]
            
            actor DataMgr {
                var data = ""
                let continuation :  AsyncThrowingStream<String, Error>.Continuation
                let isErrMgr : Bool
                init(continuation: AsyncThrowingStream<String, Error>.Continuation, isErrMgr: Bool = false) {
                    self.continuation = continuation
                    self.isErrMgr = isErrMgr
                }
                func append(_ newData: Data) {
                    data += String(data: newData, encoding: .utf8) ?? ""
                    while let idx = data.firstIndex(of: "\n") {
                        yield(String(data[...idx]))
                        data = String(data[idx...].dropFirst())
                    }
                }
                func forceYield() {
                    if !data.isEmpty {
                        yield(data)
                        data = ""
                    }
                }
                private func yield(_ chunk: String) {
                    if isErrMgr {
                        continuation.yield(with: .failure(NSError(domain: "cucumber-swift", code: 1, userInfo: [NSLocalizedDescriptionKey: chunk])))
                    }
                    else {
                        continuation.yield(chunk)
                    }
                }
            }
            
            let dataMgr = DataMgr(continuation: continuation)
            let errMgr = DataMgr(continuation: continuation, isErrMgr: true)
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            outputPipe.fileHandleForReading.readabilityHandler = {handle in
                var data = handle.availableData
                while !data.isEmpty {
                    let localData = data
                    Task {
                        await dataMgr.append(localData)
                    }
                    data = handle.availableData
                }
            }
            
            let errPipe = Pipe()
            process.standardError = errPipe
            errPipe.fileHandleForReading.readabilityHandler = {handle in
                var data = handle.availableData
                while !data.isEmpty {
                    let localData = data
                    Task {
                        await errMgr.append(localData)
                    }
                    data = handle.availableData
                }
            }
            
            process.terminationHandler = {_ in
                Task {
                    await dataMgr.forceYield()
                    await errMgr.forceYield()
                    continuation.finish()
                }
            }
            
            do {
                try process.run()
            }
            catch {
                continuation.finish(throwing: error)
            }
        }
        
    }
    
}
