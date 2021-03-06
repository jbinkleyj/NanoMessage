/*
    PublisherSocket.swift

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

import Foundation
import ISFLibrary

/// Publisher socket.
public final class PublisherSocket: NanoSocket, ProtocolSocket, PublishSubscribeSocket, PublishSocket {
    /// The seperator (as an ascii byte value) used between topic and message.
    public var topicSeperator: Byte = 127
    /// remember which topics we've sent and how many.
    public var topicCounts = true
    /// A Dictionary of the topics sent with a count of the times sent.
    public fileprivate(set) var sentTopics = Dictionary<Topic, UInt64>()
    /// When prepending the topic to the message do we ignore the topic seperator,
    /// if true then the Subscriber socket should do the same and have subscribed to topics of equal length.
    public var ignoreTopicSeperator = false

    public init(socketDomain: SocketDomain = .StandardSocket) throws {
        try super.init(socketDomain: socketDomain, socketProtocol: .PublisherProtocol)
    }
}

extension PublisherSocket {
    /// Send a message.
    ///
    /// - Parameters:
    ///   - message:      The message to send.
    ///   - blockingMode: Specifies that the send should be performed in non-blocking mode.
    ///                   If the message cannot be sent straight away, the function will throw
    ///                   `NanoMessageError.MessageNotSent`
    ///
    /// - Throws:  `NanoMessageError.SocketIsADevice`
    ///            `NanoMessageError.NoEndPoint`
    ///            `NanoMessageError.SendMessage` there was a problem sending the message.
    ///            `NanoMessageError.NoTopic` if there was no topic defined to send.
    ///            `NanoMessageError.TopicLength` if the topic length too large.
    ///            `NanoMessageError.MessageNotSent` the send has beem performed in non-blocking mode and the message cannot be sent straight away.
    ///            `NanoMessageError.TimedOut` the send timedout.
    ///
    /// - Returns: The message payload sent.
    @discardableResult
    public func sendMessage(_ message:    Message,
                            blockingMode: BlockingMode = .Blocking) throws -> MessagePayload {
        var topic = Topic()

        let payload: () throws -> Data = {
            guard (message.topic != nil) else {
                throw NanoMessageError.NoTopic
            }

            topic = message.topic!

            if (self.ignoreTopicSeperator) {                  // check if we are ignoring the topic seperator.
                return topic.data + message.data
            }

            return topic.data + [self.topicSeperator] + message.data
        }

        let sent = try sendToSocket(self, payload(), blockingMode)

        if (topicCounts) {                                    // remember which topics we've sent and how many.
            if var topicCount = sentTopics[topic] {
                topicCount += 1
                sentTopics[topic] = topicCount
            } else {
                sentTopics[topic] = 1
            }
        }

        return MessagePayload(bytes:     sent.bytes,
                              topic:     topic,
                              message:   Message(value: message.data),
                              direction: .Sent,
                              timestamp: sent.timestamp)
    }
}

extension PublisherSocket {
    /// reset the topic counts.
    public func resetTopicCounts() {
        sentTopics = Dictionary<Topic, UInt64>()
    }
}
