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

    static var allTests = [
        ("testExample", testExampleWithCounter),
    ]
}
