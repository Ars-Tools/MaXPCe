//
//  Atom+.swift
//  MaXPCe
//
//  Created by Kota on 8/6/26.
//
import CoreFoundation
extension Atom: _ObjectiveCBridgeable {
    public typealias _ObjectiveCType = CFTypeRef
    @inlinable
    public func _bridgeToObjectiveC() -> _ObjectiveCType {
        switch self {
        case.Integer(let number):
            withUnsafeBytes(of: number) {
                CFNumberCreate(kCFAllocatorDefault, .sInt64Type, $0.baseAddress)
            }
        case.FloatingPoint(let number):
            withUnsafeBytes(of: number) {
                CFNumberCreate(kCFAllocatorDefault, .float64Type, $0.baseAddress)
            }
        case.Symbol(let symbol):
            CFStringCreateWithCString(kCFAllocatorDefault, symbol, .init(CFStringBuiltInEncodings.UTF8.rawValue))
        }
    }
    @inlinable
    public static func _forceBridgeFromObjectiveC(_ source: _ObjectiveCType, result: inout Atom?) {
        switch source {
        case let number as CFNumber where CFGetTypeID(number) == CFNumberGetTypeID() && CFNumberIsFloatType(number):
            var native = 0 as Float64
            precondition(CFNumberGetValue(number, .float64Type, &native))
            result = .some(.FloatingPoint(native))
        case let number as CFNumber where CFGetTypeID(number) == CFNumberGetTypeID():
            var native = 0 as Int64
            precondition(CFNumberGetValue(number, .sInt64Type, &native))
            result = .some(.Integer(native))
        case let symbol as CFString where CFGetTypeID(symbol) == CFStringGetTypeID():
            result = .some(.Symbol(withUnsafeTemporaryAllocation(of: UInt16.self, capacity: CFStringGetLength(symbol)) {
                CFStringGetCharacters(symbol, CFRange(location: 0, length: $0.count), $0.baseAddress)
                return.init(decoding: $0, as: UTF16.self)
            }))
        default:
            break
        }
    }
    @inlinable
    public static func _conditionallyBridgeFromObjectiveC(_ source: _ObjectiveCType, result: inout Atom?) -> Bool {
        switch source {
        case let number as CFNumber where CFGetTypeID(number) == CFNumberGetTypeID() && CFNumberIsFloatType(number):
            var native = 0 as Float64
            precondition(CFNumberGetValue(number, .float64Type, &native))
            result = .some(.FloatingPoint(native))
            return true
        case let number as CFNumber where CFGetTypeID(number) == CFNumberGetTypeID():
            var native = 0 as Int64
            precondition(CFNumberGetValue(number, .sInt64Type, &native))
            result = .some(.Integer(native))
            return true
        case let symbol as CFString where CFGetTypeID(symbol) == CFStringGetTypeID():
            result = .some(.Symbol(withUnsafeTemporaryAllocation(of: UInt16.self, capacity: CFStringGetLength(symbol)) {
                CFStringGetCharacters(symbol, CFRange(location: 0, length: $0.count), $0.baseAddress)
                return.init(decoding: $0, as: UTF16.self)
            }))
            return true
        default:
            return false
        }
    }
    @inlinable
    public static func _unconditionallyBridgeFromObjectiveC(_ source: _ObjectiveCType?) -> Atom {
        switch source {
        case.some(let number as CFNumber) where CFGetTypeID(number) == CFNumberGetTypeID() && CFNumberIsFloatType(number):
            var native = 0 as Float64
            precondition(CFNumberGetValue(number, .float64Type, &native))
            return.FloatingPoint(native)
        case.some(let number as CFNumber) where CFGetTypeID(number) == CFNumberGetTypeID():
            var native = 0 as Int64
            precondition(CFNumberGetValue(number, .sInt64Type, &native))
            return.Integer(native)
        case.some(let symbol as CFString) where CFGetTypeID(symbol) == CFStringGetTypeID():
            return.Symbol(withUnsafeTemporaryAllocation(of: UInt16.self, capacity: CFStringGetLength(symbol)) {
                CFStringGetCharacters(symbol, CFRange(location: 0, length: $0.count), $0.baseAddress)
                return.init(decoding: $0, as: UTF16.self)
            })
        case.some(let other):
            let symbol = CFCopyDescription(other)
            return.Symbol(withUnsafeTemporaryAllocation(of: UInt16.self, capacity: CFStringGetLength(symbol)) {
                CFStringGetCharacters(symbol, CFRange(location: 0, length: $0.count), $0.baseAddress)
                return.init(decoding: $0, as: UTF16.self)
            })
        case.none:
            let symbol = CFCopyDescription(kCFNull)
            return.Symbol(withUnsafeTemporaryAllocation(of: UInt16.self, capacity: CFStringGetLength(symbol)) {
                CFStringGetCharacters(symbol, CFRange(location: 0, length: $0.count), $0.baseAddress)
                return.init(decoding: $0, as: UTF16.self)
            })
        }
    }
}
