//
//  Buffer.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import XPC
public final class Buffer: @unchecked Sendable, XPCObject {
    @usableFromInline
    let start: UnsafeMutableRawPointer
    @usableFromInline
    let count: Int
    @inlinable
    public init(xpc object: xpc_object_t) {
        precondition(xpc_get_type(object) == XPC_TYPE_SHMEM)
        var`catch`: UnsafeMutableRawPointer?
        count = xpc_shmem_map(object, &`catch`)
        start = unsafeBitCast(`catch`, to: UnsafeMutableRawPointer.self)
    }
    @inlinable
    public init() {
        start = unsafeBitCast(Optional<UnsafeMutableRawPointer>.none, to: UnsafeMutableRawPointer.self)
        count = 0
    }
    deinit {
        munmap(start, count)
    }
}
extension Buffer {
    @inlinable
    public var xpc: xpc_object_t {
        xpc_shmem_create(start, count)
    }
}
extension Buffer {
    @inlinable
    public var unsafeMutableRawBufferPointer: UnsafeMutableRawBufferPointer {
        .init(start: start, count: count)
    }
    @inlinable
    public func withUnsafeMutableRawBufferPointer<E, R>(_ body: (UnsafeMutableRawBufferPointer) throws (E) -> R) rethrows -> R {
        try body(unsafeMutableRawBufferPointer)
    }
    @inlinable
    public func withUnsafeMutableBufferPointer<T: BitwiseCopyable, E, R>(_ body: (UnsafeMutableBufferPointer<T>) throws (E) -> R) rethrows -> R {
        try body(unsafeMutableRawBufferPointer.assumingMemoryBound(to: T.self))
    }
}
