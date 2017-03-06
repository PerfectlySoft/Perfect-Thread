//
//  Promise.swift
//  PerfectThread
//
//  Created by Kyle Jessup on 2017-03-06.
//	Copyright (C) 2017 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2017 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

/// A Promise is an object which is shared between one or more threads. 
/// The promise will execute the closure given to it when it is created on a new thread. When the
/// thread produces its return value a consumer thread will be able to obtain 
/// the value or handle the error if one occurred.
public class Promise<ReturnType> {
		
	private let event = Threading.Event()
	private var value: ReturnType?
	private var error: Error?
	
	/// Initialize a Promise with a closure. The closure is passed the promise object on which the
	/// return value or error can be later set.
	/// The closure will be executed on the default concurrent thread queue.
	public convenience init(_ closure: @escaping (Promise<ReturnType>) -> ()) {
		self.init(queue: Threading.getQueue(), closure: closure)
	}
	
	/// Initialize a Promise with a closure. The closure is passed the promise object on which the
	/// return value or error can be later set.
	/// The closure will be executed on the indicated thread queue.
	public init(queue: ThreadQueue, closure: @escaping (Promise<ReturnType>) -> ()) {
		queue.dispatch {
			closure(self)
		}
	}
	
	/// Get the return value if it is available.
	/// Returns nil if the return value is not available.
	/// If a failure has occurred then the Error will be thrown.
	/// This is called by the consumer thread.
	public func get() throws -> ReturnType? {
		event.lock()
		defer {
			event.unlock()
		}
		if let error = error {
			throw error
		}
		return value
	}
	
	/// Get the return value if it is available.
	/// Returns nil if the return value is not available.
	/// If a failure has occurred then the Error will be thrown.
	/// Will block and wait up to the indicated number of seconds for the return value to be produced.
	/// This is called by the consumer thread.
	public func wait(seconds: Double = Threading.noTimeout) throws -> ReturnType? {
		event.lock()
		defer {
			event.unlock()
		}
		if let error = error {
			throw error
		}
		if let value = value {
			return value
		}
		_ = event.wait(seconds: seconds)
		if let error = error {
			throw error
		}
		return value
	}
	
	/// Set the Promise's return value, enabling the consumer to retrieve it.
	/// This is called by the producer thread.
	public func set(_ value: ReturnType) {
		event.lock()
		defer {
			event.unlock()
		}
		self.value = value
		event.broadcast()
	}
	
	/// Fail the Promise and set its error value.
	/// This is called by the producer thread.
	public func fail(_ error: Error) {
		event.lock()
		defer {
			event.unlock()
		}
		self.error = error
		event.broadcast()
	}
}
