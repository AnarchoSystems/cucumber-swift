//
//  Envelope.swift
//
//
//  Created by Markus Kasperczyk on 23.12.23.
//

import Foundation

public enum MessageType : String, CodingKey, Codable {
    case pickle, source, gherkinDocument
}

public enum Envelope : Codable {
    case pickle(Pickle)
    case source(Source)
    case gherkinDocument(GherkinDocument)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: MessageType.self)
        guard container.allKeys.count == 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "More than one message type found"))
        }
        switch container.allKeys.first! {
        case .pickle:
            self = try .pickle(container.decode(Pickle.self, forKey: .pickle))
        case .source:
            self = try .source(container.decode(Source.self, forKey: .source))
        case .gherkinDocument:
            self = try .gherkinDocument(container.decode(GherkinDocument.self, forKey: .gherkinDocument))
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .pickle(let pickle):
            try [MessageType.pickle : pickle].encode(to: encoder)
        case .source(let source):
            try [MessageType.source : source].encode(to: encoder)
        case .gherkinDocument(let gherkinDocument):
            try [MessageType.gherkinDocument : gherkinDocument].encode(to: encoder)
        }
    }
}

public struct Pickle : Codable {
    public let uri : String
    public let name : String
    public let id : String
    public let steps : [PickleStep]
}

public struct PickleStep : Codable {
    public let text : String
    public let argument : PickleArg?
}

public enum PickleArgType : String, CodingKey, Codable {
    case docString, dataTable
}

public enum PickleArg : Codable {
    case docString(String)
    case dataTable(DataTable)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PickleArgType.self)
        var allKeys = ArraySlice(container.allKeys)
        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
            throw DecodingError.typeMismatch(PickleArg.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
        }
        switch onlyKey {
        case .docString:
            struct DS : Codable {
                let content : String
            }
            let ds = try container.decode(DS.self, forKey: onlyKey)
            self = .docString(ds.content)
        case .dataTable:
            self = PickleArg.dataTable(try container.decode(DataTable.self, forKey: onlyKey))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .docString(let string):
                struct DS : Codable {
                    let content : String
                }
            try [PickleArgType.docString : DS(content: string)].encode(to: encoder)
        case .dataTable(let dataTable):
            try [PickleArgType.dataTable : dataTable].encode(to: encoder)
        }
    }
    
}

public struct DataTable : Codable {
    public struct Value : Codable {
        public let value : String
    }
    public struct Row : Codable {
        public let cells : [Value]
    }
    public let rows : [Row]
    func asLists() -> [[String]] {
        rows.map {row in
            row.cells.map(\.value)
        }
    }
    func asMaps() -> [[String : String]] {
        guard let header = rows.first else {
            return []
        }
        return rows.dropFirst().map {row in
            let keysAndVals : [(String, String)]
            = row.cells.enumerated().compactMap {idx, cell in
                guard header.cells.indices.contains(idx) else {return nil}
                return (header.cells[idx].value, cell.value)
            }
            return Dictionary(keysAndVals) {$1}
        }
    }
    func typed<T : Decodable>(_ type: T.Type) throws -> [T] {
        try JSONDecoder().decode([T].self, from: JSONEncoder().encode(asMaps()))
    }
}

public struct Source : Codable {
    let uri : String
    let data : String
}

public struct GherkinDocument : Codable {
    
}
