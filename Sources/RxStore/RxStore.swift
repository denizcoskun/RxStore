//
//  Store.swift
//  Sortify
//
//  Created by Coskun Deniz on 11/02/2021.
//

import Foundation
import Combine



final public class RxStoreSubject<T: Equatable & Codable>: Subject {

    public typealias Output = T
    public typealias Failure = Never
    
    public var value: Output
    public let wrapped: CurrentValueSubject<Output, Never>

    public func send(_ value: Output) {
        self.wrapped.send(value)
    }
    
    public init(_ value: T) {
        self.value = value
        self.wrapped = .init(value)
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        wrapped.send(completion: completion)
    }
    
    public func send(subscription: Subscription) {
        self.wrapped.send(subscription: subscription)
    }
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        wrapped.removeDuplicates()
            .handleEvents(receiveOutput: { self.value = $0 })
            .subscribe(subscriber)
    }

}



public protocol RxStoreAction {}

public protocol RxStoreProtocol : AnyObject {
    typealias Action = RxStoreAction
    typealias Reducer<T> = (T, Action) -> T
    typealias State = Equatable & Codable
    typealias ActionSubject = PassthroughSubject<Action, Never>
    var actions: PassthroughSubject<Action, Never>{ get }
    var stream: AnyPublisher<Action, Never> {get set}
    var _anyCancellable: AnyCancellable? {get set}
}


public enum RxStoreActions: RxStoreAction {
    case Empty
}


extension RxStoreProtocol {
    public typealias ActionObservable = AnyPublisher<RxStoreAction, Never>
    public typealias Effect = (Self, ActionObservable) -> ActionObservable
}

extension RxStoreProtocol {

    public func registerReducer<T>(for property: KeyPath<Self, RxStoreSubject<T>> , _ reducer: @escaping (T, RxStoreAction) -> T) -> Self {
        self.stream = stream.handleEvents(receiveOutput: { action in
            let state = reducer(self[keyPath: property].value, action)
            self[keyPath: property].send(state)
        })
        .eraseToAnyPublisher()
        return self
    }
    
    public func dispatch(action: RxStoreAction) {
        actions.send(action)
    }
    
    public func initialize() -> Self {
        self._anyCancellable = self.stream
            .sink(receiveValue: { _ in})
        return self
    }
    
}

extension RxStoreProtocol {
    public func registerEffects(_ effects: [Effect] ) -> Self {
        self.stream = self.stream
                .flatMap({ action in
                    return effects.map({effect in
                        effect(self, Just(action).eraseToAnyPublisher())
                    }).compactMap({$0}).publisher.flatMap({result in result})
                    .map({
                        self.actions.send($0)
                        return RxStoreActions.Empty
                    })
                    .eraseToAnyPublisher()
                })
            .eraseToAnyPublisher()
        return self
    }
    
}

extension RxStoreProtocol {
    
    public func mergeStates<T: Publisher,K: Publisher>(statePath: KeyPath<Self,T>, statePath2: KeyPath<Self,K>) -> Publishers.CombineLatest<T,K> {
        let a = self[keyPath: statePath]
        let b = self[keyPath: statePath2]
        return Publishers.CombineLatest(a,b)
    }

}


extension RxStoreProtocol {

    public typealias Selector<A: State,B: State,C> = (KeyPath<Self,RxStoreSubject<A>>,KeyPath<Self,RxStoreSubject<B>>,  @escaping (A,B) -> C) -> (Self) -> AnyPublisher<C, Never>

    public static func createSelector<A,B,C>(path: KeyPath<Self,RxStoreSubject<A>>, path2: KeyPath<Self,RxStoreSubject<B>>, handler: @escaping (A,B) -> C) -> (Self) -> AnyPublisher<C, Never> {
        func result(store: Self) -> AnyPublisher<C, Never> {
            return store.mergeStates(statePath: path, statePath2: path2).map {state, state2 in
                handler(state, state2)
           }.eraseToAnyPublisher()
        }
        return result
    }

    public func select<R>(_ selector: @escaping (Self) -> R) -> R {
        return selector(self)
    }
}


open class RxStore: RxStoreProtocol {
    public var stream: AnyPublisher<RxStoreAction, Never>
    public var actions = PassthroughSubject<RxStoreAction, Never>()
    public var _anyCancellable: AnyCancellable?
    
    public init() {
        self.stream = actions
            .filter { action in
                if case RxStoreActions.Empty = action {
                    return false
                }
                return true
            }
            .eraseToAnyPublisher()
    }

}
