# RxStore

RxStore is a fully reactive state management tool built on top of Apple's [Combine](https://developer.apple.com/documentation/combine) framework. 
It is a naive implementation of [Redux](https://redux.js.org/) inspired by [@ngrx/store](https://ngrx.io/guide/store).

## Demo App
[Spotify-Playlist-Sorter](https://github.com/denizcoskun/Spotify-Playlist-Sorter)

## Basic Usage


```swift

// Define your app store, it can have multiple sub states
class AppStore: RxStore {
    var counterState = RxStore.State(0)
}

// Define actions
enum CounterAction {
    struct Increment: RxStore.Action {}
    struct Decrement: RxStore.Action {}
}

// Create a reducer
let reducer : RxStore.Reducer<Int> = {state, action in
    switch action {
    case _ as CounterAction.Increment:
        return state + 1
    case _ as CounterAction.Decrement:
        return state - 1
    default:
        return state
    }
}

// Register the reducer and initialize the app store

let appStore = AppStore()
    .registerReducer(for: \.counterState, reducer)
    .initialize()

// You are ready to go

let cancellable = appStore
    .counterState
    .sink(receiveValue: {print($0)}) // 0, 1

appStore.dispatch(action: CounterAction.Increment)

```


## App store with multiple states


```swift

// Define your app store, it can have multiple sub states
class AppStore: RxStore {
    var counterState = RxStore.State(0)
    var loadingState = RxStore.State(false)
}

// Define actions
enum CounterAction {
    struct Increment: RxStoreAction {}
    struct Decrement: RxStoreAction {}
}

enum LoadingAction {
    struct Loading: RxStoreAction {}
    struct Loaded: RxStoreAction {}
}


// Reducer for counter state
let counterReducer : RxStore.Reducer<Int> = {state, action in
    switch action {
    case _ as CounterAction.Increment:
        return state + 1
    case _ as CounterAction.Decrement:
        return state - 1
    default:
        return state
    }
}

// Reducer for loading state
let loadingReducer: RxStore.Reducer<Bool> = {state, action in
    switch action {
    case _ as LoadingAction.Loading:
        return true
    case _ as LoadingAction.Loaded:
        return false
    default:
        return state
    }
}

// Register the reducer and initialize the app store

let appStore = AppStore()
    .registerReducer(for: \.counterState, counterReducer)
    .registerReducer(for: \.loadingState, loadingReducer)
    .initialize()

// You are ready to go

let cancellable = appStore
    .counterState
    .sink(receiveValue: {print($0)}) // 0, 1

let cancellable2 = appStore
    .loadingState
    .sink(receiveValue: {print($0)}) // false, true

appStore.dispatch(action: CounterAction.Increment())
appStore.dispatch(action: LoadingAction.Loaded())

```

## Usage with side effects


```swift

struct Todo {
 let id: Int
 let text: String
}

typealias TodosState = Dictionary<Int, Todo>

class AppStore: RxStore {
    var todosState = RxStore.State<TodosState>([:])
    var loadingState = RxStore.State(false)
}

enum Action:  {
    struct LoadTodos: RxStoreAction {}
    struct LoadTodosSuccess: RxStoreAction {
        let payload: [Todo]
    }
    struct LoadTodosFailure: RxStoreAction {
        let error: Error
    }
}

let todoReducer: RxStore.Reducer = {state, action -> TodosState in
    switch action {
    case let action as Action.LoadTodosSuccess:
        var newState = state
        action.payload.forEach {
            newState[$0.id] = $0
        }
        return newState
    default:
        return state
    }
}

let loadTodosEffect = AppStore.createEffect(Action.LoadTodos.self) { store, action in
    mockGetTodosFromServer()
        .map { Action.LoadTodosSuccess($0) }
        .catch {Just(Action.LoadTodosFailure(error: $0))}
        .eraseToAnyPublisher()
}



let store = AppStore()
    .registerReducer(for: \.todosState, reducer: todoReducer)
    .registerReducer(for: \.loadingState, reducer: loadingReducer)
    .registerEffects([loadTodosEffect])
    .initialize()

let cancellable = store.todosState.sink(receiveValue: {state in
            print(state) // [], ["mock-todo-id": MockTodo]
})

store.dispatch(Action.LoadTodos) // This will fetch the todos from the server 

```


## Selectors

Selectors allow you to combine sub states and convert them into expected result.

Below is an example of how a selector can be used:

```swift
let todoList = [mockTodo, mockTodo2]
let userTodoIds: Dictionary<Int, [Int]> = [userId:[mockTodo.id], userId2: [mockTodo2.id]]

class AppStore: RxStore {
    var todos = RxStore.State(todoList)
    var userTodos = RxStore.State(userTodoIds)
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
