//
//  Example.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class Example: Model {
    
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let exampleEng = "example_eng"
        static let exampleVie = "example_vie"
        static let vocabularyId = "vocabulary_id"
    }
    
    // MARK: - Properties
    let storage = Storage()
    var id: Identifier?
    var exampleEng: String = ""
    var exampleVie: String = ""
    var vocabularyId: Identifier
    // MARK: - Initializing
    
    init(exampleEng: String, exampleVie: String, vocabularyId: Int) {
        self.exampleEng = exampleEng;
        self.exampleVie = exampleVie;
        self.vocabularyId = Identifier(vocabularyId)
    }
    
    init(row: Row) throws {
        id = try row.get(Keys.id)
        exampleEng = try row.get(Keys.exampleEng)
        exampleVie = try row.get(Keys.exampleVie)
        vocabularyId = try row.get(Keys.vocabularyId)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.id, id)
        try row.set(Keys.exampleEng, exampleEng)
        try row.set(Keys.exampleVie, exampleVie)
        try row.set(Keys.vocabularyId, vocabularyId)
        return row
    }
}

// MARK: - Relationships

extension Example {
    
    var vocabulary: Parent<Example, Vocabulary> {
        return parent(id: vocabularyId)
    }
}

// MARK: - JSONConvertible

extension Example: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(exampleEng: try json.get(Keys.exampleEng),
                  exampleVie: try json.get(Keys.exampleVie),
                  vocabularyId: try json.get(Keys.vocabularyId))
    }
    
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.exampleEng, exampleEng)
        try json.set(Keys.exampleVie, exampleVie)
        try json.set(Keys.vocabularyId, vocabularyId)
        return json
    }
}

// MARK: - Preparation

extension Example: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Keys.exampleEng)
            builder.string(Keys.exampleVie)
            builder.parent(Vocabulary.self, optional: false)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Node
extension Example: NodeInitializable {
    convenience init(node: Node) throws {
        let id: Int = try node.get(Keys.id)
        self.init(exampleEng: try node.get(Keys.exampleEng),
                  exampleVie: try node.get(Keys.exampleVie),
                  vocabularyId: try node.get(Keys.vocabularyId))
        self.id = Identifier(id)
    }
}

// MARK: - Updateable

extension Example: Updateable {
    public static var updateableKeys: [UpdateableKey<Example>] {
        return [
            UpdateableKey(Keys.exampleEng, String.self) { Example, exampleEng in
                Example.exampleEng = exampleEng
            }, UpdateableKey(Keys.exampleVie, String.self) { Example, exampleVie in
                Example.exampleVie = exampleVie
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension Example: ResponseRepresentable { }

extension Example: Timestampable {}
