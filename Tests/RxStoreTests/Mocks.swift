//
//  File.swift
//  
//
//  Created by Coskun Deniz on 14/02/2021.
//

import Foundation
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



typealias TodosState = Dictionary<Int, Todo>
let userId = 1
let userId2 = 2
let mockTodo = Todo(userId: userId, id: 123, title: "Todo A", completed: false)
let mockTodo2 = Todo(userId: userId2, id: 444, title: "Todo B", completed: false)
