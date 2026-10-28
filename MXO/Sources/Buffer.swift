//
//  Buffer.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import XPC
public final class Buffer: Sendable, XPCObject {
    @usableFromInline
    nonisolated(unsafe)
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
    public init<T: BitwiseCopyable>(_ elements: some Collection<T>) {
        count = elements.count * MemoryLayout<T>.stride
        start = mmap(.none, count, PROT_READ|PROT_WRITE, MAP_ANON|MAP_SHARED, -1, 0)
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
