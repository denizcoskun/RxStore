# RxStore

RxStore is a fully reactive state management tool built on top of Combine. It is a naive implementation of Redux inspired by [@ngrx/store](https://ngrx.io/guide/store).

## Demo App
[Spotify-Playlist-Sorter](https://github.com/denizcoskun/Spotify-Playlist-Sorter)

## Basic Usage


```swift

class AppStore: RxStore {
    var counterState = RxStoreSubject(0)
}

enum CounterAction: RxStore.Action {
    case Increment
    case Decrement
}


let reducer : RxStore.Reducer<Int> = {state, action in
    switch action {
    case CounterAction.Increment:
        return state + 1
    case CounterAction.Decrement:
        return state - 1
    default:
        return state
    }
}

let appStore = AppStore()
    .registerReducer(for: \.counterState, reducer)
    .initialize()

let cancellable = appStore
    .counterState
    .sink(receiveValue: {print($0)}) // 0, 1

appStore.dispatch(action: Action.Increment)

```

## Usage with side effects


```swift

typealias TodosState = Dictionary<Int, Todo>
enum Action: RxStore.Action {
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


## Selectors

Selectors allow you to work with combination of different states at the same time.

Below is an example of how a selector can be used:

```swift
let todoList = [mockTodo, mockTodo2]
let userTodoIds: Dictionary<Int, [Int]> = [userId:[mockTodo.id], userId2: [mockTodo2.id]]

class AppStore: RxStore {
    var todos = RxStoreSubject(todoList)
    var userTodos = RxStoreSubject(userTodoIds)
}

let store = AppStore().initialize()

func getTodosForSelectedUser(_ userId: Int) -> AppStore.Selector<[Todo]> {
    AppStore.createSelector(path: \.todos, path2: \.userTodoIds) { todos, userTodoIds -> [Todo] in
        let todoIds = userTodoIds[userId] ?? []
        let userTodos = todos.filter { todo in  todoIds.contains(todo.id) }
        return userTodos
    }
}

let _ = store.select(getTodosForSelectedUser(userId2)).sink { userTodos in
    print(userTodos) // [mockTodo2]
}

```
