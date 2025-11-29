//
//  Internal.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
public enum Terminal {
    case Inlet(Int)
    case Outlet(Int)
}
public protocol Internal: Sendable {
    init(args: Array<Atom>, notify: @escaping(Array<Atom>) -> Void)
    var inputBusses: Array<Int> { get nonmutating set }
    var outputBusses: Array<Int> { get nonmutating set }
    func description(for terminal: Terminal) -> String
    func bang(at inlet: Int)
    func list(at inlet: Int, value: Array<Atom>) -> Array<Atom>
    func symbol(at inlet: Int, value: String)
    func number(at inlet: Int, value: Int64)
    func number(at inlet: Int, value: Float64)
    func set(value: Atom, for key: String)
    // X, X row, X col, Y, X row, Y col, elapse, length
    func dsp(sampleRate: Float64, vectorSize: Int) throws -> @Sendable(UnsafePointer<Float64>, Int, Int,
                                                                       UnsafeMutablePointer<Float64>, Int, Int,
                                                                       Int, Int) -> Void
}
extension Internal { // default methods
    public func description(for terminal: Terminal) -> String { "" }
    public func bang(at inlet: Int) {}
    public func list(at inlet: Int, value: Array<Atom>) -> Array<Atom> { [] }
    public func symbol(at inlet: Int, value: String) {}
    public func number(at inlet: Int, value: Int64) {}
    public func number(at inlet: Int, value: Float64) {}
    public func set(value: Atom, for key: String) {}
}
