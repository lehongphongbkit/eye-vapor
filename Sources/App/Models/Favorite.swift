//
//  Favorite.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class Favorite: Model {
    let storage = Storage()
    
    var userId: Identifier
    var topicId: Identifier
    
    struct Keys {
        static let id = "id"
        static let userId = "user_id"
        static let topicId = "topic_id"
    }
    
    init(userId: Int, topicId: Int) {
        self.userId = Identifier(userId)
        self.topicId = Identifier(topicId)
    }
    
    init(row: Row) throws {
        userId = try row.get(Favorite.Keys.userId)
        topicId = try row.get(Favorite.Keys.topicId)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Favorite.Keys.topicId, topicId)
        try row.set(Favorite.Keys.userId, userId)
        return row
    }
}

// MARK: Fluent Preparation

extension Favorite: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.parent(User.self, optional: false)
            builder.parent(Topic.self, optional: false)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

extension Favorite {
    var user: Parent<Favorite, User> {
        return parent(id: userId)
    }
    
    var topic: Parent<Favorite, Topic> {
        return parent(id: topicId)
    }
}


extension Favorite: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(userId: try json.get(Keys.userId),
                  topicId: try json.get(Keys.topicId))
    }
    
    func makeJSON() throws -> JSON {
        let json = JSON()
        //TODO: - cho xong roi tinh tiep
        return json
    }
}

extension Favorite: ResponseRepresentable { }

extension Favorite: Timestampable { }
