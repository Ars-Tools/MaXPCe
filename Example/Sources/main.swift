//
//  main.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import Dispatch
import MXS
//withExtendedLifetime(External<SinSynth>(as: "xpc.mxo.server"), dispatchMain)
withExtendedLifetime(External<SpeechRecognition>(as: "xpc.mxo.server"), dispatchMain)
