//
//  TT12RouterCollection.swift
//  App
//
//  Created by Mai Anh Tuan on 12/13/17.
//

import Vapor
import AuthProvider
import VaporAPNS
import S3
import Foundation
import MySQL
import Validation
import ValidationProvider
import FluentProvider
import HTTP

class TT12RouterCollection: RouteCollection {

    struct Keys {
        static let user = "user"
        static let login = "login"
        static let favorites = "favorites"
        static let token = "token"
        static let register = "register"
        static let content = "content"
        static let comments = "comments"
        static let notifications = "notifications"
        static let topics = "topics"
        static let topic = "topic"
    }

    var drop: Droplet

    init(drop: Droplet) {
        self.drop = drop
    }
    
    func makeJsonTopic(nodes: [Node]) throws -> [JSON] {
        var datas: [JSON] = []
        try nodes.forEach({ (node) in
            var data = JSON()
            try data.set(Topic.Keys.id, node.get(Topic.Keys.id) as Int)
            try data.set(Topic.Keys.name, node.get(Topic.Keys.name) as String)
            try data.set(Topic.Keys.isSystem, node.get(Topic.Keys.isSystem) as Bool)
            try data.set(Topic.Keys.status, node.get(Topic.Keys.status) as Bool)
            try data.set(Topic.Keys.userId, node.get(Topic.Keys.userId) as Int)
            try data.set(Topic.Keys.levelId, node.get(Topic.Keys.levelId) as Int)
            try data.set(Topic.Keys.levelName, node.get(Topic.Keys.levelName) as String)
            try data.set(Topic.Keys.totalLike, node.get(Topic.Keys.totalLike) as Int)
            try data.set(Topic.Keys.totalComment, node.get(Topic.Keys.totalComment) as Int)
            let totalVocab: Int = try node.get(Topic.Keys.totalVocab)
            try data.set(Topic.Keys.totalVocab, totalVocab)
            try data.set(Topic.Keys.totalScore, totalVocab * SCORE_OF_VOCAB)
            try data.set(Topic.Keys.achievedScore, node.get(Topic.Keys.achievedScore) as Int)
            try data.set(Topic.Keys.description, node.get(Topic.Keys.description) as String)
            try data.set(Topic.Keys.isFavorite, node.get(Topic.Keys.isFavorite) as Bool)
            datas.append(data)
        })
        return datas
    }
    
    func build(_ builder: RouteBuilder) throws {
        // MARK: - User
        let user = builder.grouped(Keys.user)

        let tokenMiddleware = TokenAuthenticationMiddleware(User.self)
        let auth = user.grouped(tokenMiddleware)
        let topics = auth.grouped("topics")
        let topic = auth.grouped("topic")
       
        //MARK: - List vocabularies
        builder.get("vocabularies") { (request) -> ResponseRepresentable in
            var page = 0
            var limit = 100
            var letvelId: Int?
            var keyWord: String?
            if let queryString = request.uri.query {
                let queryStringArray = queryString.components(separatedBy: "&")
                for queryString in queryStringArray {
                    let queryArray = queryString.components(separatedBy: "=")
                    if queryArray.count < 2 {
                        throw Abort.badRequest
                    }
                    let key: String = queryArray[0]
                    switch key {
                    case "page":
                        if let value = queryArray[1].int {
                            page = value
                        }
                    case "limit":
                        if let value = queryArray[1].int {
                            limit = value
                        }
                    case "key":
                        keyWord = queryArray[1].string
                    default:
                        break
                    }
                }
            }
            var vocabularies: [Vocabulary] = []
            if let key = keyWord {
                vocabularies = try Vocabulary.makeQuery().filter(raw: "word LIKE '%\(key)%' or translate LIKE '%\(key)%'").limit(limit, offset: page * limit).all()
            } else {
                vocabularies = try Vocabulary.makeQuery().limit(limit, offset: page * limit).all()
            }
            var json: JSON = JSON()
            try json.set("data", try vocabularies.makeJSON())
            try json.set("have_next_page", vocabularies.count == limit)
            return json
        }

        //MARK: - List vocabularies of level
        auth.get("vocabularies/level", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let levelId = try request.parameters.next(Int.self)
                let queryStr = "SELECT vocabularys.id, vocabularys.word, vocabularys.spell, vocabularys.type, vocabularys.translate, vocabularys.picture FROM topics LEFT JOIN topic_vocabulary ON topics.id = topic_vocabulary.topic_id LEFT JOIN vocabularys ON topic_vocabulary.vocabulary_id = vocabularys.id WHERE (`topics`.`level_id` = \(levelId) AND (topics.is_system = \(true))) GROUP BY vocabularys.id"

                if let nodes = try self.drop.database?.raw(queryStr).array {
                    let vocabularies = try [Vocabulary](node: nodes)
                    var json: JSON = JSON()
                    try json.set("data", try vocabularies.makeJSON())
                    return json
                }
            }
            throw Abort.badRequest
        }

