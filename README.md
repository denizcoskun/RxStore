# RxStore

RxStore is a fully reactive state management tool built on top of Combine. It is a naive implementation of Redux inspired by @ngrx/store.



## Basic Usage


```

class AppStore: RxStore {
    var counterState = RxStoreSubject(0)
}

let counterReducer: RxStore.Reducer<Int> = {state, action in
    switch action {
        case CounterAction.Increment:
            return state + 1
        case CounterAction.Decrement:
            return state - 1
        default:
            return state
    }
}

let appStore = AppStore().registerReducer(for: \.counterState, counterReducer).initialize()

appStore.counterState.sink(receiveValue: {print($0}) // 0, 1

appStore.dispatch(CounterState.Increment)

```

## Foundation

More docs to be added...



