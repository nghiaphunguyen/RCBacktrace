//
//  RCBacktrace.swift
//  RCBackTrace
//
//  Created by roy.cao on 2019/8/27.
//  Copyright © 2019 roy. All rights reserved.
//

import Foundation

@_silgen_name("mach_backtrace")
func backtrace(
    _ thread: thread_t,
    stack: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
    _ maxSymbols: Int32
) -> Int32

public enum RCBacktrace {
    private static func mach_callstack(_ thread: thread_t) -> [StackSymbol] {
        var symbols = [StackSymbol]()
        let stackSize: UInt32 = 128
        let addrs = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(stackSize))
        defer { addrs.deallocate() }
        let frameCount = backtrace(thread, stack: addrs, Int32(stackSize))
        let buf = UnsafeBufferPointer(start: addrs, count: Int(frameCount))

        for (index, addr) in buf.enumerated() {
            guard let addr = addr else { continue }
            let addrValue = UInt(bitPattern: addr)
            symbols.append(StackSymbol(address: addrValue, index: index))
        }
        return symbols
    }

    public static var all: [Int: [String]] {
        var threads: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let taskInspect = mach_task_self_
        guard task_threads(taskInspect, &threads, &threadCount) == KERN_SUCCESS else {
            return [:]
        }

        var threadIDs = [thread_t]()
        for i in 0..<threadCount {
            guard let threadID = threads?[Int(i)] else { continue }
            threadIDs.append(threadID)
        }

        let backTraces = threadIDs.reduce([Int: [String]]()) { result, threadID in
            var result = result
            let symbols = Self.mach_callstack(threadID)
            let callstacks = symbols.map { $0.description }
            result[Int(threadID)] = callstacks

            return result
        }

        return backTraces
    }
}
