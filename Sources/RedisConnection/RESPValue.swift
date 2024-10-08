public indirect enum RESPValue: Sendable, Hashable {
    // <implemented>/<unit tests decode>/<unit test encode
    case simpleString(String) // ✅🔲🔲 RESP 2+: `+<string>\r\n`
    case errorString(String) // ✅🔲🔲 RESP 2+: `-<string>\r\n`
    case integer(Int) // ✅🔲🔲 RESP 2+: `:<number>\r\n`
    case blobString([UInt8]) // ✅🔲🔲 RESP 2+: `$<length>\r\n<bytes>\r\n`
    case nullBulkString // ✅🔲🔲 RESP 2:  `$-1\r\n
    case nullArray // ✅🔲🔲 RESP 2:  `*-1\r\n`
    case null // ✅✅🔲 RESP 3:  `_\r\n`
    case double(Double) // ✅🔲🔲 RESP 3:  `,<floating-point-number>\r\n`
    case boolean(Bool) // ✅✅🔲 RESP 3:  `#t\r\n` / `#f\r\n`
    case blobError([UInt8]) // ✅✅🔲 RESP 3:  `!<length>\r\n<bytes>\r\n`
    case verbatimString([UInt8]) // ✅✅🔲 RESP 3:  `=<length>\r\n<bytes>`
    case bigNumber([UInt8]) // ✅🔲🔲 RESP 3:  `(<big number>\r\n`
    case array([Self]) // ✅🔲🔲 RESP 2+: `*<count>\r\n<elements>`
    case map([Self: Self]) // ✅✅🔲 RESP 3+: `%<count>\r\n<elements>`
    case set(Set<Self>) // ✅✅🔲 RESP 3+: `~<count>\r\n<elements>`
    case attribute([Self: Self]) // ✅🔲🔲 RESP 3+: `|<count>\r\n<elements>`
    case pubsub(Pubsub) // ✅🔲🔲 RESP 3+: `><count>\r\n<elements>` // TODO - this may not be exactly how this works
}

public struct Pubsub: Sendable, Hashable {
    public enum Kind: String, Sendable {
        case message
        case subscribe
        case unsubscribe
    }

    public var kind: Kind
    public var channel: String
    public var value: RESPValue
}

public extension RESPValue {
    static func blobString(_ string: String) -> RESPValue {
        blobString(Array(string.utf8))
    }

    var integerValue: Int {
        get throws {
            guard case .integer(let value) = self else {
                throw RedisError.typeMismatch
            }
            return value
        }
    }

    var stringValue: String {
        get throws {
            switch self {
            case .simpleString(let value), .errorString(let value):
                return value
            case .blobString(let value), .blobError(let value), .verbatimString(let value):
                // TODO: encoding is safe to assume?
                guard let value = String(bytes: value, encoding: .utf8) else {
                    throw RedisError.stringDecodingError
                }
                return value
            default:
                throw RedisError.typeMismatch
            }
        }
    }

    var arrayValue: [RESPValue] {
        get throws {
            switch self {
            case .array(let array):
                return array
            default:
                throw RedisError.typeMismatch
            }
        }
    }

    var pubsubValue: Pubsub {
        get throws {
            switch self {
            case .pubsub(let value):
                return value
            default:
                throw RedisError.typeMismatch
            }
        }
    }
}

public extension RESPValue {
    func encode() throws -> [UInt8] {
        switch self {
        case .simpleString(let value):
            return Array("+\(value)\r\n".utf8)
        case .errorString(let value):
            return Array("-\(value)\r\n".utf8)
        case .integer(let value):
            return Array(":\(value)\r\n".utf8)
        case .blobString(let value):
            return Array("$\(value.count)\r\n".utf8) + value + Array("\r\n".utf8)
        case .nullBulkString:
            return Array("$-1\r\n".utf8)
        case .array(let values):
            let encodedValues = try values.flatMap { try $0.encode() }
            return Array("*\(values.count)\r\n".utf8) + encodedValues
        case .nullArray:
            return Array("*-1\r\n".utf8)
        case .null:
            return Array("_\r\n".utf8)
        case .boolean(let value):
            return Array("#\(value ? "t" : "f")\r\n".utf8)
        case .blobError(let value):
            return Array("!\(value.count)\r\n".utf8) + value + Array("\r\n".utf8)
        case .verbatimString(let value):
            return Array("=\(value.count)\r\n".utf8) + value + Array("\r\n".utf8)
        case .bigNumber(let value):
            return Array("+\(value)\r\n".utf8)
        case .double:
            fatalError("Inimplemented")
        case .map:
            fatalError("Inimplemented")
        case .set:
            fatalError("Inimplemented")
        case .attribute:
            fatalError("Inimplemented")
        case .pubsub:
            fatalError("Inimplemented")
        }
    }
}

extension RESPValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .simpleString(let value):
            value
        case .errorString(let value):
            value
        case .integer(let value):
            "\(value)"
        case .blobString(let value):
            String(bytes: value, encoding: .utf8)!
        case .nullBulkString:
            "<nil-string>"
        case .array(let values):
            "[" + values.map(\.description).joined(separator: ", ") + "]"
        case .nullArray:
            "<nil-array>"
        case .null:
            "<null>"
        case .double(let value):
            "\(value)"
        case .boolean(let value):
            "\(value)"
        case .blobError(let value):
            String(bytes: value, encoding: .utf8)!
        case .verbatimString(let value):
            String(bytes: value, encoding: .utf8)!
        case .bigNumber(let value):
            ".bigNumber(\(value))"
        case .map(let values):
            ".map([" + values.map { "\($0.key.description): \($0.value.description)" }.joined(separator: ", ") + "])"
        case .set(let values):
            ".set([" + values.map(\.description).joined(separator: ", ") + "])"
        case .attribute(let values):
            ".attribute([" + values.map { "\($0.key.description): \($0.value.description)" }.joined(separator: ", ") + "])"
        case .pubsub(let value):
            "pubsub(\(String(describing: value))"
        }
    }
}
