//
//  Atom.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import XPC
public enum Atom: Sendable {
    case Integer(Int64)
    case FloatingPoint(Float64)
    case Symbol(String)
}
extension Atom {
    public static let Bang: Atom = .Symbol("bang")
}
extension Atom: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .Integer(value)
    }
}
extension Atom: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Float64) {
        self = .FloatingPoint(value)
    }
}
extension Atom: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .Symbol(value)
    }
}
extension Atom: Hashable & Equatable {
    
}
extension Atom: XPCObject {
    public init(xpc object: xpc_object_t) {
        switch xpc_get_type(object) {
        case XPC_TYPE_INT64:
            self = .Integer(xpc_int64_get_value(object))
        case XPC_TYPE_DOUBLE:
            self = .FloatingPoint(xpc_double_get_value(object))
        case XPC_TYPE_STRING:
            self = .Symbol(.init(xpc: object))
        default:
            preconditionFailure("Only Int64, Float64 and String can become Atom")
        }
    }
    public var xpc: xpc_object_t {
        switch self {
        case.Integer(let number):
            xpc_int64_create(number)
        case.FloatingPoint(let number):
            xpc_double_create(number)
        case.Symbol(let string):
            xpc_string_create(string)
        }
    }
}
