//
//  Level.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class Level: Model {
    
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let name = "name"
        static let completedTopic = "completed_topic"
        static let totalTopic = "total_topic"
        static let isLock = "isLock"
    }
    
    // MARK: - Properties
    let storage = Storage()
    var id: Identifier?
    var name: String = ""
    // MARK: - Initializing
    
    init(name: String) {
        self.name = name;
    }
    
    init(row: Row) throws {
        id = try row.get(Keys.id)
        name = try row.get(Keys.name)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.id, id)
        try row.set(Keys.name, name)
        return row
    }
}

// MARK: - Relationships

extension Level {
    
    var topics: Children<Level, Topic> {
        return children()
    }
}

// MARK: - JSONConvertible

extension Level: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(name: try json.get(Keys.name))
    }
    
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        return json
    }
    
    func makeFullJSON(user: User) throws -> JSON {
        var json = try makeJSON()
        var completedTopic = 0
        let topics = try self.topics.all()
        for topic in topics {
            if let score = try topic.scores.filter(Score.Keys.userId, .equals, user.id).first()?.score {
                let totalVocab = try topic.vocabularies.all().count
                if score >= totalVocab * SCORE_OF_VOCAB { completedTopic += 1 }
            }
        }
        try json.set(Keys.completedTopic, completedTopic)
        try json.set(Keys.totalTopic, topics.count)
        if let id = id?.int, let levelId = user.levelId.int, id > levelId {
            try json.set(Keys.isLock, true)
        } else {
            try json.set(Keys.isLock, false)
        }
        return json
    }
}

// MARK: - Preparation

extension Level: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Keys.name)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Node
extension Level: NodeInitializable {
    convenience init(node: Node) throws {
        let id: Int = try node.get(Keys.id)
        self.init(name: try node.get(Keys.name))
        self.id = Identifier(id)
    }
}

// MARK: - Updateable

extension Level: Updateable {
    public static var updateableKeys: [UpdateableKey<Level>] {
        return [
            UpdateableKey(Keys.name, String.self) { Level, name in
                Level.name = name
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension Level: ResponseRepresentable { }

extension Level: Timestampable {}
