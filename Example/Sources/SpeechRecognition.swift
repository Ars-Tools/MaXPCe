//
//  SpeechRecognition.swift
//  MaXPCe
//
//  Created by Kota on 11/26/25.
//
import MXS
import Speech
import CoreAudio
final class SpeechRecognition: Internal, @unchecked Sendable {
    let recognizer: SFSpeechRecognizer
    let notifier: (Array<Atom>) -> Void
    var task: SFSpeechRecognitionTask?
    init(args: Array<Atom>, notify: @escaping (Array<Atom>) -> Void) {
        recognizer = .init(locale: .current).unsafelyUnwrapped
        notifier = notify
        print(recognizer.isAvailable)
        print(recognizer.supportsOnDeviceRecognition)
    }
    var inputBusses: Array<Int> {
        get { [1] }
        set {
            // ignore change
        }
    }
    var outputBusses: Array<Int> = []
    func dsp(sampleRate: Float64, vectorSize: Int) throws -> @Sendable (UnsafePointer<Float64>, Int, Int, UnsafeMutablePointer<Float64>, Int, Int, Int, Int) -> Void {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: sampleRate, channels: 1, interleaved: false).unsafelyUnwrapped
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        task = recognizer.recognitionTask(with: req) { [self] in
            if let result = $0 {
                notifier([.Symbol(result.bestTranscription.formattedString)])
            } else if let error = $1 {
                
            }
        }
        return { [self] x, _, _, _, _, _, _, c in
            let abl = AudioBufferList.allocate(maximumBuffers: 1)
            defer {
                abl.unsafePointer.deallocate()
            }
            abl[0] = .init(UnsafeMutableBufferPointer(start: .init(mutating: x), count: c), numberOfChannels: 1)
            let buf = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: abl.unsafePointer).unsafelyUnwrapped
            req.append(buf)
        }
    }
}
extension SFSpeechAudioBufferRecognitionRequest: @unchecked Sendable {}
