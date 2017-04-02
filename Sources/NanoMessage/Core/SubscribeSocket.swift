/*
    SubscribeSocket.swift

    Copyright (c) 2017 Stephen Whittle  All rights reserved.

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

protocol SubscribeSocket: ReceiverSocket {
    var receivedTopics: Dictionary<Topic, UInt64> { get } // implement private set
    var removeTopicFromMessage: Bool { get set }
    var ignoreTopicSeperator: Bool { get }                // implement private set
    var subscribedTopics: Set<Topic> { get }              // implement private set
    var subscribedToAllTopics: Bool { get }               // implement private set

    func isTopicSubscribed(_ topic: Topic) -> Bool
    func flipIgnoreTopicSeperator() throws -> Bool
    func subscribeTo(topic: Topic) throws -> Bool
    func unsubscribeFrom(topic: Topic) throws -> Bool
    func subscribeToAllTopics() throws -> Bool
    func unsubscribeFromAllTopics() throws
}
