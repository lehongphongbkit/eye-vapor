//
//  DayScore.swift
//  AdminPanel
//
//  Created by MBA0280F on 3/22/19.
//

import Vapor
import FluentProvider
import HTTP

final class DayScore: Model {
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let totalScore = "total_score"
        static let userID = "user_id"
    }
    
    let storage = Storage()
    var id: Identifier?
    var totalScore: Int = 0
    var userID: Identifier
    
    init(totalScore: Int, userID: Int) {
        self.totalScore = totalScore
        self.userID = Identifier(userID)
    }
    
    init(row: Row) throws {
        id = try row.get(Keys.id)
        totalScore = try row.get(Keys.totalScore)
        userID = try row.get(Keys.userID)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.id, id)
        try row.set(Keys.totalScore, totalScore)
        try row.set(Keys.userID, userID)
        return row
    }
    
    public static func makeJson(nodes: [Node]) throws -> [JSON] {
        var datas: [JSON] = []
        try nodes.forEach({ (node) in
            var data = JSON()
            try data.set(Keys.id, node.get(Keys.id) as Int)
            try data.set(Keys.totalScore, node.get(Keys.totalScore) as Int)
            try data.set("date", node.get("created_at") as String)
            datas.append(data)
        })
        return datas
    }
}

extension DayScore {
    var user: Parent<DayScore, User> {
        return parent(id: userID)
    }
}


// MARK: - JSONConvertible

extension DayScore: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(totalScore: try json.get(Keys.totalScore), userID: try json.get(Keys.userID))
    }
    
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.totalScore, totalScore)
        return json
    }
}

// MARK: - Preparation

extension DayScore: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.int(Keys.totalScore)
            builder.parent(User.self, optional: false)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Node
extension DayScore: NodeInitializable {
    convenience init(node: Node) throws {
        let id: Int = try node.get(Keys.id)
        self.init(totalScore: try node.get(Keys.totalScore), userID: try node.get(Keys.userID))
        self.id = Identifier(id)
    }
}

// MARK: - Updateable

extension DayScore: Updateable {
    public static var updateableKeys: [UpdateableKey<DayScore>] {
        return [
            UpdateableKey(Keys.totalScore, Int.self) { dayScore, totalScore in
                dayScore.totalScore = totalScore
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension DayScore: ResponseRepresentable { }

extension DayScore: Timestampable {}



