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
    private let wrapped: CurrentValueSubject<Output, Never>

    public func send(_ value: Output) {
        self.wrapped.send(value)
    }
    
    init(_ value: T) {
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

public enum RxStoreActions: RxStoreAction {
    case Empty
}

public protocol RxStoreState: Equatable, Codable {}

public protocol RxStoreEffects {
    typealias ActionObservable = AnyPublisher<RxStoreAction, Never>
    associatedtype Store
    typealias Effect = (Store, ActionObservable) -> ActionObservable
}

protocol RxStoreProtocol : AnyObject {
    typealias ActionSubject = PassthroughSubject<RxStoreAction, Never>
    var actions: PassthroughSubject<RxStoreAction, Never>{ get }
    var stream: AnyPublisher<RxStoreAction, Never> {get set}
    var _anyCancellable: AnyCancellable? {get set}
}


extension RxStoreProtocol {
    typealias Reducer<T> = (T, RxStoreAction) -> T
    func registerReducer<T>(for property: KeyPath<Self, RxStoreSubject<T>> , reducer: @escaping (T, RxStoreAction) -> T) -> Self {
        self.stream = stream.handleEvents(receiveOutput: { action in
            let state = reducer(self[keyPath: property].value, action)
            self[keyPath: property].send(state)
        })
        .eraseToAnyPublisher()
        return self
    }
    
    func dispatch(action: RxStoreAction) {
        actions.send(action)
    }
    
    func initialize() -> Self {
        self._anyCancellable = self.stream
            .sink(receiveValue: { _ in})
        return self
    }
    
}

extension RxStoreProtocol {
    typealias ActionObservable = AnyPublisher<RxStoreAction, Never>
    typealias Effect = (Self, ActionObservable) -> ActionObservable?

    func registerEffects(_ effects: [Effect] ) -> Self {
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
    
    func mergeStates<T: Publisher,K: Publisher>(statePath: KeyPath<Self,T>, statePath2: KeyPath<Self,K>) -> Publishers.CombineLatest<T,K> {
        let a = self[keyPath: statePath]
        let b = self[keyPath: statePath2]
        return Publishers.CombineLatest(a,b)
    }

}


public class RxStore: RxStoreProtocol {
    internal var stream: AnyPublisher<RxStoreAction, Never>
    internal var actions = PassthroughSubject<RxStoreAction, Never>()
    internal var _anyCancellable: AnyCancellable?
    
    init() {
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
