// swift-tools-version:4.0
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

import PackageDescription

#if os(Linux)
let package = Package(
	name: "PerfectThread",
	products: [
		.library(
			name: "PerfectThread",
			targets: ["PerfectThread"]),
		],
	dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-LinuxBridge.git", from: "3.0.0")
	],
	targets: [
		.target(
			name: "PerfectThread",
			dependencies: ["LinuxBridge"]),
		.testTarget(
			name: "PerfectThreadTests",
			dependencies: ["PerfectThread"]),
		]
)
#else
let package = Package(
	name: "PerfectThread",
	products: [
		.library(
			name: "PerfectThread",
			targets: ["PerfectThread"]),
		],
	dependencies: [
	],
	targets: [
		.target(
			name: "PerfectThread",
			dependencies: []),
		.testTarget(
			name: "PerfectThreadTests",
			dependencies: ["PerfectThread"]),
		]
)
#endif











//#if os(Linux)
//let package = Package(
//    name: "PerfectThread",
//    targets: [],
//    dependencies: [
//        .Package(url: "https://github.com/PerfectlySoft/Perfect-LinuxBridge.git", majorVersion: 3)
//    ],
//    exclude: []
//)
//#else
//let package = Package(
//    name: "PerfectThread",
//    targets: [],
//    dependencies: [
//
//    ],
//    exclude: []
//)
//#endif
