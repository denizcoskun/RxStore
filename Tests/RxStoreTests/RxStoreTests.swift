import XCTest
import Combine

@testable import RxStore

final class RxStoreTests: XCTestCase {
    func testExampleWithCounter() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        enum CounterAction: RxStoreAction {
            case Increment
            case Decrement
        }
        
        class TestStore: RxStore {
            var counterState = RxStoreSubject(0)
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
        
        let store = TestStore().registerReducer(for: \.counterState, reducer: reducer)
        .initialize()
        
        store.dispatch(action: CounterAction.Increment)
        let _ = store.counterState.sink(receiveValue: { value in
            XCTAssertEqual(value, 1)
        })
        
    }
    
    func testEmptyActionsIgnored() {
        class TestStore: RxStore {
            let emptyState = RxStoreSubject(false)
        }
        
        let store = TestStore().registerReducer(for: \.emptyState, reducer: {state, action in
                if case RxStoreActions.Empty = action {
                    return true
                }
                return false
            }).initialize()
        
        enum Action: RxStoreAction {
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
        
        enum Action: RxStoreAction, Equatable{
            case LoadTodos
            case LoadTodosSuccess([Todo])
            case LoadTodosFailure
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
            .registerReducer(for: \.todosState, reducer: todoReducer)
            .registerEffects([loadTodos])
            .initialize()
        
        store.dispatch(action: Action.LoadTodos)
        let _ = store.todosState.sink(receiveValue: {state in
            XCTAssertEqual(state, [mockTodo.id: mockTodo])
        })
        
    }

    static var allTests = [
        ("testExample", testExampleWithCounter),
    ]
}
