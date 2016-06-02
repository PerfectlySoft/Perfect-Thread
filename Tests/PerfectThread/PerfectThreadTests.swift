//
//  Package.swift
//  PerfectThread
//
//  Created by Kyle Jessup on 2016-05-02.
//	Copyright (C) 2016 PerfectlySoft, Inc.
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
    import LinuxBridge
#else
    import Darwin
#endif

import XCTest
@testable import PerfectThread

class PerfectThreadTests: XCTestCase {
    
    func getNow() -> Double {
        var posixTime = timeval()
        gettimeofday(&posixTime, nil)
        return Double((posixTime.tv_sec * 1000) + (Int(posixTime.tv_usec)/1000))
    }
    
    func testConcurrentQueue() {
        let q = Threading.getQueue(name: "concurrent", type: .Concurrent)
        
        var t1 = 0, t2 = 0, t3 = 0
        
        q.dispatch {
            t1 = 1
            Threading.sleep(seconds: 5)
        }
        q.dispatch {
            t2 = 1
            Threading.sleep(seconds: 5)
        }
        q.dispatch {
            t3 = 1
            Threading.sleep(seconds: 5)
        }
        Threading.sleep(seconds: 1)
        
        XCTAssert(t1 == 1 && t2 == 1 && t3 == 1)
    }
    
    func testSerialQueue() {
        let q = Threading.getQueue(name: "serial", type: .Serial)
        
        var t1 = 0
        
        q.dispatch {
            XCTAssert(t1 == 0)
            t1 = 1
        }
        q.dispatch {
            XCTAssert(t1 == 1)
            t1 = 2
        }
        q.dispatch {
            XCTAssert(t1 == 2)
            t1 = 3
        }
        Threading.sleep(seconds: 2)
        XCTAssert(t1 == 3)
    }

    func testThreadSleep() {
        let now = getNow()
        Threading.sleep(seconds: 1.9)
        let nower = getNow()
        XCTAssert(nower - now >= 2.0)
    }

    static var allTests : [(String, (PerfectThreadTests) -> () throws -> Void)] {
        return [
            ("testConcurrentQueue", testConcurrentQueue),
            ("testSerialQueue", testSerialQueue),
            ("testThreadSleep", testThreadSleep)            
        ]
    }
}
