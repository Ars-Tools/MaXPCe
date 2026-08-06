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
    func test() {
        #expect(Atom.Integer(500) == 500 as Atom)
        guard case.Integer(500) = Atom(cftype: 500 as CFNumber) else {
            Issue.record()
            return
        }
        #expect(Atom.FloatingPoint(0.5) == 0.5 as Atom)
        guard case.FloatingPoint(0.5) = Atom(cftype: 0.5 as CFNumber) else {
            Issue.record()
            return
        }
        #expect(Atom.Symbol("123") == "123" as Atom)
        guard case.Symbol("123") = Atom(cftype: "123" as CFString) else {
            Issue.record()
            return
        }
    }
}
