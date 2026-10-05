//
//  Atom.swift
//  MaXPCe
//
//  Created by Kota on 8/6/26.
//
public enum Atom: Sendable, Copyable {
    case Integer(Int64)
    case FloatingPoint(Float64)
    case Symbol(String)
}
extension Atom {
    public static let Bang: Atom = .Symbol("bang")
}
extension Atom: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: Int64) {
        self = .Integer(value)
    }
}
extension Atom: ExpressibleByFloatLiteral {
    @inlinable
    public init(floatLiteral value: Float64) {
        self = .FloatingPoint(value)
    }
}
extension Atom: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self = .Symbol(value)
    }
}
extension Atom: Hashable & Equatable {
    
}
extension Atom: Comparable {

}
extension Atom {
    @inlinable
    public var integer: Optional<Int64> {
        switch self {
        case.Integer(let number):
            .some(number)
        case.FloatingPoint(let number):
            .init(exactly: number)
        case.Symbol(let symbol) where symbol.starts(with: "0b"):
            .init(symbol.dropFirst(2), radix: 2)
        case.Symbol(let symbol) where symbol.starts(with: "0o"):
            .init(symbol.dropFirst(2), radix: 8)
        case.Symbol(let symbol) where symbol.starts(with: "0x"):
            .init(symbol.dropFirst(2), radix: 16)
        case.Symbol(let symbol):
            .init(symbol)
        }
    }
    @inlinable
    public var floatingPoint: Optional<Float64> {
        switch self {
        case.Integer(let number):
            .init(exactly: number)
        case.FloatingPoint(let number):
            .some(number)
        case.Symbol(let symbol):
            .init(symbol)
        }
    }
    @inlinable
    public var symbol: String {
        switch self {
        case.Integer(let number):
            number.description
        case.FloatingPoint(let number):
            number.description
        case.Symbol(let symbol):
            symbol
        }
    }
}
