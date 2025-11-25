//
//  External.swift
//  MaXPCe
//
//  Created by Kota on 11/24/25.
//
import func Accelerate.vDSP_mmovD
@preconcurrency import XPC
@preconcurrency import Combine
import os.log
public struct External<MXO: Internal>: Sendable {
    @usableFromInline
    let log: OSLog
    @usableFromInline
    let dsp: DispatchQueue
    @usableFromInline
    let msg: DispatchQueue
}
extension External {
    @inlinable // dsp worker thread
    func dsp(render: @escaping@Sendable(Int, Int, Int, Int) -> Void) -> xpc_endpoint_t {
        let digress = xpc_connection_create(.none, .some(dsp))
        xpc_connection_set_event_handler(digress) { [unowned digress] in
            switch xpc_get_type($0) {
            case XPC_TYPE_CONNECTION:
                xpc_connection_set_event_handler($0) {
                    switch xpc_get_type($0) {
                    case XPC_TYPE_DICTIONARY:
                        guard
                            case.some(let s) = xpc_dictionary_get_value($0, "s"), xpc_get_type(s) == XPC_TYPE_INT64,
                            case.some(let c) = xpc_dictionary_get_value($0, "c"), xpc_get_type(c) == XPC_TYPE_INT64,
                            case.some(let i) = xpc_dictionary_get_value($0, "i"), xpc_get_type(i) == XPC_TYPE_INT64,
                            case.some(let o) = xpc_dictionary_get_value($0, "o"), xpc_get_type(o) == XPC_TYPE_INT64 else { break }
                        render(.init(xpc_int64_get_value(i)), .init(xpc_int64_get_value(o)), .init(xpc_int64_get_value(s)), .init(xpc_int64_get_value(c)))
                        if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                            xpc_connection_send_message(p, r)
                        }
                    default:
                        os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
                    }
                }
                xpc_connection_activate($0)
            case XPC_TYPE_ERROR where $0.isEqual(XPC_ERROR_CONNECTION_INVALID):
                if case.some(let ref) = xpc_connection_get_context(digress) {
                    Unmanaged<xpc_connection_t>.fromOpaque(ref).release()
                }
            default:
                os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
            }
        }
        xpc_connection_set_context(digress, Unmanaged.passRetained(digress).toOpaque())
        xpc_connection_activate(digress)
        return xpc_endpoint_create(digress)
    }
}
extension External {
    @inlinable
    func msg(args: Array<Atom>) -> xpc_endpoint_t {
        let express = xpc_connection_create(.none, .some(msg))
        xpc_connection_set_event_handler(express) { [unowned express] in
            switch xpc_get_type($0) {
            case XPC_TYPE_CONNECTION:
                let impress = MXO(args: args, notify: $0.notify(list:))
                xpc_connection_set_event_handler($0) {
                    switch xpc_get_type($0) {
                    case XPC_TYPE_DICTIONARY:
                        switch xpc_dictionary_get_string($0, "/").map(String.init(cString:)) {
                        case.some(":"):
                            guard
                                case.some(let p) = xpc_dictionary_get_remote_connection($0),
                                case.some(let r) = xpc_dictionary_create_reply($0) else { break }
                            xpc_dictionary_set_int64(r, "i", .init(impress.inputBusses.count))
                            xpc_dictionary_set_int64(r, "o", .init(impress.outputBusses.count))
                            xpc_connection_send_message(p, r)
                        case.some("?"): // help, return string
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64,
                                case.some(let v) = xpc_dictionary_get_value($0, ":"), xpc_get_type(v) == XPC_TYPE_BOOL,
                                case.some(let r) = xpc_dictionary_create_reply($0),
                                case.some(let p) = xpc_dictionary_get_remote_connection($0) else { break }
                            xpc_dictionary_set_string(r, "=", impress.description(for: xpc_bool_get_value(v) ? .Outlet(.init(xpc_int64_get_value(b))) : .Inlet(.init(xpc_int64_get_value(b)))))
                            xpc_connection_send_message(p, r)
                        case.some("<"): // input bus (setter)
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64,
                                case.some(let v) = xpc_dictionary_get_value($0, "="), xpc_get_type(v) == XPC_TYPE_INT64,
                                case.some(let r) = xpc_dictionary_create_reply($0),
                                case.some(let p) = xpc_dictionary_get_remote_connection($0) else { break }
                            let idx = Int(xpc_int64_get_value(b))
                            let val = xpc_int64_get_value(v)
                            if impress.inputBusses.indices.contains(idx) {
                                impress.inputBusses[idx] = .init(val)
                                xpc_dictionary_set_int64(r, "=", impress.inputBusses[idx] == val ? val : 0)
                            }
                            xpc_connection_send_message(p, r)
                        case.some(">"): // output bus (getter)
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64, //case.some(let v) = xpc_dictionary_get_value(msg, "="), xpc_get_type(v) == XPC_TYPE_INT64,
                                case.some(let r) = xpc_dictionary_create_reply($0),
                                case.some(let p) = xpc_dictionary_get_remote_connection($0) else { break }
                            let idx = Int(xpc_int64_get_value(b)) // let val = Int(xpc_int64_get_value(v))
                            if impress.outputBusses.indices.contains(idx) {
                                xpc_dictionary_set_int64(r, "=", .init(impress.outputBusses[idx]))
                            }
                            xpc_connection_send_message(p, r)
                        case.some("&"): // dsp chain
                            guard
                                case.some(let s) = xpc_dictionary_get_value($0, "s"), xpc_get_type(s) == XPC_TYPE_DOUBLE,
                                case.some(let c) = xpc_dictionary_get_value($0, "c"), xpc_get_type(c) == XPC_TYPE_INT64,
                                case.some(let m) = xpc_dictionary_get_value($0, "m"), xpc_get_type(m) == XPC_TYPE_SHMEM,
                                case.some(let n) = xpc_dictionary_get_value($0, "n"), xpc_get_type(n) == XPC_TYPE_INT64,
                                case.some(let i) = xpc_dictionary_get_value($0, "i"), xpc_get_type(i) == XPC_TYPE_ARRAY,
                                case.some(let o) = xpc_dictionary_get_value($0, "o"), xpc_get_type(o) == XPC_TYPE_ARRAY,
                                case.some(let r) = xpc_dictionary_create_reply($0),
                                case.some(let p) = xpc_dictionary_get_remote_connection($0) else { break }
                            do {
                                let render = try impress.dsp(sampleRate: xpc_double_get_value(s), vectorSize: .init(xpc_int64_get_value(c)))
                                let period = Int(xpc_int64_get_value(n))
                                let buffer = Buffer(xpc: m)
                                let sᵢ = repeatElement(i, count: xpc_array_get_count(i)).enumerated().compactMap {
                                    Int(exactly: xpc_array_get_int64($1, $0))
                                }.reduce(.max, min)
                                let sₒ = repeatElement(o, count: xpc_array_get_count(o)).enumerated().compactMap {
                                    Int(exactly: xpc_array_get_int64($1, $0))
                                }.reduce(.max, min)
                                xpc_dictionary_set_value(r, "=", dsp { i, o, start, count in
                                    withUnsafeTemporaryAllocation(of: Float64.self, capacity: max(i, o) * count) {
                                        guard case.some(let window) = $0.baseAddress else { return }
                                        let base = start % period
                                        let head = min(count, period - base)
                                        let tail = max(0, base + count - period)
                                        // enq
                                        let mᵢ = buffer.start.assumingMemoryBound(to: Float64.self).advanced(by: sᵢ)
                                        vDSP_mmovD(mᵢ.advanced(by: base), window, .init(head), .init(i), .init(period), .init(count))
                                        vDSP_mmovD(mᵢ, window.advanced(by: head), .init(tail), .init(i), .init(period), .init(count))
                                        render(window, i, count, window, o, count, start, count)
                                        let mₒ = buffer.start.assumingMemoryBound(to: Float64.self).advanced(by: sₒ)
                                        vDSP_mmovD(window, mₒ.advanced(by: base), .init(head), .init(o), .init(count), .init(period))
                                        vDSP_mmovD(window.advanced(by: head), mₒ, .init(tail), .init(o), .init(count), .init(period))
                                    }
                                })
                            } catch {
                                os_log(.error, log: log, "%{public}@", String(describing: error))
                            }
                            xpc_connection_send_message(p, r)
                        case.some("d"): // param dict
                            guard
                                case.some(let v) = xpc_dictionary_get_value($0, "="), xpc_get_type(v) == XPC_TYPE_DICTIONARY else { break }
                            xpc_dictionary_apply(v) {
                                impress.set(value: .init(xpc: $1), for: .init(cString: $0))
                                return true
                            }
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_connection_send_message(p, r)
                            }
                        case.some("p"): // param partial
                            guard
                                case.some(let k) = xpc_dictionary_get_value($0, "k"), xpc_get_type(k) == XPC_TYPE_STRING,
                                case.some(let v) = xpc_dictionary_get_value($0, "v") else { break }
                            impress.set(value: .init(xpc: v), for: .init(xpc: k))
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_connection_send_message(p, r)
                            }
                        case.some("b"): // bang
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64 else { break }
                            impress.bang(at: .init(xpc_int64_get_value(b)))
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_connection_send_message(p, r)
                            }
                        case.some("i"): // integer
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64,
                                case.some(let v) = xpc_dictionary_get_value($0, "="), xpc_get_type(v) == XPC_TYPE_INT64 else { break }
                            impress.number(at: .init(xpc_int64_get_value(b)), value: xpc_int64_get_value(v))
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_connection_send_message(p, r)
                            }
                        case.some("f"): // floatingPoint
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64,
                                case.some(let v) = xpc_dictionary_get_value($0, "="), xpc_get_type(v) == XPC_TYPE_INT64 else { break }
                            impress.number(at: .init(xpc_int64_get_value(b)), value: xpc_double_get_value(v))
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_connection_send_message(p, r)
                            }
                        case.some("s"): // symbol
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64,
                                case.some(let v) = xpc_dictionary_get_value($0, "="), xpc_get_type(v) == XPC_TYPE_STRING else { break }
                            impress.symbol(at: .init(xpc_int64_get_value(b)), value: .init(xpc: v))
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_connection_send_message(p, r)
                            }
                        case.some("l"): // list
                            guard
                                case.some(let b) = xpc_dictionary_get_value($0, "#"), xpc_get_type(b) == XPC_TYPE_INT64,
                                case.some(let v) = xpc_dictionary_get_value($0, "="), xpc_get_type(v) == XPC_TYPE_ARRAY else { break }
                            let result = impress.list(at: .init(xpc_int64_get_value(b)), value: .init(xpc: v))
                            if case.some(let r) = xpc_dictionary_create_reply($0), case.some(let p) = xpc_dictionary_get_remote_connection($0) {
                                xpc_dictionary_set_value(r, "=", result.xpc)
                                xpc_connection_send_message(p, r)
                            }
                        default:
                            os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
                        }
                    default:
                        os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
                    }
                }
                xpc_connection_activate($0)
            case XPC_TYPE_ERROR where $0.isEqual(XPC_ERROR_CONNECTION_INVALID):
                if case.some(let ref) = xpc_connection_get_context(express) {
                    Unmanaged<xpc_connection_t>.fromOpaque(ref).release()
                }
            default:
                os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
            }
        }
        xpc_connection_set_context(express, Unmanaged.passRetained(express).toOpaque())
        xpc_connection_activate(express)
        return xpc_endpoint_create(express)
    }
}
extension External {
    @inlinable
    public init(as name: String, on queue: Optional<DispatchQueue> = .none) {
        log = .init(subsystem: name, category: .dynamicTracing)
        msg = .init(label: name)
        dsp = .global(qos: .userInitiated)
        let ingress = xpc_connection_create_mach_service(name, queue, .init(XPC_CONNECTION_MACH_SERVICE_LISTENER))
        xpc_connection_set_event_handler(ingress) { [unowned ingress, self] in
            switch xpc_get_type($0) {
            case XPC_TYPE_CONNECTION:
                xpc_connection_set_event_handler($0) {
                    switch xpc_get_type($0) {
                    case XPC_TYPE_DICTIONARY:
                        guard
                            case.some(let a) = xpc_dictionary_get_array($0, "="),
                            case.some(let p) = xpc_dictionary_get_remote_connection($0),
                            case.some(let r) = xpc_dictionary_create_reply($0) else { break }
                        xpc_dictionary_set_value(r, "=", msg(args: .init(xpc: a)))
                        xpc_connection_send_message(p, r)
                    default:
                        os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
                    }
                }
                xpc_connection_activate($0)
            case XPC_TYPE_ERROR where $0.isEqual(XPC_ERROR_CONNECTION_INVALID):
                if case.some(let ref) = xpc_connection_get_context(ingress) {
                    Unmanaged<xpc_connection_t>.fromOpaque(ref).release()
                }
            default:
                os_log(.info, log: log, "%{public}@ is not handled @%d", String(describing: $0), #line)
            }
        }
        xpc_connection_set_context(ingress, Unmanaged.passRetained(ingress).toOpaque())
        xpc_connection_activate(ingress)
    }
}
