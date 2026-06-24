
public protocol RegexArgDecodable {
    static func decode(from match: Substring) throws -> Self
}

public protocol CukeStringRawRepresentable: RegexArgDecodable, RawRepresentable where RawValue == String {}

public extension CukeStringRawRepresentable {
    static func decode(from match: Substring) throws -> Self {
        guard let value = Self(rawValue: String(match)) else {
            throw CukeError.regexArgDecodingError("Cannot decode '\(match)' as \(Self.self)")
        }
        return value
    }
}

extension String: RegexArgDecodable {
    public static func decode(from match: Substring) throws -> String { String(match) }
}

extension Substring: RegexArgDecodable {
    public static func decode(from match: Substring) throws -> Substring { match }
}

extension Int: RegexArgDecodable {
    public static func decode(from match: Substring) throws -> Int {
        guard let value = Int(match) else {
            throw CukeError.regexArgDecodingError("Cannot decode '\(match)' as Int")
        }
        return value
    }
}

extension Double: RegexArgDecodable {
    public static func decode(from match: Substring) throws -> Double {
        guard let value = Double(match) else {
            throw CukeError.regexArgDecodingError("Cannot decode '\(match)' as Double")
        }
        return value
    }
}

extension Float: RegexArgDecodable {
    public static func decode(from match: Substring) throws -> Float {
        guard let value = Float(match) else {
            throw CukeError.regexArgDecodingError("Cannot decode '\(match)' as Float")
        }
        return value
    }
}

extension Bool: RegexArgDecodable {
    public static func decode(from match: Substring) throws -> Bool {
        switch match.lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            throw CukeError.regexArgDecodingError("Cannot decode '\(match)' as Bool")
        }
    }
}