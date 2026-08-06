//
//  Atom.swift
//  MaXPCe
//
//  Created by Kota on 8/6/26.
//
public enum Atom: Sendable {
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
