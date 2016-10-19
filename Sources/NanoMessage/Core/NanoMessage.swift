/*
    NanoMessage.swift

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

import CNanoMessage

/// On publish/subscribe sockets the maximum size of a topic
public let maximumTopicLength = 128

/// The underlying nanomsg libraries ABI version.
public func getNanoMsgABIVersion() -> (current: Int, revision: Int, age: Int) {
    return (Int(NN_VERSION_CURRENT), Int(NN_VERSION_REVISION), Int(NN_VERSION_AGE))
}

/// NanoMessage library ABI version.
public func getABIVersion() -> (current: Int, revision: Int, age: Int) {
    return (current: 0, revision: 0, age: 6)
}

/// Notify all sockets about process termination.
public func terminate() {
    nn_term()
}

/// Get a nanomsg symbol.
///
/// - Parameters:
///   - index: The index of the nanomsg symbol we require.
///
/// - Returns: The nanomsg libraries symbol name and value as a tuple.
private func _getSymbol(_ index: CInt) -> (name: String, value: CInt)? {
    var value: CInt = 0

    if let symbolName = nn_symbol(index, &value) {
        return (String(cString: symbolName), value)
    }

    return nil
}

private var _nanomsgSymbol = Dictionary<String, CInt>()
/// A dictionary of nanomsg symbol names and values.
public var nanomsgSymbol: Dictionary<String, CInt> {
    if (_nanomsgSymbol.isEmpty) {
        var index: CInt = 0

        while (true) {
            if let symbol: (name: String, value: CInt) = _getSymbol(index) {
                _nanomsgSymbol[symbol.name] = symbol.value
            } else {
                break     // no more symbols
            }

            index += 1
        }
    }

    return _nanomsgSymbol
}

private var _symbolProperty = Set<SymbolProperty>()
/// A set of nanomsg symbol properties.
public var symbolProperty: Set<SymbolProperty> {
    if (_symbolProperty.isEmpty) {
        var buffer = nn_symbol_properties()
        let bufferLength = CInt(MemoryLayout<nn_symbol_properties>.size)
        var index: CInt = 0

        while (true) {
            let returnCode = nn_symbol_info(index, &buffer, bufferLength)

            if (returnCode == 0) {    // no more symbol properties
                break
            }

            _symbolProperty.insert(SymbolProperty(value: buffer.value, name: String(cString: buffer.name), namespace: buffer.ns, type: buffer.type, unit: buffer.unit))

            index += 1
        }
    }

    return _symbolProperty
}

private var _nanomsgError = Dictionary<Int, String>()
/// A dictionary of Posix nanomsg error codes and strings.
public var nanomsgError: Dictionary<Int, String> {
    if (_nanomsgError.isEmpty) {
        for symbol in symbolProperty {
            if (symbol.namespace == NN_NS_ERROR) {              // we have a symbol property of the error namespace
                _nanomsgError[Int(symbol.value)] = symbol.name
            }
        }
    }

    return _nanomsgError
}