        // MARK: - Get score of user
        auth.get("score") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let queryStr = "SELECT topics.id, topics.name, scores.score FROM scores LEFT JOIN topics ON scores.topic_id = topics.id WHERE `scores`.`user_id` = \(userID)"
                print(queryStr)
                func makeJSON(nodes: [Node]) throws -> JSON {
                    var json = JSON()
                    var datas: [JSON] = []
                    try nodes.forEach({ (node) in
                        var data = JSON()
                        let id: Int = try node.get("id")
                        try data.set("topic_id", id)
                        let name: String = try node.get("name")
                        try data.set("topic_name", name)
                        let score: Int = try node.get("score")
                        try data.set("score", score)
                        datas.append(data)
                    })
                    try json.set("data", datas)
                    return json
                }
                if let nodes = try self.drop.database?.raw(queryStr).array {
                    return try makeJSON(nodes: nodes)
                }
            }
            throw Abort.badRequest
        }

        //MARK: - levels
        auth.get("levels") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            guard let userID = try user.assertExists().int, let levelID = user.levelId.int else { throw Abort.badRequest }
            let queryStr = "SELECT id, name, (id > \(levelID)) as isLock,"
                        + "(select count(id) from topics where topics.level_id = levels.id ) as total_topic,"
                        + "(select count(tp1.id) from topics as tp1 inner join scores on tp1.id = scores.topic_id where is_system = 1 and tp1.level_id = levels.id and scores.user_id = \(userID) and score >= \(SCORE_OF_VOCAB) * (SELECT count(topic_vocabulary.id)  FROM topics as tp2  inner join topic_vocabulary on tp2.id = topic_vocabulary.topic_id where tp2.id = tp1.id)* 0.8) as completed_topic "
                        + "FROM levels"
            print(queryStr)
            
            func makeJSON(nodes: [Node]) throws -> JSON {
                var json = JSON()
                var datas: [JSON] = []
                try nodes.forEach({ (node) in
                    var data = JSON()
                    try data.set(Level.Keys.id, node.get(Level.Keys.id) as Int)
                    try data.set(Level.Keys.name, node.get(Level.Keys.name) as String)
                    try data.set(Level.Keys.isLock, node.get(Level.Keys.isLock) as Bool)
                    try data.set(Level.Keys.totalTopic, node.get(Level.Keys.totalTopic) as Int)
                    try data.set(Level.Keys.completedTopic, node.get(Level.Keys.completedTopic) as Int)
                    datas.append(data)
                })
                try json.set("data", datas)
                return json
            }
            
            if let nodes = try self.drop.database?.raw(queryStr).array {
                return try makeJSON(nodes: nodes)
            }
            throw Abort.badRequest
        }

        //MARK: - List topic from use
        auth.get("topics") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let topics = try Topic.makeQuery().filter(Topic.Keys.userId, .equals, userID).all()
                var json = JSON()
                var datas: [JSON] = []
                for topic in topics {
                    datas.append(try topic.makeFullJson())
                }
                try json.set("data", datas)
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - All system topics when level
        topics.get("system", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            let levelId = try request.parameters.next(Int.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr = "SELECT id,  name, status, is_system, user_id, level_id, total_like, total_comment, "
                        + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                        + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id), 0) as achieved_score, "
                        + "IFNULL((select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id), '') as description, "
                        + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                        + "(select name from levels where levels.id = topics.level_id ) as level_name "
                        + "FROM  topics where is_system = true and level_id = \(levelId)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try self.makeJsonTopic(nodes: nodes))
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - All public topics when level
        topics.get("all") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var level: Int?
                if let queryString = request.uri.query {
                    let queryStringArray = queryString.components(separatedBy: "&")
                    for queryString in queryStringArray {
                        let queryArray = queryString.components(separatedBy: "=")
                        if queryArray.count < 2 {
                            throw Abort.badRequest
                        }
                        let key: String = queryArray[0]
                        switch key {
                        case "level":
                            if let value = queryArray[1].int {
                                level = value
                            }
                        default:
                            break
                        }
                    }
                }
                var topics: [Topic] = []
                if let level = level {
                    topics = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR status = '0' OR is_system = \(true)) AND level_id = \(level)").all()
                } else {
                    topics = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR status = '0' OR is_system = \(true))").all()
                }
                var json = JSON()
                var datas: [JSON] = []
                for topic in topics {
                    datas.append(try topic.makeFullJson())
                }
                try json.set("data", datas)
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - get top topic public
        auth.get("topics/top") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var limit = 10
                if let queryString = request.uri.query {
                    let queryStringArray = queryString.components(separatedBy: "&")
                    for queryString in queryStringArray {
                        let queryArray = queryString.components(separatedBy: "=")
                        if queryArray.count < 2 {
                            throw Abort.badRequest
                        }
                        let key: String = queryArray[0]
                        switch key {
                        case "limit":
                            if let value = queryArray[1].int {
                                limit = value
                            }
                        default:
                            break
                        }
                    }
                }
                var topics: [Topic] = []

                topics = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR status = '0') ORDER BY total_like DESC LIMIT \(limit)").all()

                var json = JSON()
                var datas: [JSON] = []
                for topic in topics {
                    var json = try topic.makeTopJson()
                    let favorites = try Favorite.makeQuery().filter(raw: "user_id = \(userID) AND topic_id = \(topic.assertExists().int!)").all()
                    try json.set("is_like", !favorites.isEmpty)
                    datas.append(json)
                }
                try json.set("data", datas)
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - topic detail
        auth.get("topic", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            let topicID = try request.parameters.next(Int.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr1 = "SELECT id,  name, status, is_system, user_id, level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id), 0) as achieved_score, "
                + "IFNULL((select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id), '') as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM  topics where id = \(topicID)"
            print(queryStr1)
            guard let nodes = try self.drop.database?.raw(queryStr1).array else { throw Abort.badRequest }
            var json = try self.makeJsonTopic(nodes: nodes)[0]
            
            let queryStr2 = "SELECT vocabularys.id as vocab_id , word, spell, type, translate, picture, examples.id as example_id, example_eng, example_vie FROM vocabularys INNER JOIN "
                + "topic_vocabulary on vocabularys.id =  topic_vocabulary.vocabulary_id "
                + "INNER JOIN examples on vocabularys.id = examples.vocabulary_id "
                + "where topic_vocabulary.topic_id = \(topicID)"
            print(queryStr2)
            guard let nodeVocabs = try self.drop.database?.raw(queryStr2).array else { throw Abort.badRequest }
            var vocabs: [JSON] = []
            try nodeVocabs.forEach({ (nodeVocab) in
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
            try json.set("vocabularies", vocabs)
            return json
//            guard let topic = try Topic.makeQuery().filter(raw: "id = \(topicID)").first()
//                else {
//                    throw Abort.badRequest
//            }
//
//            let vocabs = try topic.vocabularies.all().makeJSON()
//            try json.set("vocabularies", vocabs)
//            return json
//            let user = try request.auth.assertAuthenticated(User.self)
//            if let userID = try user.assertExists().int {
//                let id = try request.parameters.next(Int.self)
//                let topic = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR status = '0' OR is_system = \(true)) AND id = \(id)").first()
//                if let topic = topic {
//                    var json = try topic.makeDetailJson()
//                    let queryStr = "SELECT scores.topic_id, scores.score FROM scores "
//                        + "WHERE `scores`.`user_id` = \(userID) and `scores`.`topic_id` = \(id) "
//                    print(queryStr)
//                    if let nodes = try self.drop.database?.raw(queryStr).array, let node = nodes.first {
//                        let score: Int = try node.get("score")
//                        try json.set("achieved_score", score)
//                    } else {
//                        try json.set("achieved_score", 0)
//
//                    }
//                    try json.set("total_score", topic.vocabularies.count() * SCORE_OF_VOCAB)
//                    let description = try topic.vocabularies.all().reduce(into: "", { (result, vocab) in
//                        result += vocab.word + ", "
//                    })
//                    try json.set("description", description)
//                    return json
//                } else {
//                    throw Abort.contentNotFound
//                }
//            }
//            throw Abort.badRequest
        }

        //MARK: - create new topic
        auth.post("topic") { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var name = ""
                var status = "0"
                var levelId = 1
                var vocabularies: [Int] = []
                if let json = req.json {
                    name = try json.get(Topic.Keys.name)
                    status = try json.get(Topic.Keys.status)
                    levelId = try json.get(Topic.Keys.levelId)
                    vocabularies = try json.get("vocabularys")
                } else {
                    throw Abort.badRequest
                }
                if vocabularies.count == 0 {
                    throw Abort.badRequest
                }
                let topic = Topic(name: name, status: status, levelId: levelId, userId: userID, totalLike: 0, totalComment: 0)
                if user.isAdmin == true {
                    topic.status = "1"
                    topic.isSystem = true
                }
                try topic.save()
                for vocabulariID in vocabularies {
                    if let vocabulary = try Vocabulary.makeQuery().find(vocabulariID) {
                        let pivolot = try Pivot<Topic, Vocabulary>(topic, vocabulary)
                        try pivolot.save()
                    }
                }
                return try topic.makeDetailJson()
            }
            throw Abort.badRequest
        }

        //MARK: - edit topic
        auth.put("topic", Int.parameter) { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let topic_id = try req.parameters.next(Int.self)
                var name: String?
                var status: String?
                var levelId: Int?
                var vocabularies: [Int]?
                if let json = req.json {
                    name = try json.get(Topic.Keys.name)
                    status = try json.get(Topic.Keys.status)
                    levelId = try json.get(Topic.Keys.levelId)
                    vocabularies = try json.get("vocabularys")
                } else {
                    throw Abort.badRequest
                }
                if let topic = try Topic.find(topic_id) {
                    if topic.userId.int != userID {
                        throw Abort.notPermission
                    }
                    if let name = name {
                        topic.name = name
                    }
                    if let status = status {
                        topic.status = status
                    }
                    if let levelId = levelId {
                        topic.levelId = Identifier(levelId)
                    }
                    if let vocabularies = vocabularies {
                        if vocabularies.count != 0 {
                            try Pivot<Topic, Vocabulary>.makeQuery().filter(raw: "topic_id = \(topic_id)").delete()

                            for vocabulariID in vocabularies {
                                if let vocabulary = try Vocabulary.makeQuery().find(vocabulariID) {
                                    let pivolot = try Pivot<Topic, Vocabulary>(topic, vocabulary)
                                    try pivolot.save()
                                }
                            }
                        }
                    }
                    try topic.save()
                    return try topic.makeDetailJson()
                } else {
                    throw Abort.contentNotFound
                }
            }
            throw Abort.badRequest
        }

        //MARK: - like and unlike a topic
        topic.post("like") { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var topicId = 0
                if let json = req.json {
                    topicId = try json.get("id")
                } else {
                    throw Abort.badRequest
                }
                if topicId == 0 {
                    throw Abort.badRequest
                }
                let call = "call likeTopic(\(userID), \(topicId))"
                try self.drop.database?.raw(call)
                return Response(status: .noContent)
            }
            throw Abort.badRequest
        }

        //MARK: - delete topic
        auth.delete("topic", Int.parameter) { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let id = try req.parameters.next(Int.self)
                let topic = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR is_system = \(true)) AND id = \(id)").first()
                if let topic = topic {
                    for vocabulary in try topic.vocabularies.all() {
                        if let topicId = try topic.assertExists().int, let vocaId = try vocabulary.assertExists().int {
                            try Pivot<Topic, Vocabulary>.makeQuery().filter(raw: "topic_id = \(topicId) AND vocabulary_id = \(vocaId) ").delete()
                        }
                    }
                    for favorite in try topic.favorites.all() {
                        try favorite.delete()
                    }
                    try topic.delete()
                    let response = Response(status: .noContent)
                    return response
                } else {
                    throw Abort.badRequest
                }
            }
            throw Abort.badRequest
        }

        //MARK: - add score
        auth.post("score") { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var scoreNum = 0
                var topicId = 0
                if let json = req.json {
                    scoreNum = try json.get(Score.Keys.score)
                    topicId = try json.get("topic_id")
                    if let score = try Score.makeQuery().filter(raw: "user_id = \(userID) AND topic_id = \(topicId)").first() {
                        if user.totalScore.int != nil {
                            user.totalScore = Identifier(user.totalScore.int! + scoreNum - score.score)
                        } else {
                            user.totalScore = Identifier(scoreNum - score.score)
                        }
                        try user.save()
                        score.score = scoreNum
                        try score.save()
                        return try score.makeJSON()
                    } else {
                        if user.totalScore.int != nil {
                            user.totalScore = Identifier(user.totalScore.int! + scoreNum)
                        } else {
                            user.totalScore = Identifier(scoreNum)
                        }
                        try user.save()
                        let score = Score(score: scoreNum, topicId: topicId, userId: userID)
                        try score.save()
                        return try score.makeJSON()
                    }
                } else {
                    throw Abort.badRequest
                }
            }
            throw Abort.badRequest
        }

