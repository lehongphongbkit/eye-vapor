//
//  Score.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

public let SCORE_OF_VOCAB: Int = 15
final class Score: Model {
    
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let score = "score"
        static let topicId = "topic_id"
        static let userId = "user_id"
    }
    
    // MARK: - Properties
    let storage = Storage()
    var id: Identifier?
    var score: Int = 0
    var topicId: Identifier
    var userId: Identifier
    // MARK: - Initializing
    
    init(score: Int, topicId: Int, userId: Int) {
        self.score = score;
        self.topicId = Identifier(topicId)
        self.userId = Identifier(userId)
    }
    
    init(row: Row) throws {
        id = try row.get(Keys.id)
        score = try row.get(Keys.score)
        userId = try row.get(Keys.userId)
        topicId = try row.get(Keys.topicId)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.id, id)
        try row.set(Keys.score, score)
        try row.set(Keys.userId, userId)
        try row.set(Keys.topicId, topicId)
        return row
    }
}

// MARK: - Relationships

extension Score {
    
    var user: Parent<Score, User> {
        return parent(id: userId)
    }
    
    var topic: Parent<Score, Topic> {
        return parent(id: topicId)
    }
}

// MARK: - JSONConvertible

extension Score: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(score: try json.get(Keys.score),
                  topicId: try json.get(Keys.topicId),
                  userId: try json.get(Keys.userId))
    }
    
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.score, score)
        return json
    }
}

// MARK: - Preparation

extension Score: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.int(Keys.score)
            builder.parent(User.self, optional: true)
            builder.parent(Topic.self, optional: true)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Node
extension Score: NodeInitializable {
    convenience init(node: Node) throws {
        let id: Int = try node.get(Keys.id)
        self.init(score: try node.get(Keys.score),
                  topicId: try node.get(Keys.topicId),
                  userId: try node.get(Keys.userId))
        self.id = Identifier(id)
    }
}

// MARK: - Updateable

extension Score: Updateable {
    public static var updateableKeys: [UpdateableKey<Score>] {
        return [
            UpdateableKey(Keys.score, Int.self) { score, num_score in
                score.score = num_score
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension Score: ResponseRepresentable { }

extension Score: Timestampable {}
