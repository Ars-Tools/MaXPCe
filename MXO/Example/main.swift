//
//  main.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import Dispatch
import MXO
withExtendedLifetime(Service<Thru>(as: "tools.ars.xpc.matrix"), dispatchMain)
//withExtendedLifetime(External<SpeechRecognition>(as: "xpc.mxo.server"), dispatchMain)
