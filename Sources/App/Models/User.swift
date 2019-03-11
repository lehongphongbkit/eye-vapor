//
//  User.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP
import AuthProvider

final class User: Model {

    // MARK: - Defining

    struct Keys {
        static let id = "id"
        static let name = "name"
        static let password = "password"
        static let phone = "phone"
        static let email = "email"
        static let avatarUrl = "avatarUrl"
        static let deviceToken = "deviceToken"
        static let gender = "gender"
        static let birthday = "birthday"
        static let levelId = "level_id"
        static let isAdmin = "is_admin"
        static let totalScore = "total_score"
    }

    // MARK: - Properties
    let storage = Storage()

    var name: String
    var password: String = ""
    var phone: String?
    var email: String
    var avatarUrl: String?
    var deviceToken: String?
    var gender: Bool?
    var birthday: String?
    var levelId: Identifier = 1
    var isAdmin = false
    var totalScore: Identifier = 0

    // MARK: - Initializing

    init(name: String, phone: String?, email: String, avatarUrl: String?, passWord: String, deviceToken: String?, gender: Bool?, birthday: String?) {
        self.name = name
        self.password = passWord
        self.phone = phone
        self.email = email
        self.avatarUrl = avatarUrl
        self.password = passWord
        self.deviceToken = deviceToken
        self.gender = gender
        self.birthday = birthday

    }

    init(row: Row) throws {
        password = try row.get(Keys.password)
        name = try row.get(Keys.name)
        phone = try row.get(Keys.phone)
        email = try row.get(Keys.email)
        avatarUrl = try row.get(Keys.avatarUrl)
        deviceToken = try row.get(Keys.deviceToken)
        gender = try row.get(Keys.gender)
        birthday = try row.get(Keys.birthday)
        levelId = try row.get(Keys.levelId)
        isAdmin = try row.get(Keys.isAdmin)
        totalScore = try row.get(Keys.totalScore)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.name, name)
        try row.set(Keys.password, password)
        try row.set(Keys.phone, phone)
        try row.set(Keys.email, email)
        try row.set(Keys.avatarUrl, avatarUrl)
        try row.set(Keys.deviceToken, deviceToken)
        try row.set(Keys.gender, gender)
        try row.set(Keys.birthday, birthday)
        try row.set(Keys.levelId, levelId)
        try row.set(Keys.isAdmin, isAdmin)
        try row.set(Keys.totalScore, totalScore)
        return row
    }

    public static func makeJsonUser(node: Node) throws -> JSON {
        var json = JSON()
        try json.set(User.Keys.id, node.get(User.Keys.id) as Int)
        try json.set(User.Keys.name, node.get(User.Keys.name) as String)
        try json.set(User.Keys.email, node.get(User.Keys.email) as String)
        let phone: String? = try node.get(User.Keys.phone)
        if let phone = phone {
            try json.set(User.Keys.phone, phone)
        }
        let avatarUrl: String? = try node.get(User.Keys.avatarUrl)
        if let avatarUrl = avatarUrl {
            try json.set(User.Keys.avatarUrl, avatarUrl)
        }
        let gender: Int? = try node.get(User.Keys.gender)
        if let gender = gender {
            try json.set(User.Keys.gender, gender)
        }
        let birthday: String? = try node.get(User.Keys.birthday)
        if let birthday = birthday {
            try json.set(User.Keys.birthday, birthday)
        }
        try json.set(User.Keys.totalScore, node.get(User.Keys.totalScore) as Int)
        try json.set(User.Keys.levelId, node.get(User.Keys.levelId) as Int)
        try json.set("level_name", node.get("level_name") as String)
        return json
    }

    public static func makeJsonUsers(nodes: [Node]) throws -> [JSON] {
        var datas: [JSON] = []
        try nodes.forEach({ (node) in
            var json = JSON()
            try json.set(User.Keys.id, node.get(User.Keys.id) as Int)
            try json.set(User.Keys.name, node.get(User.Keys.name) as String)
            let phone: String? = try node.get(User.Keys.phone)
            if let phone = phone {
                try json.set(User.Keys.phone, phone)
            }
            try json.set(User.Keys.email, node.get(User.Keys.email) as String)
            let avatarUrl: String? = try node.get(User.Keys.avatarUrl)
            if let avatarUrl = avatarUrl {
                try json.set(User.Keys.avatarUrl, avatarUrl)
            }
            let gender: Int? = try node.get(User.Keys.gender)
            if let gender = gender {
                try json.set(User.Keys.gender, gender)
            }
            let birthday: String? = try node.get(User.Keys.birthday)
            if let birthday = birthday {
                try json.set(User.Keys.birthday, birthday)
            }
            try json.set(User.Keys.totalScore, node.get(User.Keys.totalScore) as Int)
            try json.set(User.Keys.levelId, node.get(User.Keys.levelId) as Int)
            try json.set("level_name", node.get("level_name") as String)
            datas.append(json)
        })
        return datas
    }
}


