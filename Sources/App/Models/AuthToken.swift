//
//  AuthToken.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class AuthToken: Model {
    
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let token = "token"
        static let userid = "user_id"
    }
    
    // MARK: - Properties
    
    let storage = Storage()
    var token: String = ""
    let userId: Identifier
    
    var user: Parent<AuthToken, User> {
        return parent(id: userId)
    }
    
    init(userID: Int) {
        self.userId = Identifier(userID)
        self.token = String.randomString(length: 64)
    }
    
    // MARK: - Initializing
    
    init(row: Row) throws {
        token = try row.get(Keys.token)
        userId = try row.get(Keys.userid)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.token, token)
        try row.set(Keys.userid, userId)
        return row
    }
}


// MARK: - Relationships
// MARK: - JSONConvertible
// MARK: - Preparation

extension AuthToken: Preparation {
    
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Keys.token)
            builder.int(Keys.userid)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Updateable

extension AuthToken: Updateable {
    public static var updateableKeys: [UpdateableKey<AuthToken>] {
        return [
            UpdateableKey(Keys.token, String.self) { authToken, token in
                authToken.token = token
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension AuthToken: ResponseRepresentable {
    func makeResponse() throws -> Response {
        return Response(redirect: "ss")
    }
}
