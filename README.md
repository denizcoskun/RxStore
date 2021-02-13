# RxStore

RxStore is a fully reactive state management tool built on top of Combine. It is a naive implementation of Redux inspired by @ngrx/store.



## Basic Usage


```swift

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

let cancellable = appStore.counterState.sink(receiveValue: {print($0}) // 0, 1

appStore.dispatch(CounterState.Increment)

```

## Usage with side effects


```swift

typealias TodosState = Dictionary<Int, Todo>
enum Action: RxStoreAction {
    case LoadTodos, LoadTodosSuccess([Todo]), LoadTodosFailure
}

let todoReducer: RxStore.Reducer = {state, action -> TodosState in
    switch action {
    case Action.LoadTodosSuccess(let todos):
        var newState = state
        todos.forEach {
            newState[$0.id] = $0
        }
        return newState
    default:
        return state
    }
}
let loadTodos: RxStore.Effect = {state, action in
    action.flatMap {action -> RxStore.ActionObservable in
        if case Action.LoadTodos = action   {
            return mockGetTodosFromServer().map {
                Action.LoadTodosSuccess($0)
            }.eraseToAnyPublisher()
        }
        return Empty().eraseToAnyPublisher()
    }.eraseToAnyPublisher()
}

class AppStore: RxStore {
    var todosState = RxStoreSubject<TodosState>([:])
    var loadingState = RxStoreSubject(false)
}

let store = AppStore()
    .registerReducer(for: \.todosState, reducer: todoReducer)
    .registerReducer(for: \.loadingState, reducer: loadingReducer)
    .registerEffects([loadTodos])
    .initialize()

let cancellable = store.todosState.sink(receiveValue: {state in
            print(state) // [], ["mock-todo-id": MockTodo]
})

store.dispatch(Action.LoadTodos) // This will fetch the todos from the server 


```


