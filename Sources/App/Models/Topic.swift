//
//  Topic.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class Topic: Model {
    
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let name = "name"
        static let levelId = "level_id"
        static let userId = "user_id"
        static let status = "status"
        static let isSystem = "is_system"
        static let totalLike = "total_like"
        static let totalComment = "total_comment"
        static let isLike = "is_like"
        static let totalVocab = "total_vocab"
        static let achievedScore = "achieved_score"
        static let totalScore = "total_score"
    }
    
    // MARK: - Properties
    let storage = Storage()
    var id: Identifier?
    var name: String = ""
    var status: String = ""
    var levelId: Identifier
    var userId: Identifier
    var isSystem: Bool = false
    var totalLike: Identifier = 0
    var totalComment: Identifier = 0
    // MARK: - Initializing
    
    init(name: String, status: String, levelId: Int, userId: Int, totalLike: Int, totalComment: Int) {
        self.name = name;
        self.status = status;
        self.levelId = Identifier(levelId)
        self.userId = Identifier(userId)
        self.totalLike = Identifier(totalLike)
        self.totalComment = Identifier(totalComment)
    }
    
    init(row: Row) throws {
        id = try row.get(Keys.id)
        name = try row.get(Keys.name)
        status = try row.get(Keys.status)
        userId = try row.get(Keys.userId)
        levelId = try row.get(Keys.levelId)
        isSystem = try row.get(Keys.isSystem)
        totalLike = try row.get(Keys.totalLike)
        totalComment = try row.get(Keys.totalComment)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.id, id)
        try row.set(Keys.name, name)
        try row.set(Keys.status, status)
        try row.set(Keys.userId, userId)
        try row.set(Keys.levelId, levelId)
        try row.set(Keys.isSystem, isSystem)
        try row.set(Keys.totalLike, totalLike)
        try row.set(Keys.totalComment, totalComment)
        return row
    }
}

// MARK: - Relationships

extension Topic {
    
    var user: Parent<Topic, User> {
        return parent(id: userId)
    }
    
    var level: Parent<Topic, Level> {
        return parent(id: levelId)
    }
    
    var comments: Children<Topic, XIIComment> {
        return children()
    }
    
    var favorites: Children<Topic, Favorite> {
        return children()
    }
    
    var vocabularies: Siblings<Topic, Vocabulary, Pivot<Topic, Vocabulary>> {
        return siblings()
    }
    
    var scores: Children<Topic, Score> {
        return children()
    }
}

// MARK: - JSONConvertible

extension Topic: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(name: try json.get(Keys.name),
                  status: try json.get(Keys.status),
                  levelId: try json.get(Keys.levelId),
                  userId: try json.get(Keys.userId),
                  totalLike: try json.get(Keys.totalLike),
                  totalComment: try json.get(Keys.totalComment))
    }
    
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        try json.set(Keys.status, status)
        return json
    }
    
    func makeFullJson() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        try json.set(Keys.totalLike, totalLike)
        try json.set(Keys.status, status)
        try json.set(Keys.totalComment, totalComment)
        try json.set(Keys.totalVocab, vocabularies.count())
        if let level: Level = try self.level.get() {
            try json.set("level_id", level.id)
            try json.set("level_name", level.name)
        }
        return json
    }
    
    func makeFullJson(userID: Identifier) throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        try json.set(Keys.totalLike, totalLike)
        try json.set(Keys.status, status)
        try json.set(Keys.totalComment, totalComment)
        try json.set(Keys.totalVocab, vocabularies.count())
        try json.set(Keys.totalScore, vocabularies.count() * SCORE_OF_VOCAB)
        if let score = try scores.filter(Keys.userId, .equals, userID).first()?.score {
            try json.set(Keys.achievedScore, score)
        } else {
            try json.set(Keys.achievedScore, 0)
        }
        let description = try vocabularies.all().reduce(into: "", { (result, vocab) in
            result += vocab.word + ", "
        })
        try json.set("description", description)
        if let level: Level = try self.level.get() {
            try json.set("level_id", level.id)
            try json.set("level_name", level.name)
        }
        return json
    }
    
    func makeTopJson() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        try json.set(Keys.totalLike, totalLike)
        try json.set(Keys.status, status)
        try json.set(Keys.totalComment, totalComment)
        if let level: Level = try self.level.get() {
            try json.set("level_id", level.id)
            try json.set("level_name", level.name)
        }
        if let user = try self.user.get() {
            if user.isAdmin {
                try json.set("from", "System")
            } else {
                try json.set("from", try user.makeJSON())
            }
        }
        return json
    }
    
    func makeDetailJson() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        try json.set(Keys.totalLike, totalLike)
        try json.set(Keys.status, status)
        if let level: Level = try self.level.get() {
            try json.set("level_id", level.id)
            try json.set("level_name", level.name)
        }
        try json.set(Keys.totalComment, totalComment)
        try json.set("total_like", totalLike)
        let vocabularies = try self.vocabularies.all()
        try json.set(Keys.totalVocab, vocabularies.count)
        try json.set("vocabularies", try vocabularies.makeJSON())
        return json
    }
}

// MARK: - Preparation

extension Topic: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Keys.name)
            builder.string(Keys.status)
            builder.bool(Keys.isSystem)
            builder.parent(User.self, optional: true)
            builder.parent(Level.self, optional: true)
            builder.int(Keys.totalLike)
            builder.int(Keys.totalComment)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Node
extension Topic: NodeInitializable {
    convenience init(node: Node) throws {
        let id: Int = try node.get(Keys.id)
        self.init(name: try node.get(Keys.name),
                  status: try node.get(Keys.status),
                  levelId: try node.get(Keys.levelId),
                  userId: try node.get(Keys.userId),
                  totalLike: try node.get(Keys.totalLike),
                  totalComment: try node.get(Keys.totalComment))
        self.id = Identifier(id)
    }
}

// MARK: - Updateable

extension Topic: Updateable {
    public static var updateableKeys: [UpdateableKey<Topic>] {
        return [
            UpdateableKey(Keys.name, String.self) { topic, name in
                topic.name = name
            }, UpdateableKey(Keys.status, String.self) { topic, status in
                topic.status = status
            }, UpdateableKey(Keys.isSystem, Bool.self) { topic, isSystem in
                topic.isSystem = isSystem
            }, UpdateableKey(Keys.totalLike, Int.self) { topic, totalLike in
                topic.totalLike = Identifier(totalLike)
            }, UpdateableKey(Keys.totalComment, Int.self) { topic, totalComment in
                topic.totalComment = Identifier(totalComment)
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension Topic: ResponseRepresentable { }

extension Topic: Timestampable {}
