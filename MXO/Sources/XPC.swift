//
//  XPC.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import XPC
import MAX
public protocol XPCObject: Sendable {
    init(xpc object: xpc_object_t)
    var xpc: xpc_object_t { get }
}
extension String {
    @inlinable
    public init(xpc object: xpc_object_t) {
        precondition(xpc_get_type(object) == XPC_TYPE_STRING)
        self = UnsafeBufferPointer(start: xpc_string_get_string_ptr(object),
                                   count: xpc_string_get_length(object)
        ).withMemoryRebound(to: UInt8.self) {
            .init(decoding: $0, as: UTF8.self)
        }
    }
}
extension xpc_connection_t {
    @inlinable
    func notify(list: Array<Atom>) {
        precondition(xpc_get_type(self) == XPC_TYPE_CONNECTION)
        let req = xpc_dictionary_create_empty()
        xpc_dictionary_set_string(req, "/", "n")
        xpc_dictionary_set_value(req, "=", list.xpc)
        xpc_connection_send_message(self, req)
    }
}
