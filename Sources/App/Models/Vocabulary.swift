//
//  Vocabulary.swift
//  AdminPanel
//
//  Created by MBA0280F on 2/25/19.
//

import Vapor
import FluentProvider
import HTTP

final class Vocabulary: Model {
    
    // MARK: - Defining
    
    struct Keys {
        static let id = "id"
        static let word = "word"
        static let spell = "spell"
        static let type = "type"
        static let translate = "translate"
        static let picture = "picture"
    }
    
    // MARK: - Properties
    let storage = Storage()
    var id: Identifier?
    var word: String = ""
    var spell: String = ""
    var type: String = ""
    var translate: String = ""
    var picture: String = ""
    // MARK: - Initializing
    
    init(word: String, spell: String, type: String, translate: String, picture: String) {
        self.word = word
        self.spell = spell
        self.type = type
        self.translate = translate
        self.picture = picture
    }
    
    init(row: Row) throws {
        id = try row.get(Keys.id)
        word = try row.get(Keys.word)
        spell = try row.get(Keys.spell)
        type = try row.get(Keys.type)
        translate = try row.get(Keys.translate)
        picture = try row.get(Keys.picture)
    }
    
    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Keys.id, id)
        try row.set(Keys.word, word)
        try row.set(Keys.spell, spell)
        try row.set(Keys.type, type)
        try row.set(Keys.translate, translate)
        try row.set(Keys.picture, picture)
        return row
    }
    
    public static func makeJsonVocabs(nodes: [Node]) throws -> [JSON] {
        var vocabs: [JSON] = []
        try nodes.forEach({ (nodeVocab) in
            var vocab = JSON()
            try vocab.set(Vocabulary.Keys.id, nodeVocab.get("vocab_id") as Int)
            try vocab.set(Vocabulary.Keys.word, nodeVocab.get(Vocabulary.Keys.word) as String)
            try vocab.set(Vocabulary.Keys.spell, nodeVocab.get(Vocabulary.Keys.spell) as String)
            try vocab.set(Vocabulary.Keys.type, nodeVocab.get(Vocabulary.Keys.type) as String)
            try vocab.set(Vocabulary.Keys.translate, nodeVocab.get(Vocabulary.Keys.translate) as String)
            try vocab.set(Vocabulary.Keys.picture, nodeVocab.get(Vocabulary.Keys.picture) as String)
            var example = JSON()
            try example.set(Example.Keys.id, nodeVocab.get("example_id") as Int)
            try example.set(Example.Keys.exampleEng, nodeVocab.get(Example.Keys.exampleEng) as String)
            try example.set(Example.Keys.exampleVie, nodeVocab.get(Example.Keys.exampleVie) as String)
            try example.set(Example.Keys.vocabularyId, nodeVocab.get("vocab_id") as Int)
            try vocab.set("examples", [example])
            vocabs.append(vocab)
        })
        return vocabs
    }
}

// MARK: - Relationships

extension Vocabulary {
    var topics: Siblings<Vocabulary, Topic, Pivot<Topic, Vocabulary>> {
        return siblings()
    }
    
    var examples: Children<Vocabulary, Example> {
        return children()
    }
}

// MARK: - JSONConvertible

extension Vocabulary: JSONConvertible {
    convenience init(json: JSON) throws {
        self.init(word: try json.get(Keys.word),
                  spell: try json.get(Keys.spell),
                  type: try json.get(Keys.type),
                  translate: try json.get(Keys.translate),
                  picture: try json.get(Keys.picture))
    }
    
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Keys.id, id)
        try json.set(Keys.word, word)
        try json.set(Keys.spell, spell)
        try json.set(Keys.type, type)
        try json.set(Keys.translate, translate)
        try json.set(Keys.picture, picture)
        try json.set("examples", try self.examples.all().makeJSON())
        return json
    }
}

// MARK: - Preparation

extension Vocabulary: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Keys.word)
            builder.string(Keys.spell)
            builder.string(Keys.type)
            builder.string(Keys.translate)
            builder.string(Keys.picture)
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: - Node
extension Vocabulary: NodeInitializable {
    convenience init(node: Node) throws {
        let id: Identifier = try node.get(Keys.id)
        self.init(word: try node.get(Keys.word),
                  spell: try node.get(Keys.spell),
                  type: try node.get(Keys.type),
                  translate: try node.get(Keys.translate),
                  picture: try node.get(Keys.picture))
        self.id = id
    }
}

// MARK: - Updateable

extension Vocabulary: Updateable {
    public static var updateableKeys: [UpdateableKey<Vocabulary>] {
        return [
            UpdateableKey(Keys.word, String.self) { vocabulary, word in
                vocabulary.word = word
            }, UpdateableKey(Keys.spell, String.self) { vocabulary, spell in
                vocabulary.spell = spell
            }, UpdateableKey(Keys.type, String.self) { vocabulary, type in
                vocabulary.type = type
            }, UpdateableKey(Keys.translate, String.self) { vocabulary, translate in
                vocabulary.translate = translate
            }, UpdateableKey(Keys.picture, String.self) { vocabulary, picture in
                vocabulary.picture = picture
            }
        ]
    }
}

// MARK: - ResponseRepresentable

extension Vocabulary: ResponseRepresentable { }

extension Vocabulary: Timestampable {}
