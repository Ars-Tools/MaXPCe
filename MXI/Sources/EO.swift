//
//  Macro.swift
//  MaXPCe
//
import Foundation
import MAX
final class EO: MAX.EO {
    @usableFromInline
    let outlet: @Sendable (Array<Atom>) -> Void
    @inlinable
    init(args: Array<Atom>, notify notifier: @escaping (Array<Atom>) -> Void) {
        outlet = unsafeBitCast(notifier, to: (@Sendable(Array<Atom>) -> Void).self)
    }
}
@_cdecl("core_new")
func new(args: CFArray, notifier: @Sendable @escaping @convention(block) (CFArray) -> Void) -> UnsafeMutableRawPointer {
    Unmanaged.passUnretained(EO(args: args as!Array<Atom>) {
        notifier($0 as CFArray)
    }).toOpaque()
}
@_cdecl("core_del")
func del(object: UnsafeMutableRawPointer) {
    Unmanaged<EO>.fromOpaque(object).release()
}
@_cdecl("core_bang")
func bang(object: UnsafeMutableRawPointer, at inlet: intptr_t) {
    Unmanaged<EO>.fromOpaque(object).takeUnretainedValue().bang(at: inlet)
}
@_cdecl("core_integer")
func integer(object: UnsafeMutableRawPointer, at inlet: intptr_t, value: Int64) {
    Unmanaged<EO>.fromOpaque(object).takeUnretainedValue().number(at: inlet, value: value)
}
@_cdecl("core_floatingpoint")
func floatingpoint(object: UnsafeMutableRawPointer, at inlet: intptr_t, value: Float64) {
    Unmanaged<EO>.fromOpaque(object).takeUnretainedValue().number(at: inlet, value: value)
}
@_cdecl("core_list")
func list(object: UnsafeMutableRawPointer, at inlet: intptr_t, value: CFArray) {
    Unmanaged<EO>.fromOpaque(object).takeUnretainedValue().list(at: inlet, value: value as?Array<Atom> ?? .init())
}
@_cdecl("core_anything")
func anything(object: UnsafeMutableRawPointer, at inlet: intptr_t, value: CFArray, selector: CFString, response: @convention(block) (CFArray) -> Void) {
    response(Unmanaged<EO>.fromOpaque(object).takeUnretainedValue().anything(at: inlet, value: value as?Array<Atom> ?? .init(), selector: selector as String) as CFArray)
}
