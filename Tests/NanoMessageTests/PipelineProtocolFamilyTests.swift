/*
    PipelineProtocolFamilyTests.swift

    Copyright (c) 2016 Stephen Whittle  All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom
    the Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
*/

import XCTest
import Foundation

@testable import NanoMessage

class PipelineProtocolFamilyTests: XCTestCase {
    private func testPipeline(connectAddress: String, bindAddress: String = "") {
        guard let connectURL = URL(string: connectAddress) else {
            XCTAssert(false, "connectURL is invalid")
            return
        }

        guard let bindURL = URL(string: (bindAddress.isEmpty) ? connectAddress : bindAddress) else {
            XCTAssert(false, "bindURL is invalid")
            return
        }

        var completed = false

        do {
            let node0 = try PushSocket()
            let node1 = try PullSocket()

            try node0.setSendTimeout(seconds: 1)
            try node1.setReceiveTimeout(seconds: 1)

            let node0EndPointId: Int = try node0.connectToURL(connectURL)
            XCTAssertGreaterThanOrEqual(node0EndPointId, 0, "node0.connectToURL('\(connectURL)') < 0")

            let node1EndPointId: Int = try node1.bindToURL(bindURL)
            XCTAssertGreaterThanOrEqual(node1EndPointId, 0, "node1.bindToURL('\(bindURL)') < 0")

            pauseForBind()

            let bytesSent = try node0.sendMessage(payload)
            XCTAssertEqual(bytesSent, payload.utf8.count, "bytesSent != payload.utf8.count")

            let node1Received: ReceiveString = try node1.receiveMessage()
            XCTAssertEqual(node1Received.bytes, node1Received.message.utf8.count, "bytes != message.utf8.count")
            XCTAssertEqual(node1Received.message, payload, "message != payload")

            completed = true
        } catch let error as NanoMessageError {
            XCTAssert(false, "\(error)")
        } catch {
            XCTAssert(false, "an unexpected error '\(error)' has occured in the library libNanoMessage.")
        }

        XCTAssert(completed, "test not completed")
    }

    func testTCPPipeline() {
        print("TCP tests...")
        testPipeline(connectAddress: "tcp://localhost:5555", bindAddress: "tcp://*:5555")
    }

    func testInProcessPipeline() {
        print("In-Process tests...")
        testPipeline(connectAddress: "inproc:///tmp/pipeline.inproc")
    }

    func testInterProcessPipeline() {
        print("Inter Process tests...")
        testPipeline(connectAddress: "ipc:///tmp/pipeline.ipc")
    }

    func testWebSocketPipeline() {
        print("Web Socket tests...")
        testPipeline(connectAddress: "ws://localhost:5555", bindAddress: "ws://*:5555")
    }

#if !os(OSX)
    static let allTests = [
        ("testTCPPipeline", testTCPPipeline),
        ("testInProcessPipeline", testInProcessPipeline),
        ("testInterProcessPipeline", testInterProcessPipeline),
        ("testWebSocketPipeline", testWebSocketPipeline)
    ]
#endif
}
