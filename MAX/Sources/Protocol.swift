//
//  Protocol.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
public enum Terminal {
    case Inlet(Int)
    case Outlet(Int)
}
public protocol EO: Sendable {
    init(args: Array<Atom>, notify: @escaping(Array<Atom>) -> Void)
    func description(for terminal: Terminal) -> String
    func bang(at inlet: Int)
    func list(at inlet: Int, value: Array<Atom>) -> Array<Atom>
    func symbol(at inlet: Int, value: String)
    func number(at inlet: Int, value: Int64)
    func number(at inlet: Int, value: Float64)
    func set(value: Atom, for key: String)
}
extension EO { // default methods
    public func description(for terminal: Terminal) -> String { "" }
    public func bang(at inlet: Int) {}
    public func list(at inlet: Int, value: Array<Atom>) -> Array<Atom> { [] }
    public func symbol(at inlet: Int, value: String) {}
    public func number(at inlet: Int, value: Int64) {}
    public func number(at inlet: Int, value: Float64) {}
    public func set(value: Atom, for key: String) {}
}
public protocol MC: EO {
    var inputBusses: Array<Int> { get nonmutating set }
    var outputBusses: Array<Int> { get nonmutating set }
    // cursor, length, X, X row, X ldx, Y, X row, Y ldx
    func dsp(sampleRate: Float64, vectorSize: Int) throws -> @Sendable(Int, Int,
                                                                       UnsafePointer<Float64>, Int, Int,
                                                                       UnsafeMutablePointer<Float64>, Int, Int) -> Void
}
