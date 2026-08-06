//
//  Bundle.swift
//  MaXPCe
//
//  Created by Kota on 11/29/25.
//
import CoreFoundation
import MXO
@MainActor
@_cdecl("maxpce_mxi_new")
func new(native: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    fatalError()
}
@MainActor
@_cdecl("maxpce_mxi_del")
func del(object: UnsafeMutableRawPointer) {
    fatalError()
}
@_cdecl("maxpce_mxi_int")
func int(object: UnsafeMutableRawPointer, val: Int64) {
    
}
@_cdecl("maxpce_mxi_flt")
func flt(object: UnsafeMutableRawPointer, val: Float64) {
    fatalError()
}
@_cdecl("maxpce_mxi_sym")
func sym(object: UnsafeMutableRawPointer, val: UnsafePointer<CChar>) {
    fatalError()
}
@_cdecl("maxpce_mxi_list")
func list(object: UnsafeMutableRawPointer, list: CFArray) -> Optional<CFArray> {
    fatalError()
}
@_cdecl("maxpce_mxi_ich")
func ich(object: UnsafeMutableRawPointer, at index: Int64, count: Int64) -> Int64 {
    fatalError()
}
@_cdecl("maxpce_mxi_och")
func och(object: UnsafeMutableRawPointer, at index: Int64) -> Int64 {
    fatalError()
}
@_cdecl("maxpce_mxi_setup")
func setup(object: UnsafeMutableRawPointer, sampleRate: Float64, vectorSize: Int64) {
    fatalError()
}
@_cdecl("maxpce_mxi_dsp64")
func dsp64(object: UnsafeMutableRawPointer,
           i: UnsafeMutablePointer<Float64>, ic: Int64,
           o: UnsafeMutablePointer<Float64>, oc: Int64,
           count: Int) {
    fatalError()
}
