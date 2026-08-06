//
//  List.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import XPC
import typealias MAX.List
extension Array where Element: XPCObject {
    @inlinable
    public init(xpc object: xpc_object_t) {
        precondition(xpc_get_type(object) == XPC_TYPE_ARRAY)
        self.init()
        xpc_array_apply(object) {
            append(.init(xpc: $1))
            return true
        }
    }
    @inlinable
    public var xpc: xpc_object_t {
        let object = xpc_array_create_empty()
        for atom in self {
            xpc_array_append_value(object, atom.xpc)
        }
        return object
    }
}
extension Array where Element: BinaryInteger {
    @inlinable
    init(parseInt64 array: xpc_object_t) {
        self.init()
        xpc_array_apply(array) {
            precondition(xpc_get_type($1) == XPC_TYPE_INT64)
            switch Element(exactly: xpc_int64_get_value($1)) {
            case.some(let val):
                append(val)
            case.none:
                assertionFailure()
            }
            return true
        }
    }
}
extension List: XPCObject {}