// MARK: - Relationships

extension User {
    var favorites: Siblings<User, Topic, Favorite> {
        return siblings()
    }

//    var promotions: Siblings<User, Promotion, Pivot<User, Promotion>> {
//        return siblings()
//    }
//
//    var comments: Children<User, Comment> {
//        return children()
//    }

    var level: Parent<User, Level> {
        return parent(id: levelId)
    }


//    var notifications: Siblings<User, Notification, Pivot<User, Notification>> {
//        return siblings()
//    }
}


// MARK: - JSONConvertible

extension User: JSONConvertible {

    convenience init(json: JSON) throws {
        self.init(name: try json.get(Keys.name),
            phone: try json.get(Keys.phone),
            email: try json.get(Keys.email),
            avatarUrl: "",
            passWord: "",
            deviceToken: try json.get(Keys.deviceToken),
            gender: try json.get(Keys.gender),
            birthday: try json.get(Keys.birthday)
        )
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        try json.set(Keys.phone, phone)
        try json.set(Keys.email, email)
        if let avatarUrl = avatarUrl {
            try json.set(Keys.avatarUrl, avatarUrl)
        }
        if let gender = gender {
            try json.set(Keys.gender, gender)
        }
        if let birthday = birthday {
            try json.set(Keys.birthday, birthday)
        }
        try json.set(Keys.totalScore, totalScore)
        if let level: Level = try self.level.get() {
            try json.set(User.Keys.levelId, level.id)
            try json.set("level_name", level.name)
        }
        return json
    }

    func sortJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.name, name)
        if let avatarUrl = avatarUrl {
            try json.set(Keys.avatarUrl, avatarUrl)
        }

        try json.set(Keys.totalScore, totalScore)
        return json
    }
}

// MARK: - Preparation

extension User: Preparation {

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Keys.name, length: 50, optional: false)
            builder.string(Keys.password, optional: false)
            builder.string(Keys.phone, length: 15, optional: true)
            builder.string(Keys.email, length: 50, optional: false, unique: true)
            builder.string(Keys.avatarUrl, length: 100, optional: true)
            builder.string(Keys.deviceToken, length: 64, optional: true, unique: true)
            builder.bool(Keys.gender, optional: true)
            builder.string(Keys.birthday, length: 11, optional: true)
            builder.parent(Level.self, optional: true)
            builder.bool(Keys.isAdmin)
            builder.int(Keys.totalScore)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Auth

extension User: TokenAuthenticatable {
    public typealias TokenType = AuthToken
}

// MARK: - PasswordAuthenticatable
extension User: PasswordAuthenticatable { }
extension Request {

    func login(drop: Droplet) throws -> User? {
        guard let json = json else {
            throw Abort(
                    .badRequest,
                metadata: nil,
                reason: "Data wrong"
            )
        }
        let mail: String = try json.get(User.Keys.email)
        var password: String = try json.get(User.Keys.password)

        let user = try User.makeQuery().filter(User.Keys.email, mail).first()
        guard let userGet = user else { return nil }
        password = try drop.hash.make(password.makeBytes()).makeString()
        if userGet.password == password {
            if let deviceToken: String = json[User.Keys.deviceToken]?.string {
                if !deviceToken.isEmpty {
                    userGet.deviceToken = deviceToken
                }
            }
            return user
        }
        return nil
    }

    func makeUser(drop: Droplet) throws -> User? {
        guard let json = json else {
            return nil
        }
        let password: String = try json.get(User.Keys.password)
        let passwordBytes = password.makeBytes()
        let passwordHart = try drop.hash.make(passwordBytes).makeString()
        let user = try User(json: json)
        user.password = passwordHart
        return user
    }

    func user() throws -> User {
        return try auth.assertAuthenticated()
    }
}

// MARK: - Updateable

extension User: Updateable {

    public static var updateableKeys: [UpdateableKey<User>] {
        return [
            UpdateableKey(Keys.name, String.self) { user, name in
                user.name = name
            }, UpdateableKey(Keys.phone, String.self) { user, phone in
                user.phone = phone
            }, UpdateableKey(Keys.email, String.self) { user, email in
                user.email = email
            }, UpdateableKey(Keys.deviceToken, String.self) { user, deviceToken in
                user.deviceToken = deviceToken
            }, UpdateableKey(Keys.gender, Bool.self) { user, gender in
                user.gender = gender
            }, UpdateableKey(Keys.birthday, String.self) { user, birthday in
                user.birthday = birthday
            }, UpdateableKey(Keys.totalScore, Int.self) { user, totalScore in
                user.totalScore = Identifier(totalScore)
            }, UpdateableKey(Keys.levelId, Int.self) { user, levelId in
                user.totalScore = Identifier(levelId)
            }
        ]
    }
}

// MARK: - ResponseRepresentable
extension User: ResponseRepresentable { }
