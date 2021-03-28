import XCTest
import Combine

import RxStore

enum CounterAction: RxStore.Action {
    case Increment
    case Decrement
    case Dummy
}

final class RxStoreTests: XCTestCase {
    func testExampleWithCounter() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        
        class AppStore: RxStore {
            var counterState = RxStore.State(0)
        }
        
        
        let reducer : AppStore.Reducer<Int> = {state, action in
            switch action {
            case CounterAction.Increment:
                return state + 1
            case CounterAction.Decrement:
                return state - 1
            default:
                return state
            }
        }
        
        let store = AppStore().registerReducer(for: \.counterState, reducer)
        .initialize()
        
        store.dispatch(action: CounterAction.Increment)
        let _ = store.counterState.sink(receiveValue: { value in
            XCTAssertEqual(value, 1)
        })
        
        
    }
    
    func testEmptyActionsIgnored() {
        class TestStore: RxStore {
            let emptyState = RxStore.State(false)
        }
        
        let store = TestStore().registerReducer(for: \.emptyState, {state, action in
                if case RxStoreActions.Empty = action {
                    return true
                }
                return false
            }).initialize()
        
        enum Action: RxStore.Action {
            case first
        }
        let _ = store.emptyState.sink(receiveValue: {state in
            XCTAssertEqual(state, false)
        })
        store.dispatch(action: RxStoreActions.Empty)
        store.dispatch(action: Action.first)
    }
    
    func testEffects() {
        struct Todo: Codable, Equatable {
            let userId: Int
            let id: Int
            let title: String
            let completed: Bool
            internal init(userId: Int, id: Int, title: String, completed: Bool) {
                self.userId = userId
                self.id = id
                self.title = title
                self.completed = completed
            }
            
        }
        
        enum Action: RxStoreAction {
            case LoadTodos, LoadTodosSuccess([Todo]), LoadTodosFailure
        }
        
        typealias TodosState = Dictionary<Int, Todo>
        let mockTodo = Todo(userId: 1, id: 123, title: "Todo A", completed: false)
        func mockGetTodosFromServer() -> AnyPublisher<[Todo],Never> {
            return Just([mockTodo]).eraseToAnyPublisher()
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
        }
        
        let store = AppStore()
            .registerReducer(for: \.todosState, todoReducer)
            .registerEffects([loadTodos])
            .initialize()
        
        store.dispatch(action: Action.LoadTodos)
        let _ = store.todosState.sink(receiveValue: {state in
            XCTAssertEqual(state, [mockTodo.id: mockTodo])
        })
        
    }
    
    func testSelector() {
        class AppStore: RxStore {
            var todos = RxStore.State([mockTodo])
            var userTodoIds = RxStore.State<Dictionary<Int, [Int]>>([userId:[mockTodo.id], userId2: [mockTodo2.id]])
            var counter = RxStore.State(0)
        }
        enum Action: RxStore.Action {
            case AddTodo(Todo)
        }

        func counterReducer(_ state: Int, action: RxStore.Action) -> Int {
                switch action {
                    case CounterAction.Increment:
                        return state + 1
                    case CounterAction.Decrement:
                        return state - 1
                    default:
                        return state
                }
            }
        
        let store = AppStore()
            .registerReducer(for: \.todos, {state, action in
                if case Action.AddTodo(let todo) = action {
                    var newState = state
                    newState.append(todo)
                    return newState
                }
                return state
            })
            .registerReducer(for: \.counter, counterReducer)
            .initialize()
        
        func getTodosForSelectedUser(_ userId: Int) -> AppStore.Selector<[Todo]> {
            AppStore.createSelector(path: \.todos, path2: \.userTodoIds) { todos, userTodoIds -> [Todo] in
                let todoIds = userTodoIds[userId] ?? []
                let userTodos = todos.filter { todo in  todoIds.contains(todo.id) }
                return userTodos
            }
        }
        
        store.dispatch(action: Action.AddTodo(mockTodo2))
        let _ = store.select(getTodosForSelectedUser(userId2)).sink { userTodos in
            XCTAssertEqual(userTodos, [mockTodo2])
        }

    }

    static var allTests = [
        ("testExample", testExampleWithCounter),
    ]
}


