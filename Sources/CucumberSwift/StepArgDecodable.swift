import Foundation
import Gherkin

public struct StepArgDecodeOptions {
    public let tableMajor: RowColMajor
    public let hasHeader: Bool

    public init(tableMajor: RowColMajor = .rowMajor, hasHeader: Bool = true) {
        self.tableMajor = tableMajor
        self.hasHeader = hasHeader
    }
}

public protocol DocStringDecodable {
    static func decode(from docString: String, mediatype: String?) throws -> [Self]
}

extension String: DocStringDecodable {
    public static func decode(from docString: String, mediatype _: String?) throws -> [String] {
        [docString]
    }
}

public protocol DataTableDecodable {
    static func decode(from data: [[String]], header: [String]?) throws -> [Self]
}

public extension Array where Element: DataTableDecodable {
    static func fromDataTable(
        _ table: Gherkin.PickleTable,
        options: StepArgDecodeOptions = .init()
    ) throws -> [Element] {
        try Element.decode(from: table, options: options)
    }
}

extension DataTableDecodable {
    public static func decode(
        from table: Gherkin.PickleTable,
        options: StepArgDecodeOptions = .init()
    ) throws -> [Self] {
        var data = [[String]]()
        var header: [String]? = nil
        switch options.tableMajor {
        case .rowMajor:
            if options.hasHeader {
                header = table.rows.first?.cells.map { $0.value }
                data = table.rows.dropFirst().map { $0.cells.map { $0.value } }
            } else {
                header = nil
                data = table.rows.map { $0.cells.map { $0.value } }
            }
        case .columnMajor:
            header = nil
            var colIdx = 0
            while true {
                var col: [String] = []
                if !table.rows.allSatisfy({ $0.cells.count > colIdx }) {
                    break
                }
                defer { colIdx += 1 }
                for row in table.rows {
                    col.append(row.cells[colIdx].value)
                }
                if options.hasHeader && colIdx == 0 {
                    header = col
                    continue
                }
                data.append(col)
            }
        }
        return try Self.decode(from: data, header: header)
    }
}

public enum CukeError: LocalizedError {
    case stepArgumentMissing(expected: String)
    case stepArgumentTypeMismatch(expected: String)
    case docStringDecodingError(String)
    case dataTableDecodingError(String)
    case regexArgDecodingError(String)
    case stepDecodingError(step: String, regex: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .stepArgumentMissing(expected):
            return "Missing step argument (expected: \(expected))"
        case let .stepArgumentTypeMismatch(expected):
            return "Step argument type mismatch (expected: \(expected))"
        case let .docStringDecodingError(message):
            return "Doc string decoding failed: \(message)"
        case let .dataTableDecodingError(message):
            return "Data table decoding failed: \(message)"
        case let .regexArgDecodingError(message):
            return "Regex argument decoding failed: \(message)"
        case let .stepDecodingError(step, regex, reason):
            return "Step decoding failed for '\(step)' with regex '\(regex)': \(reason)"
        }
    }
}

public protocol CodableDataTableDecodable: DataTableDecodable, Codable {}

extension CodableDataTableDecodable {
    public static func decode(from data: [[String]], header: [String]?) throws -> [Self] {
        guard let header = header else {
            throw CukeError.dataTableDecodingError(
                "Header is required for CodableDataTableDecodable")
        }
        var dictArray: [[String: String]] = []
        for row in data {
            guard row.count == header.count else {
                throw CukeError.dataTableDecodingError("Row count does not match header count")
            }
            let dict = Dictionary(uniqueKeysWithValues: zip(header, row))
            dictArray.append(dict)
        }
        return try JSONDecoder().decode([Self].self, from: JSONEncoder().encode(dictArray))
    }
}
