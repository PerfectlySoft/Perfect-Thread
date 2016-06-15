//
//  ThreadQueue.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 2016-04-08.
//  Copyright © 2016 PerfectlySoft. All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

#if os(Linux)
    import SwiftGlibc
    import LinuxBridge
#else
    import Darwin
#endif

/// A thread queue which can dispatch a closure according to the queue type.
public protocol ThreadQueue {
    /// The queue name.
    var name: String { get }
    /// The queue type.
    var type: Threading.QueueType { get }
    /// Execute the given closure within the queue's thread.
    func dispatch(_ closure: Threading.ThreadClosure)
}

public extension Threading {
    
    private static var serialQueues = [String:ThreadQueue]()
    private static var concurrentQueues = [String:ThreadQueue]()
    private static let queuesLock = Threading.Lock()
    
    /// Queue type indicator.
    public enum QueueType {
        /// A queue which operates on only one thread.
        case serial
        /// A queue which operates on a number of threads, usually equal to the number of logical CPUs.
        case concurrent
    }
    
    private class SerialQueue: ThreadQueue {
        let name: String
        let type = Threading.QueueType.serial
        
        private typealias ThreadFunc = Threading.ThreadClosure
        private let lock = Threading.Event()
        private var q = [ThreadFunc]()
        
        init(name: String) {
            self.name = name
            self.startLoop()
        }
        
        func dispatch(_ closure: ThreadFunc) {
            let _ = self.lock.lock()
            defer { let _ = self.lock.unlock() }
            self.q.append(closure)
            let _ = self.lock.signal()
        }
        
        private func startLoop() {
            Threading.dispatchOnNewThread {
                while true {
                    var block: SerialQueue.ThreadFunc?
                    do {
                        let _ = self.lock.lock()
                        defer { let _ = self.lock.unlock() }
                        
                        let count = self.q.count
                        if count > 0 {
                            block = self.q.removeFirst()
                        } else {
                            let _ = self.lock.wait()
                            if self.q.count > 0 {
                                block = self.q.removeFirst()
                            }
                        }
                    }
                    if let b = block {
                        b()
                    }
                }
            }
        }
    }
    
    private class ConcurrentQueue: ThreadQueue {
        let name: String
        let type = Threading.QueueType.concurrent
        
        private typealias ThreadFunc = Threading.ThreadClosure
        private let lock = Threading.Event()
        private var q = [ThreadFunc]()
        
        init(name: String) {
            self.name = name
            self.startLoop()
        }
        
        func dispatch(_ closure: ThreadFunc) {
            let _ = self.lock.lock()
            defer { let _ = self.lock.unlock() }
            self.q.append(closure)
            let _ = self.lock.signal()
        }
        
        private func startLoop() {
            for _ in 0..<max(4, Threading.processorCount) {
                Threading.dispatchOnNewThread {
                    while true {
                        var block: ConcurrentQueue.ThreadFunc?
                        do {
                            let _ = self.lock.lock()
                            defer { let _ = self.lock.unlock() }
                            
                            let count = self.q.count
                            if count > 0 {
                                block = self.q.removeFirst()
                            } else {
                                let _ = self.lock.wait()
                            }
                        }
                        if let b = block {
                            b()
                        }
                    }
                }
            }
        }
    }
    
    private static var processorCount: Int {
    #if os(Linux)
        let num = sysconf(Int32(_SC_NPROCESSORS_ONLN))
    #else
        let num = sysconf(_SC_NPROCESSORS_ONLN)
    #endif
        return num
    }
    
    /// Find or create a queue indicated by name and type.
    public static func getQueue(name nam: String, type: QueueType) -> ThreadQueue {
        let _ = Threading.queuesLock.lock()
        defer { let _ = Threading.queuesLock.unlock() }
        
        switch type {
        case .serial:
            if let qTst = Threading.serialQueues[nam] {
                return qTst
            }
            let q = SerialQueue(name: nam)
            Threading.serialQueues[nam] = q
            return q
        case .concurrent:
            if let qTst = Threading.concurrentQueues[nam] {
                return qTst
            }
            let q = ConcurrentQueue(name: nam)
            Threading.concurrentQueues[nam] = q
            return q
        }
    }
    
    /// Call the given closure on the "default" concurrent queue
    /// Returns immediately.
    public static func dispatch(closure: Threading.ThreadClosure) {
        let q = Threading.getQueue(name: "default", type: .concurrent)
        q.dispatch(closure)
    }
    
    // This is a lower level function which does not utilize the ThreadQueue system.
    private static func dispatchOnNewThread(closure: ThreadClosure) {
    #if os(Linux)
        var thrdSlf = pthread_t()
    #else
        var thrdSlf = pthread_t(nil)
    #endif
        var attr = pthread_attr_t()
        
        pthread_attr_init(&attr)
        pthread_attr_setdetachstate(&attr, Int32(PTHREAD_CREATE_DETACHED))
        
        final class IsThisRequired {
            let closure: ThreadClosure
            init(closure: ThreadClosure) {
                self.closure = closure
            }
        }
        
        let holderObject = IsThisRequired(closure: closure)
        
    #if Xcode
        typealias ThreadFunction = @convention(c) (UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void>?
        let pthreadFunc: ThreadFunction = { p in
            let unleakyObject = Unmanaged<IsThisRequired>.fromOpaque(OpaquePointer(p)).takeRetainedValue()
            unleakyObject.closure()
            return nil
        }
    #else
        typealias ThreadFunction = @convention(c) (UnsafeMutablePointer<Void>?) -> UnsafeMutablePointer<Void>?
        let pthreadFunc: ThreadFunction = { p in
            if let pCheck = p {
                let unleakyObject = Unmanaged<IsThisRequired>.fromOpaque(OpaquePointer(pCheck)).takeRetainedValue()
                unleakyObject.closure()
            }
            return nil
        }
    #endif
        
        let leakyObject = UnsafeMutablePointer<Void>(OpaquePointer(bitPattern: Unmanaged.passRetained(holderObject)))
        pthread_create(&thrdSlf, &attr, pthreadFunc, leakyObject)
    }
}
