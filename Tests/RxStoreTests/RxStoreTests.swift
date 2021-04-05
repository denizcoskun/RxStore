import XCTest
import Combine

import RxStore

enum CounterAction {
    struct Increment: RxStoreAction {}
    struct Decrement: RxStoreAction {}

}

final class RxStoreTests: XCTestCase {
    var subscriptions = Set<AnyCancellable>()
    
    override func tearDown() {
      subscriptions = []
    }
    func testExampleWithCounter() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        
        class AppStore: RxStore {
            var counterState = RxStore.State(0)
        }
        
        
        let reducer : AppStore.Reducer<Int> = {state, action in
            switch action {
            case _ as CounterAction.Increment:
                return state + 1
            case _ as CounterAction.Decrement:
                return state - 1
            default:
                return state
            }
        }
        
        let store = AppStore().registerReducer(for: \.counterState, reducer)
        .initialize()
        
        store.dispatch(action: CounterAction.Increment())
        let _ = store.counterState.sink(receiveValue: { value in
            XCTAssertEqual(value, 1)
        })
        
        
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
        
        enum Action {
            struct LoadTodos: RxStoreAction {}
            struct LoadTodosSuccess: RxStoreAction {
                let todos: [Todo]
                init(_ todos: [Todo]) {
                    self.todos = todos;
                }
            }
            struct LoadTodosFailure: RxStoreAction {}
        }
        
        typealias TodosState = Dictionary<Int, Todo>
        let mockTodo = Todo(userId: 1, id: 123, title: "Todo A", completed: false)
        func mockGetTodosFromServer() -> AnyPublisher<[Todo],Never> {
            return Just([mockTodo]).eraseToAnyPublisher()
        }
        let todoReducer: RxStore.Reducer = {state, action -> TodosState in
            switch action {
            case let action as Action.LoadTodosSuccess:
                var newState = state
                action.todos.forEach {
                    newState[$0.id] = $0
                }
                return newState
            default:
                return state
            }
        }

        
        class AppStore: RxStore {
            var todosState = State<TodosState>([:])
        }
        
        
        let loadTodosEffect = AppStore.createEffect(Action.LoadTodos.self) { store, action in
            mockGetTodosFromServer()
                .map { Action.LoadTodosSuccess($0) }
                .replaceError(with: Action.LoadTodosFailure())
                .eraseToAnyPublisher()
        }
        
        let store = AppStore()
            .registerReducer(for: \.todosState, todoReducer)
            .registerEffects([loadTodosEffect])
            .initialize()
        var actions: [RxStoreAction] = []
        store.stream.prefix(2).sink(receiveCompletion: {_ in
            XCTAssertTrue(actions[0] is Action.LoadTodos)
            XCTAssertTrue(actions[1] is Action.LoadTodosSuccess)
        }, receiveValue: {action in
            actions.append(action)
        }).store(in: &subscriptions)
        
        store.dispatch(action: Action.LoadTodos())

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
        enum Action {
            struct AddTodo: RxStoreAction {
                let todo: Todo
            }
        }

        func counterReducer(_ state: Int, action: RxStore.Action) -> Int {
                switch action {
                    case _ as CounterAction.Increment:
                        return state + 1
                    case _ as CounterAction.Decrement:
                        return state - 1
                    default:
                        return state
                }
            }
        
        let store = AppStore()
            .registerReducer(for: \.todos, {state, action in
                if let action = action as? Action.AddTodo {
                    var newState = state
                    newState.append(action.todo)
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

        let _ = store.select(getTodosForSelectedUser(userId2)).prefix(2).collect()
            .sink {todos in
                XCTAssert(todos == [[], [mockTodo2]] as [[Todo]], "failed")
            }.store(in: &subscriptions)
        
        store.dispatch(action: Action.AddTodo(todo: mockTodo2))
    }

    static var allTests = [
        ("testExample", testExampleWithCounter),
    ]
}


