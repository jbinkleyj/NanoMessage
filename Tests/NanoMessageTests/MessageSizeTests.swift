/*
    MessageSizeTests.swift

    Copyright (c) 2016, 2017 Stephen Whittle  All rights reserved.

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
import ISFLibrary

import NanoMessage

class MessageSizeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testMessageSize(connectAddress: String, bindAddress: String = "") {
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

            let timeout = TimeInterval(seconds: 1)

            try node0.setSendTimeout(seconds: timeout)
            try node1.setReceiveTimeout(seconds: timeout)

            let node0EndPoint: EndPoint = try node0.createEndPoint(url: connectURL, type: .Connect)
            let node1EndPoint: EndPoint = try node1.createEndPoint(url: bindURL, type: .Bind)

            pauseForBind()

            var messageSize = 1
            let maximumMessageSize = try node1.getMaximumMessageSize()

            while (messageSize <= maximumMessageSize) {
                let messagePayload = Message(value: Array<Byte>(repeating: 0xff, count: messageSize))

                let _ = try node0.sendMessage(messagePayload)
                let _ = try node1.receiveMessage()

                messageSize *= 2
            }

            XCTAssertEqual(node0.messagesSent!, node1.messagesReceived!, "node0.messagesSent != node1.messagesReceived")
            XCTAssertEqual(node0.bytesSent!, node1.bytesReceived!, "node0.bytesSent != node1.bytesReceived")

            print("Total Messages (Sent/Received): (\(node0.messagesSent!),\(node1.messagesReceived!)), Total Bytes (Sent/Received): (\(node0.bytesSent!),\(node1.bytesReceived!))")

            let node0Removed = try node0.removeEndPoint(node0EndPoint)
            XCTAssertTrue(node0Removed, "node0.removeEndPoint(\(node0EndPoint))")
            let node1Removed = try node1.removeEndPoint(node1EndPoint)
            XCTAssertTrue(node1Removed, "node1.removeEndPoint(\(node1EndPoint))")

            completed = true
        } catch let error as NanoMessageError {
            XCTAssert(false, "\(error)")
        } catch {
            XCTAssert(false, "an unexpected error '\(error)' has occured in the library libNanoMessage.")
        }

        XCTAssert(completed, "test not completed")
    }

    func testTCPMessageSize() {
        testMessageSize(connectAddress: "tcp://localhost:5800", bindAddress: "tcp://*:5800")
    }

    func testInProcessMessageSize() {
        testMessageSize(connectAddress: "inproc:///tmp/msgsize.inproc")
    }

    func testInterProcessMessageSize() {
        testMessageSize(connectAddress: "ipc:///tmp/msgsize.ipc")
    }

    func testWebSocketMessageSize() {
        testMessageSize(connectAddress: "ws://localhost:5805", bindAddress: "ws://*:5805")
    }

#if os(Linux)
    static let allTests = [
        ("testTCPMessageSize", testTCPMessageSize),
        ("testInProcessMessageSize", testInProcessMessageSize),
        ("testInterProcessMessageSize", testInterProcessMessageSize),
        ("testWebSocketMessageSize", testWebSocketMessageSize)
    ]
#endif
}
