//
//  Atom.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import XPC
import typealias MAX.Atom
extension Atom: XPCObject {
    @inlinable
    public init(xpc object: xpc_object_t) {
        switch xpc_get_type(object) {
        case XPC_TYPE_INT64:
            self = .Integer(xpc_int64_get_value(object))
        case XPC_TYPE_DOUBLE:
            self = .FloatingPoint(xpc_double_get_value(object))
        case XPC_TYPE_STRING:
            self = .Symbol(.init(xpc: object))
        default:
            preconditionFailure("Only Int64, Float64 and String can become an Atom")
        }
    }
    @inlinable
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
