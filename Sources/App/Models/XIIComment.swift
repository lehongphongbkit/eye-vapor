//
//  XIIComment.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class XIIComment: Model {
    let storage = Storage()

    var content: String
    var userId: Identifier
    var topicId: Identifier

    struct Keys {
        static let id = "id"
        static let content = "content"
        static let userId = "user_id"
        static let topicId = "topic_id"
        static let user = "user"
        static let createAt = "created_at"
    }

    init(content: String, userId: Int, topicId: Int) {
        self.content = content
        self.userId = Identifier(userId)
        self.topicId = Identifier(topicId)
    }

    init(row: Row) throws {
        content = try row.get(XIIComment.Keys.content)
        userId = try row.get(XIIComment.Keys.userId)
        topicId = try row.get(XIIComment.Keys.topicId)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(XIIComment.Keys.content, content)
        try row.set(XIIComment.Keys.topicId, topicId)
        try row.set(XIIComment.Keys.userId, userId)
        return row
    }

    static func makeJSON(nodes: [Node]) throws -> [JSON] {
        var datas = [JSON]()
        try nodes.forEach({ (node) in
            var json = JSON()
            try json.set(Keys.id, node.get(Keys.id) as Int)
            try json.set(Keys.content, node.get(Keys.content) as String)
            try json.set(Keys.createAt, node.get(Keys.createAt) as Date)
            var user = JSON()
            try user.set(User.Keys.id, node.get("user_id") as Int)
            try user.set(User.Keys.name, node.get(User.Keys.name) as String)
            if let avatarUrl: String = try node.get(User.Keys.avatarUrl) {
                try user.set(User.Keys.avatarUrl, avatarUrl)
            }
            try json.set("user", user)
            datas.append(json)
        })
        return datas
    }
}

// MARK: Fluent Preparation

extension XIIComment: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(XIIComment.Keys.content)
            builder.parent(User.self, optional: false)
            builder.parent(Topic.self, optional: false)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

extension XIIComment {
    var user: Parent<XIIComment, User> {
        return parent(id: userId)
    }

    var topic: Parent<XIIComment, Topic> {
        return parent(id: topicId)
    }
}


extension XIIComment: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(content: try json.get(Keys.content),
            userId: try json.get(Keys.userId),
            topicId: try json.get(Keys.topicId))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(XIIComment.Keys.id, id)
        try json.set(XIIComment.Keys.content, content)
        try json.set(XIIComment.Keys.createAt, createdAt)
        let user = try self.user.get()
        try json.set(XIIComment.Keys.user, user?.sortJSON())
        return json
    }
}

extension XIIComment: ResponseRepresentable { }

extension XIIComment: Updateable {
    static var updateableKeys: [UpdateableKey<XIIComment>] {
        return [
            UpdateableKey(XIIComment.Keys.content, String.self) { comment, content in
                comment.content = content
            }
        ]
    }
}

extension XIIComment: Timestampable { }
