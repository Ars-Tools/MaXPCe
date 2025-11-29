//
//  SinSynth.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import MXO
import Synchronization
import simd
final class SinSynth: Internal, @unchecked Sendable {
    var inputBusses: Array<Int> = [1]
    var outputBusses: Array<Int> = [4]
    var frequency: Float64 = 438
    var amplitude: Float64 = 0
    let notifier: (Array<Atom>) -> Void
    init(args: Array<Atom>, notify: @escaping(Array<Atom>) -> Void) {
        notifier = notify
    }
    func bang(at inlet: Int) {
        notifier(["ok"])
    }
    func set(value: Atom, for key: String) {
        switch key {
        case "frequency":
            switch value {
            case.Integer(let val):
                frequency = .init(val)
            case.FloatingPoint(let val):
                frequency = val
            default:
                break
            }
        case "amplitude":
            switch value {
            case.Integer(let val):
                amplitude = .init(val)
            case.FloatingPoint(let val):
                amplitude = val
            default:
                break
            }
        default:
            break
        }
    }
    func dsp(sampleRate: Float64, vectorSize: Int) throws -> @Sendable(UnsafePointer<Float64>, Int, Int, UnsafeMutablePointer<Float64>, Int, Int, Int, Int) -> Void {
        notifier(["DSP Starts!"])
        return { [self]
            In, InChannelCount, InChannelStride,
            Out, OutChannelCount, OutChannelStride,
            CurrentTime, LengthToRender in
            // Standard Sinewave
//            for channel in 0..<OutChannelCount {
//                for index in 0..<LengthToRender {
//                    Out[index+channel*OutChannelStride] =
//                    amplitude * sin(2.0 * .pi * frequency * Float64(CurrentTime + index) / sampleRate)
//                }
//            }
//             Modulate Primary Input
            for channel in 0..<OutChannelCount {
                for index in 0..<LengthToRender {
                    let inputAmplitude = In[index]
                    let modulationAmplitude = amplitude * sin(2.0 * .pi * frequency * Float64(CurrentTime + index) / sampleRate)
                    Out[index+channel*OutChannelStride] = inputAmplitude * modulationAmplitude
                }
            }
        }
    }
}
