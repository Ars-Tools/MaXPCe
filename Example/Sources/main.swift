//
//  main.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import Dispatch
import MXS
withExtendedLifetime(External<SinSynth>(as: "tools.ars.xpc.mxo.SinSynth"), dispatchMain)