//        //MARK: - Comment
//        auth.post("comment") { (req) -> ResponseRepresentable in
//            let user = try req.auth.assertAuthenticated(User.self)
//            guard let json = req.json,
//                let topicId = json["topic_id"]?.int,
//                let content = json["content"]?.string,
//                let userId = user.id?.int else { throw Abort.badRequest }
//            let comment = XIIComment(content: content, userId: userId, topicId: topicId)
//            try comment.save()
//            if let topic = try comment.topic.get() {
//                let comments = try topic.comments.makeQuery().filter("user_id", .notEquals, comment.userId).all()
//                var users: [User] = []
//                for comment in comments {
//                    if let user = try comment.user.get() {
//                        if users.contains(where: { (ur) -> Bool in
//                            ur.id == user.id
//                        }) { continue }
//                        if let deviceTokenNeedPush = user.deviceToken,
//                            !deviceTokenNeedPush.isEmpty {
//                            let payload = Payload()
//                            payload.extra = try NotificationManager.shared.createExtraPayload(userComment: user, userReceive: user, topic: topic, comment: comment, count: comments.count)
//                            let pushMessage = ApplePushMessage(topic: "com.tuanma.thuctap.10", priority: .immediately, payload: payload, sandbox: true)
//                            try NotificationManager.shared.send(pushMessage, to: deviceTokenNeedPush)
//                        }
//                        users.append(user)
//                    }
//                }
//                topic.totalComment = Identifier((topic.totalComment.int ?? 0) + 1)
//                try topic.save()
//            }
//            return try comment.makeJSON()
//        }

        //MARK: - get topic comment
        auth.get("comment/topic", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let id = try request.parameters.next(Int.self)
                let topic = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR status = '0' OR is_system = \(true)) AND id = \(id)").first()
                if let topic = topic {
                    var json: JSON = JSON()
                    try json.set("data", try topic.comments.all().makeJSON())
                    return json
                } else {
                    throw Abort.contentNotFound
                }
            }
            throw Abort.badRequest
        }

        //MARK: - get topic like
        topics.get("like") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr = "SELECT topics.id as id,  name, status, is_system, topics.user_id as user_id, level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id), 0) as achieved_score, "
                + "IFNULL((select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id), '') as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM  topics inner join favorites on topics.id = favorites.topic_id where is_system = false and favorites.user_id = \(userID)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try self.makeJsonTopic(nodes: nodes))
                return json
            }
            throw Abort.contentNotFound
        }

        //MARK: - get topic save
        topics.get("save") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr = "SELECT topics.id as id,  name, status, is_system, topics.user_id as user_id, level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id), 0) as achieved_score, "
                + "IFNULL((select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id), '') as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM  topics inner join favorites on topics.id = favorites.topic_id where is_system = true and favorites.user_id = \(userID)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try self.makeJsonTopic(nodes: nodes))
                return json
            }
            throw Abort.contentNotFound
        }

        //MARK: - get ranking
        auth.get("ranking") { (request) -> ResponseRepresentable in
            let _ = try request.auth.assertAuthenticated(User.self)
            var limit = 10
            if let queryString = request.uri.query {
                let queryStringArray = queryString.components(separatedBy: "&")
                for queryString in queryStringArray {
                    let queryArray = queryString.components(separatedBy: "=")
                    if queryArray.count < 2 {
                        throw Abort.badRequest
                    }
                    let key: String = queryArray[0]
                    switch key {
                    case "limit":
                        if let value = queryArray[1].int {
                            limit = value
                        }
                    default:
                        break
                    }
                }
            }

            let users = try User.makeQuery().sort("total_score", Sort.Direction.descending).limit(limit).all()
            var json = JSON()
            try json.set("data", try users.makeJSON())
            return json
        }

//        // MARK: - Favorites
//        try auth.resource(Keys.favorites, FavoriteController.self)
//
//        // MARK: - Comments
//        auth.resource(Keys.comments, CommentController(drop))
//
//        // MARK: - Natification
//        try auth.resource(Keys.notifications, NotificationController.self)
    }
}
