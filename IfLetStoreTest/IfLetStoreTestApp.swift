//
//  IfLetStoreTestApp.swift
//  IfLetStoreTest
//
//  Created by Olli Tapaninen on 22.7.2021.
//

import SwiftUI
import ComposableArchitecture

@main
struct IfLetStoreTestApp: App {
    var body: some Scene {
        WindowGroup {
            TestView()
        }
    }
}

enum TestAction {
    case close
    case increment

}
struct TestState: Equatable {
    var number: Int?
}

let reducer = Reducer { (state: inout TestState, action: TestAction, env: Void) -> Effect in

    switch action {
    case .close:
        state.number = nil
    case .increment:
        if state.number == nil {
            state.number = 1
        } else {
            state.number! += 1
        }
    }

    return .none
}

let store = Store(initialState: TestState(number: nil), reducer: reducer, environment: ())

struct TestView: View {

    var body: some View {
        VStack {
            HStack {
                WithViewStore(store) { viewStore in
                    Button(action: { viewStore.send(.close) }) {
                        Text("Set to nil")
                    }
                    Button(action: { viewStore.send(.increment) }) {
                        Text("Increment")
                    }
                }
            }

            Group {
                IfLetStore(store.scope(state: \.number)) { numberStore in
                    WithViewStore(numberStore) { numberViewStore in
                        Text("Number: \(numberViewStore.state)")
                    }
                } else: {
                    Text("No number")
                }

                IfLetStoreFixed(store.scope(state: \.number)) { numberStore in
                    WithViewStore(numberStore) { numberViewStore in
                        Text("Number: \(numberViewStore.state)")
                    }
                } else: {
                    Text("No number")
                }
            }
            .transition(.slide)
            .animation(.linear(duration: 2))
        }
    }
}

public struct IfLetStoreFixed<State, Action, Content>: View where Content: View {
    private let content: (ViewStore<State?, Action>) -> Content
    private let store: Store<State?, Action>


    public init<IfContent, ElseContent>(
        _ store: Store<State?, Action>,
        @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent
    ) where Content == _ConditionalContent<IfContent, ElseContent> {
        self.store = store
        self.content = { viewStore in
            if viewStore.state != nil {
                let unwrapper = Optional<State>.lastWrappedValue
                // Force unwrap is safe here because first value from scope is non-nil and scoped store
                // is dismanteled after last nil value.
                return ViewBuilder.buildEither(first: ifContent(store.scope(state: { unwrapper($0)! })))
            } else {
                return ViewBuilder.buildEither(second: elseContent())
            }
        }
    }

    public init<IfContent>(
        _ store: Store<State?, Action>,
        @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent
    ) where Content == IfContent? {
        self.store = store
        self.content = { viewStore in
            viewStore.state.map { _ in
                let unwrapper = Optional<State>.lastWrappedValue
                // Force unwrap is safe here because first value from scope is non-nil and scoped store
                // is dismanteled after last nil value.
                return ifContent(store.scope(state: { unwrapper($0)! }))
            }
        }
    }

    public var body: some View {
        WithViewStore(
            self.store,
            removeDuplicates: { ($0 != nil) == ($1 != nil) },
            content: self.content
        )
    }
}

extension Optional {
    static var lastWrappedValue: (Self) -> Self {
        var lastWrapped: Wrapped?
        return {
            lastWrapped = $0 ?? lastWrapped
            return lastWrapped
        }
    }
}
