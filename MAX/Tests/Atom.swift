//
//  Atom+.swift
//  MaXPCe
//
//  Created by Kota on 11/29/25.
//
import Foundation
import Testing
@testable import MAX
@Suite
struct AtomTestCases {
    @Test
    func cffixnum() {
        let x = 10 as Atom
        let y = x as!NSNumber
        #expect(CFGetTypeID(y) == CFNumberGetTypeID())
        #expect(y == NSNumber(value: 10))
        let z = y as Atom
        #expect(z == x)
    }
    @Test
    func cfflxnum() {
        let x = 10.0 as Atom
        let y = x as!NSNumber
        #expect(CFGetTypeID(y) == CFNumberGetTypeID())
        #expect(y == NSNumber(value: 10))
        let z = y as Atom
        #expect(z == x)
    }
    @Test
    func cfstring() {
        let x = "🤖" as Atom
        let y = x as!NSString
        #expect(CFGetTypeID(y) == CFStringGetTypeID())
        #expect(y == NSString(string: "🤖"))
        let z = y as Atom
        #expect(z == x)
    }
    @Test
    func cfarray() {
        let x = [1, 1.2, "123"] as Array<Atom>
        let y = x as CFArray
        #expect(CFGetTypeID(y) == CFArrayGetTypeID())
        #expect(y == [1, 1.2, "123"] as CFArray)
        guard case.some(let z) = y as?Array<Atom> else {
            Issue.record()
            return
        }
        #expect(z == x)
    }
    @Test
    func cfOther() {
        let x = Date() as AnyObject
        let y = x as?Atom
        #expect(y == nil)
    }
    @Test
    func symParse() {
        let x = "12.5" as Atom
        #expect(x.floatingPoint == 12.5)
        let y = "1e+1" as Atom
        #expect(y.floatingPoint == 10)
        let z = "0xf" as Atom
        #expect(z.integer == 15)
        #expect(z.floatingPoint == 15)
    }
}
