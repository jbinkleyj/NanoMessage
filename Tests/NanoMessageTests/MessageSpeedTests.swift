/*
    MessageSpeedTests.swift

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
import Mutex

import NanoMessage

class MessageSpeedTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    var asyncSendMutex: Mutex = try! Mutex()
    var asyncMessagesSent: UInt64 = 0
    var asyncBytesSent: UInt64 = 0
    var asyncReceiveMutex: Mutex = try! Mutex()
    var asyncMessagesReceived: UInt64 = 0
    var asyncBytesReceived: UInt64 = 0

    enum ReceiveType {
        case Serial
        case Asynchronously
    }

    func testMessageSpeed(receiveType: ReceiveType, connectAddress: String, bindAddress: String = "") {
        guard let connectURL = URL(string: connectAddress) else {
            XCTAssert(false, "connectURL is invalid")
            return
        }

        guard let bindURL = URL(string: (bindAddress.isEmpty) ? connectAddress : bindAddress) else {
            XCTAssert(false, "bindURL is invalid")
            return
        }

        var completed = false

        asyncMessagesSent = 0
        asyncBytesSent = 0
        asyncMessagesReceived = 0
        asyncBytesReceived = 0

        do {
            let node0 = try PushSocket()
            let node1 = try PullSocket()

            let timeout = TimeInterval(seconds: 1)

            try node0.setSendTimeout(seconds: timeout)
            try node1.setReceiveTimeout(seconds: timeout)

            let node0EndPoint: EndPoint = try node0.createEndPoint(url: connectURL, type: .Connect)
            let node1EndPoint: EndPoint = try node1.createEndPoint(url: bindURL, type: .Bind)

            pauseForBind()

            let messageSize = 128
            let messagePayload = Message(value: Array<Byte>(repeating: 0xff, count: messageSize))

            if (receiveType == .Asynchronously) {
                print("started send/recv: \(Date().timeIntervalSinceReferenceDate)")
            }

            for _ in 1 ... 100_000 {
                switch receiveType {
                    case .Serial:
                        let _ = try node0.sendMessage(messagePayload)
                        let _ = try node1.receiveMessage()
                    case .Asynchronously:
                        node0.sendMessage(messagePayload) { sent in
                            wrapper(do: {
                                        try self.asyncSendMutex.lock {
                                            self.asyncMessagesSent += 1
                                            self.asyncBytesSent += UInt64(sent.bytes)
                                        }
                                    },
                                    catch: { failure in
                                        nanoMessageErrorLogger(failure)
                                    })
                        }
                        node1.receiveMessage { received in
                            wrapper(do: {
                                        try self.asyncReceiveMutex.lock {
                                            self.asyncMessagesReceived += 1
                                            self.asyncBytesReceived += UInt64(received.bytes)
                                        }
                                    },
                                    catch: { failure in
                                        nanoMessageErrorLogger(failure)
                                    })
                        }
                }
            }

            if (receiveType == .Asynchronously) {
                print("before node0.wait: \(Date().timeIntervalSinceReferenceDate)")
                node0.aioGroup.wait()
                print("before node1.wait: \(Date().timeIntervalSinceReferenceDate)")
                node1.aioGroup.wait()
                print("after wait's     : \(Date().timeIntervalSinceReferenceDate)")
            }

            XCTAssertEqual(node0.messagesSent!, node1.messagesReceived!, "node0.messagesSent != node1.messagesReceived")
            XCTAssertEqual(node0.bytesSent!, node1.bytesReceived!, "node0.bytesSent != node1.bytesReceived")

            if (receiveType == .Asynchronously) {
                XCTAssertEqual(node0.messagesSent!, asyncMessagesSent, "node0.messagesSent != asyncMessagesSent")
                XCTAssertEqual(node0.bytesSent!, asyncBytesSent, "node0.bytesSent != asyncBytesSent")
                XCTAssertEqual(node1.messagesReceived!, asyncMessagesReceived, "node1.messagesReceived != asyncMessagesReceived")
                XCTAssertEqual(node1.bytesReceived!, asyncBytesReceived, "node1.bytesReceived != asyncBytesReceived")
            }

            print("Message Size: \(messageSize) Bytes, Total Messages (Sent/Received): (\(node0.messagesSent!),\(node1.messagesReceived!)), Total Bytes (Sent/Received): (\(node0.bytesSent!),\(node1.bytesReceived!))")

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

    func testTCPMessageSpeedSerial() {
        testMessageSpeed(receiveType: .Serial, connectAddress: "tcp://localhost:5900", bindAddress: "tcp://*:5900")
    }

    func testTCPMessageSpeedAsynchronously() {
        testMessageSpeed(receiveType: .Asynchronously, connectAddress: "tcp://localhost:5905", bindAddress: "tcp://*:5905")
    }

    func testInProcessMessageSpeedSerial() {
        testMessageSpeed(receiveType: .Serial, connectAddress: "inproc:///tmp/msgspeedsync.inproc")
    }

    func testInProcessMessageSpeedAsynchronously() {
        testMessageSpeed(receiveType: .Asynchronously, connectAddress: "inproc:///tmp/msgspeedasync.inproc")
    }

    func testInterProcessMessageSpeedSerial() {
        testMessageSpeed(receiveType: .Serial, connectAddress: "ipc:///tmp/msgspeedsync.ipc")
    }

    func testInterProcessMessageSpeedAsynchronously() {
        testMessageSpeed(receiveType: .Asynchronously, connectAddress: "ipc:///tmp/msgspeedasync.ipc")
    }

    func testWebSocketMessageSpeedSerial() {
        testMessageSpeed(receiveType: .Serial, connectAddress: "ws://localhost:5910", bindAddress: "ws://*:5910")
    }

    func testWebSocketMessageSpeedAsynchronously() {
        testMessageSpeed(receiveType: .Asynchronously, connectAddress: "ws://localhost:5915", bindAddress: "ws://*:5915")
    }

#if os(Linux)
    static let allTests = [
        ("testTCPMessageSpeedSerial", testTCPMessageSpeedSerial),
        ("testTCPMessageSpeedAsynchronously", testTCPMessageSpeedAsynchronously),
        ("testInProcessMessageSpeedSerial", testInProcessMessageSpeedSerial),
        ("testInProcessMessageSpeedAsynchronously", testInProcessMessageSpeedAsynchronously),
        ("testInterProcessMessageSpeedSerial", testInterProcessMessageSpeedSerial),
        ("testInterProcessMessageSpeedAsynchronously", testInterProcessMessageSpeedAsynchronously),
        ("testWebSocketMessageSpeedSerial", testWebSocketMessageSpeedSerial),
        ("testWebSocketMessageSpeedAsynchronously", testWebSocketMessageSpeedAsynchronously)
    ]
#endif
}
