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
    func set(value: Atom, for attribute: String)
    // provide buffer memory with channel-major (planar) layout, notify update range to notify update the buffer
    func buffer(name: String, rate: Float64, rows: Int, cols: Int, buffer: UnsafeMutableBufferPointer<Float64>, stride: Int) -> (Range<Int>, Range<Int>)
}
extension EO { // default methods
    public func description(for terminal: Terminal) -> String { .init() }
    public func bang(at inlet: Int) {}
    public func list(at inlet: Int, value: Array<Atom>) -> Array<Atom> { .init() }
    public func symbol(at inlet: Int, value: String) {}
    public func number(at inlet: Int, value: Int64) {}
    public func number(at inlet: Int, value: Float64) {}
    public func set(value: Atom, for attribute: String) {}
    public func buffer(name: String, rate: Float64, rows: Int, cols: Int, buffer: UnsafeMutableBufferPointer<Float64>, stride: Int) -> (Range<Int>, Range<Int>) {
        (0..<rows, 0..<cols)
    }
}
public protocol MC: EO {
    var inputBusses: Array<Int> { get nonmutating set }
    var outputBusses: Array<Int> { get nonmutating set }
    // cursor, length, X, X row, X ldx, Y, X row, Y ldx
    func dsp(sampleRate: Float64, vectorSize: Int) throws -> @Sendable(Int, Int,
                                                                       UnsafePointer<Float64>, Int, Int,
                                                                       UnsafeMutablePointer<Float64>, Int, Int) -> Void
}
