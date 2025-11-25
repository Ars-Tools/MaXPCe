//
//  SinSynth.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import MXS
import simd
final class SinSynth: Internal, @unchecked Sendable {
    var inputBusses: Array<Int> = [1]
    var outputBusses: Array<Int> = [4]
    var frequency: Float64 = 440
    var amplitude: Float64 = 1
    let notifier: (Array<Atom>) -> Void
    init(args: Array<Atom>, notify: @escaping(Array<Atom>) -> Void) {
        notifier = notify
    }
    func set(value: Atom, for key: String) {
        switch key {
        case "freq":
            switch value {
            case.Integer(let val):
                frequency = .init(val)
            case.FloatingPoint(let val):
                frequency = val
            default:
                break
            }
        case "amp":
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
        return { [self] x, xr, xc, y, yr, yc, s, c in
            for ch in 0..<yr {
                for k in 0..<c {
                    y[k+ch*yc] = amplitude * sin(2.0 * .pi * frequency * Float64(k + s) / sampleRate)
                }
            }
        }
    }
}
