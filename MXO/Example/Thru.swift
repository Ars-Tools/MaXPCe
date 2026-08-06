//
//  Matrix.swift
//  MaXPCe
//
//  Created by Kota on 12/1/25.
//
import MAX
import MXO
import Synchronization
import simd
import Accelerate
final class Thru: MAX.MC, @unchecked Sendable {
    var inputBusses: Array<Int> = [1, 2, 3, 4]
    var outputBusses: Array<Int> = [1, 2, 3, 4]
    @inlinable
    init(args: Array<Atom>, notify: @escaping(Array<Atom>) -> Void) {
        
    }
    @inlinable
    func dsp(sampleRate: Float64, vectorSize: Int) throws -> @Sendable(Int, Int, UnsafePointer<Float64>, Int, Int, UnsafeMutablePointer<Float64>, Int, Int) -> Void {
        let row = outputBusses.reduce(0, +)
        let col = inputBusses.reduce(0, +)
        let weight = Array<Float64>(unsafeUninitializedCapacity: row * col) {
            $0.initialize(repeating: .zero)
            for k in 0..<min(row, col) {
                $0[k * col + k] = 1
            }
            $1 = $0.count
        }
        return { s, c, x, xr, xc, y, yr, yc in
            cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                        yr, c, xr,
                        1,
                        weight, col,
                        x, xc,
                        0,
                        y, yc)
        }
    }
}
