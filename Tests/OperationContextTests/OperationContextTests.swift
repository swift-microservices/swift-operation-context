// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import OperationContext
import Testing

@Suite("OperationContext Tests")
struct OperationContextTests {
    @Test("New contexts and the current default are empty")
    func emptyContext() {
        #expect(OperationContext()[FirstKey.self] == nil)
        #expect(OperationContext.current[FirstKey.self] == nil)
    }

    @Test("Subscript storage distinguishes key types and generic specializations")
    func typedKeys() {
        var context = OperationContext()
        context[FirstKey.self] = 1
        context[SecondKey.self] = 2
        context[GenericKey<Int>.self] = 3
        context[GenericKey<String>.self] = "value"

        #expect(context[FirstKey.self] == 1)
        #expect(context[SecondKey.self] == 2)
        #expect(context[GenericKey<Int>.self] == 3)
        #expect(context[GenericKey<String>.self] == "value")
    }

    @Test("Replacing and removing entries in a copy preserves the original")
    func valueSemantics() {
        var original = OperationContext()
        original[FirstKey.self] = 1
        original[SecondKey.self] = 2
        var copy = original
        copy[FirstKey.self] = 3
        copy[SecondKey.self] = nil

        #expect(original[FirstKey.self] == 1)
        #expect(original[SecondKey.self] == 2)
        #expect(copy[FirstKey.self] == 3)
        #expect(copy[SecondKey.self] == nil)
    }

    @Test("A stored optional nil is distinct from a missing entry")
    func optionalValues() throws {
        var context = OperationContext()
        context[GenericKey<String?>.self] = .some(nil)
        let value = try #require(context[GenericKey<String?>.self])
        #expect(value == nil)

        context[GenericKey<String?>.self] = nil
        #expect(context[GenericKey<String?>.self] == nil)
    }

    @Test("Synchronous scopes return results and restore bindings after a throw")
    func synchronousScopes() {
        var context = OperationContext.current
        context[FirstKey.self] = 42
        #expect(OperationContext.current[FirstKey.self] == nil)

        let result = OperationContext.withContext(context) {
            #expect(throws: Failure.expected) {
                try OperationContext.withContext(OperationContext()) {
                    #expect(OperationContext.current[FirstKey.self] == nil)
                    throw Failure.expected
                }
            }
            #expect(OperationContext.current[FirstKey.self] == 42)
            return OperationContext.current[FirstKey.self]
        }

        #expect(result == 42)
        #expect(OperationContext.current[FirstKey.self] == nil)
    }

    @Test("Async scopes survive suspension and restore bindings after a throw")
    func asynchronousScopes() async {
        var context = OperationContext()
        context[FirstKey.self] = 42

        let result = await OperationContext.withContext(context) {
            await Task.yield()
            #expect(OperationContext.current[FirstKey.self] == 42)
            await #expect(throws: Failure.expected) {
                try await OperationContext.withContext(OperationContext()) {
                    await Task.yield()
                    #expect(OperationContext.current[FirstKey.self] == nil)
                    throw Failure.expected
                }
            }
            #expect(OperationContext.current[FirstKey.self] == 42)
            return OperationContext.current[FirstKey.self]
        }

        #expect(result == 42)
        #expect(OperationContext.current[FirstKey.self] == nil)
    }

    @Test("Task-local binding propagates to child tasks with independent scopes")
    func taskPropagation() async {
        var context = OperationContext()
        context[FirstKey.self] = 42

        await OperationContext.$current.withValue(context) {
            await withTaskGroup(of: Void.self) { group in
                for value in 1...2 {
                    group.addTask {
                        #expect(OperationContext.current[FirstKey.self] == 42)
                        #expect(OperationContext.current[SecondKey.self] == nil)
                        var child = OperationContext.current
                        child[SecondKey.self] = value
                        await OperationContext.withContext(child) {
                            await Task.yield()
                            #expect(OperationContext.current[FirstKey.self] == 42)
                            #expect(OperationContext.current[SecondKey.self] == value)
                        }
                        #expect(OperationContext.current[SecondKey.self] == nil)
                    }
                }
            }
            #expect(OperationContext.current[SecondKey.self] == nil)
        }
        #expect(OperationContext.current[FirstKey.self] == nil)
    }

    @Test("Scoped operations preserve caller isolation and non-Sendable results")
    func actorIsolation() async {
        await Caller().checkIsolation()
    }
}

private enum FirstKey: OperationContextKey { typealias Value = Int }
private enum SecondKey: OperationContextKey { typealias Value = Int }
private enum GenericKey<Value: Sendable>: OperationContextKey {}
private enum Failure: Error { case expected }

private final class LocalState {
    var calls = 0
}

private actor Caller {
    private let state = LocalState()

    func checkIsolation() async {
        let synchronousResult = OperationContext.withContext(OperationContext()) {
            self.preconditionIsolated()
            state.calls += 1
            return state
        }
        #expect(synchronousResult === state)

        let asynchronousResult = await OperationContext.withContext(OperationContext()) {
            self.preconditionIsolated()
            state.calls += 1
            await Task.yield()
            self.preconditionIsolated()
            state.calls += 1
            return state
        }
        #expect(asynchronousResult === state)
        #expect(state.calls == 3)
    }
}
