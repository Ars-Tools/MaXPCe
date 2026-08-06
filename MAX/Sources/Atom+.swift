//
//  Atom+.swift
//  MaXPCe
//
//  Created by Kota on 8/6/26.
//
import Foundation
extension Atom {
    @inlinable
    public init(cftype ref: CFTypeRef) {
        switch ref {
        case let number as CFNumber where CFGetTypeID(number) == CFNumberGetTypeID() && CFNumberIsFloatType(number):
            var num = 0 as Float64
            precondition(CFNumberGetValue(number, .float64Type, &num))
            self = .FloatingPoint(num)
        case let number as CFNumber where CFGetTypeID(number) == CFNumberGetTypeID():
            var num = 0 as Int64
            precondition(CFNumberGetValue(number, .sInt64Type, &num))
            self = .Integer(num)
        case let symbol as CFString where CFGetTypeID(symbol) == CFStringGetTypeID():
            self = .Symbol(symbol as String)
        default:
            preconditionFailure()
        }
    }
}
