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

    func build(_ builder: RouteBuilder) throws {
        // MARK: - User
        let user = builder.grouped(Keys.user)

        let tokenMiddleware = TokenAuthenticationMiddleware(User.self)
        let auth = user.grouped(tokenMiddleware)
        let topics = auth.grouped("topics")
        let topic = auth.grouped("topic")
        let comment = topic.grouped("comment")

        //MARK: - Search vocabularies
        builder.get("vocabularies") { (request) -> ResponseRepresentable in
            var page = 0
            var limit = 10
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
            var queryStr = ""
            if let key = keyWord {
                queryStr = "SELECT vocabularys.id as vocab_id , word, spell, type, translate, picture, examples.id as example_id, example_eng, example_vie FROM vocabularys "
                    + "INNER JOIN examples on vocabularys.id = examples.vocabulary_id "
                    + "where word LIKE '\(key)%' order by word asc LIMIT \(page * limit), \(limit)"
            } else {
                queryStr = "SELECT vocabularys.id as vocab_id , word, spell, type, translate, picture, examples.id as example_id, example_eng, example_vie FROM vocabularys "
                    + "INNER JOIN examples on vocabularys.id = examples.vocabulary_id "
                    + "order by word asc LIMIT \(page * limit), \(limit)"
            }
            print(queryStr)
            guard let nodeVocabs = try self.drop.database?.raw(queryStr).array else { throw Abort.badRequest }

            var json: JSON = JSON()
            try json.set("data", try Vocabulary.makeJsonVocabs(nodes: nodeVocabs))
            try json.set("have_next_page", nodeVocabs.count == limit)
            return json
        }

        //MARK: - Get list vocabularies of level
        auth.get("vocabularies/level", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let levelId = try request.parameters.next(Int.self)
                let queryStr = "SELECT vocabularys.id as vocab_id, vocabularys.word, vocabularys.spell, vocabularys.type, vocabularys.translate, vocabularys.picture, examples.id as example_id, example_vie, example_eng FROM topics inner JOIN topic_vocabulary ON topics.id = topic_vocabulary.topic_id inner JOIN vocabularys ON topic_vocabulary.vocabulary_id = vocabularys.id inner join examples on vocabularys.id = examples.vocabulary_id WHERE `topics`.`level_id` = \(levelId) AND topics.is_system = true"

                print(queryStr)
                if let nodes = try self.drop.database?.raw(queryStr).array {
                    let vocabularies = try Vocabulary.makeJsonVocabs(nodes: nodes)
                    var json: JSON = JSON()
                    try json.set("data", try vocabularies.makeJSON())
                    return json
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

        //MARK: - All system topics when level
        topics.get("system", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            let levelId = try request.parameters.next(Int.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr = "SELECT topics.id as id,  topics.name as name, status, is_system, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id and scores.user_id = \(userID)), 0) as achieved_score, "
                + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM topics inner join users on topics.user_id = users.id "
                + "where is_system = true and topics.level_id = \(levelId)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try Topic.makeJsonTopics(nodes: nodes))
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
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            var page = 0
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
                    case "page":
                        if let value = queryArray[1].int {
                            page = value
                        }
                    case "limit":
                        if let value = queryArray[1].int {
                            limit = value
                        }
                    default:
                        break
                    }
                }
            }
            let queryStr = "SELECT topics.id as id,  topics.name as name, status, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, topics.created_at as created_at, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM topics inner join users on topics.user_id = users.id "
                + "where is_system = false and status = true order by total_like desc, total_comment desc, topics.created_at desc LIMIT \(page * limit), \(limit)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try Topic.makeJsonTopicSocials(nodes: nodes))
                try json.set("have_next_page", nodes.count == limit)
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - topic detail
        auth.get("topic", Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            let topicID = try request.parameters.next(Int.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr1 = "SELECT topics.id as id,  topics.name as name, status, is_system, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id and scores.user_id =\(userID)), 0) as achieved_score, "
                + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM topics inner join users on topics.user_id = users.id where topics.id = \(topicID)"
            print(queryStr1)
            guard let node = try self.drop.database?.raw(queryStr1).array?.first else { throw Abort.contentNotFound }
            var json = try Topic.makeJsonTopic(node: node)

            let queryStr2 = "SELECT vocabularys.id as vocab_id , word, spell, type, translate, picture, examples.id as example_id, example_eng, example_vie FROM vocabularys INNER JOIN "
                + "topic_vocabulary on vocabularys.id =  topic_vocabulary.vocabulary_id "
                + "INNER JOIN examples on vocabularys.id = examples.vocabulary_id "
                + "where topic_vocabulary.topic_id = \(topicID)"
            print(queryStr2)
            guard let nodeVocabs = try self.drop.database?.raw(queryStr2).array else { throw Abort.badRequest }
            try json.set("vocabularies", try Vocabulary.makeJsonVocabs(nodes: nodeVocabs))
            return json
        }

        //MARK: - Get my topic
        topics.get("mine") { (request) -> ResponseRepresentable in
            var page = 0
            var limit = 10
            let user = try request.auth.assertAuthenticated(User.self)
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
                    default:
                        break
                    }
                }
            }
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr = "SELECT topics.id as id,  topics.name as name, status, is_system, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id and scores.user_id =\(userID)), 0) as achieved_score, "
                + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM topics inner join users on topics.user_id = users.id where topics.user_id = \(userID) order by created_at desc LIMIT \(page * limit), \(limit)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try Topic.makeJsonTopics(nodes: nodes))
                try json.set("have_next_page", nodes.count == limit)
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - add new topic
        topic.post("add") { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var name = ""
                var status = false
                var levelId = 1
                var vocabularies: [Int] = []
                var description: String?
                if let json = req.json {
                    name = try json.get(Topic.Keys.name)
                    status = try json.get(Topic.Keys.status)
                    levelId = try json.get(Topic.Keys.levelId)
                    vocabularies = try json.get("vocabularys")
                    description = try json.get(Topic.Keys.description)
                } else {
                    throw Abort.badRequest
                }
                if vocabularies.count == 0 {
                    throw Abort.badRequest
                }

                let topic = Topic(name: name, status: status, levelId: levelId, userId: userID, totalLike: 0, totalComment: 0, description: description)
                if user.isAdmin == true {
                    topic.status = true
                    topic.isSystem = true
                }
                try topic.save()
                guard let topicID = topic.id?.int else { return Response(status: .noContent) }
                var queryInsert = "INSERT INTO topic_vocabulary(vocabulary_id, topic_id) values"
                for vocabulariID in vocabularies {
                    queryInsert += " (\(vocabulariID), \(topicID)),"
                }
                queryInsert = queryInsert.substring(0, length: queryInsert.count - 1)
                print(queryInsert)
                try self.drop.database?.raw(queryInsert)

                let queryStr1 = "SELECT topics.id as id, topics.name as name, status, is_system, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, "
                    + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                    + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id and scores.user_id =\(userID)), 0) as achieved_score, "
                    + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                    + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                    + "(select name from levels where levels.id = topics.level_id ) as level_name "
                    + "FROM topics inner join users on topics.user_id = users.id where topics.id = \(topicID)"
                print(queryStr1)
                guard let node = try self.drop.database?.raw(queryStr1).array?.first else { return Response(status: .noContent) }
                var json = try Topic.makeJsonTopic(node: node)

                let queryStr2 = "SELECT vocabularys.id as vocab_id , word, spell, type, translate, picture, examples.id as example_id, example_eng, example_vie FROM vocabularys INNER JOIN "
                    + "topic_vocabulary on vocabularys.id =  topic_vocabulary.vocabulary_id "
                    + "INNER JOIN examples on vocabularys.id = examples.vocabulary_id "
                    + "where topic_vocabulary.topic_id = \(topicID)"
                print(queryStr2)
                guard let nodeVocabs = try self.drop.database?.raw(queryStr2).array else { return Response(status: .noContent) }
                try json.set("vocabularies", try Vocabulary.makeJsonVocabs(nodes: nodeVocabs))
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - edit topic
        topic.put("edit", Int.parameter) { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let topic_id = try req.parameters.next(Int.self)
                var name: String?
                var status: Bool?
                var levelId: Int?
                var vocabularies: [Int]?
                var description: String?
                if let json = req.json {
                    name = try json.get(Topic.Keys.name)
                    status = try json.get(Topic.Keys.status)
                    levelId = try json.get(Topic.Keys.levelId)
                    vocabularies = try json.get("vocabularys")
                    description = try json.get(Topic.Keys.description)
                } else {
                    throw Abort.badRequest
                }
                if let topic = try Topic.find(topic_id), let topicID = topic.id?.int {
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
                    if let description = description {
                        topic.description = description
                    }

                    if let vocabularies = vocabularies {
                        if vocabularies.count != 0 {
                            try Pivot<Topic, Vocabulary>.makeQuery().filter(raw: "topic_id = \(topic_id)").delete()
                            var queryInsert = "INSERT INTO topic_vocabulary(vocabulary_id, topic_id) values"
                            for vocabulariID in vocabularies {
                                queryInsert += " (\(vocabulariID), \(topicID)),"
                            }
                            queryInsert = queryInsert.substring(0, length: queryInsert.count - 1)
                            print(queryInsert)
                            try self.drop.database?.raw(queryInsert)
                        }
                    }
                    try topic.save()
                    let queryStr1 = "SELECT topics.id as id,  topics.name as name, status, is_system, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, "
                        + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                        + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id and scores.user_id =\(userID)), 0) as achieved_score, "
                        + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                        + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                        + "(select name from levels where levels.id = topics.level_id ) as level_name "
                        + "FROM topics inner join users on topics.user_id = users.id where topics.id = \(topicID)"
                    print(queryStr1)
                    guard let node = try self.drop.database?.raw(queryStr1).array?.first else { return Response(status: .noContent) }
                    var json = try Topic.makeJsonTopic(node: node)

                    let queryStr2 = "SELECT vocabularys.id as vocab_id , word, spell, type, translate, picture, examples.id as example_id, example_eng, example_vie FROM vocabularys INNER JOIN "
                        + "topic_vocabulary on vocabularys.id =  topic_vocabulary.vocabulary_id "
                        + "INNER JOIN examples on vocabularys.id = examples.vocabulary_id "
                        + "where topic_vocabulary.topic_id = \(topicID)"
                    print(queryStr2)
                    guard let nodeVocabs = try self.drop.database?.raw(queryStr2).array else { return Response(status: .noContent) }
                    try json.set("vocabularies", try Vocabulary.makeJsonVocabs(nodes: nodeVocabs))
                    return json
                } else {
                    throw Abort.contentNotFound
                }
            }
            throw Abort.badRequest
        }

        //MARK: - delete topic
        topic.delete("delete", Int.parameter) { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let id = try req.parameters.next(Int.self)
                let topic = try Topic.makeQuery().filter(raw: "user_id = \(userID) AND id = \(id)").first()
                if let topic = topic, let topicID = topic.id?.int {
                    let call = "call deleteTopic(\(topicID), \(topic.isSystem))"
                    try self.drop.database?.raw(call)
                    let response = Response(status: .noContent)
                    return response
                } else {
                    throw Abort.contentNotFound
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
                    let call = "call addScore(\(scoreNum), \(topicId),\(userID))"
                    try self.drop.database?.raw(call)
                    return Response(status: .noContent)
                }
            }
            throw Abort.badRequest
        }

        //MARK: - Comment
        comment.post(Int.parameter) { (req) -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            let topicId = try req.parameters.next(Int.self)
            guard let json = req.json,
                let content = json["content"]?.string,
                let userId = user.id?.int else { throw Abort.badRequest }
            let comment = XIIComment(content: content, userId: userId, topicId: topicId)
            try comment.save()
            if let topic = try comment.topic.get() {
//                let comments = try topic.comments.makeQuery().filter("user_id", .notEquals, comment.userId).all()
//                var users: [User] = []
//                for comment in comments {
//                    if let user = try comment.user.get() {
//                        if users.contains(where: { (ur) -> Bool in
//                            ur.id == user.id
//                        }) { continue }
////                        if let deviceTokenNeedPush = user.deviceToken,
////                            !deviceTokenNeedPush.isEmpty {
////                            let payload = Payload()
////                            payload.extra = try NotificationManager.shared.createExtraPayload(userComment: user, userReceive: user, topic: topic, comment: comment, count: comments.count)
////                            let pushMessage = ApplePushMessage(topic: "com.tuanma.thuctap.10", priority: .immediately, payload: payload, sandbox: true)
////                            try NotificationManager.shared.send(pushMessage, to: deviceTokenNeedPush)
////                        }
//                        users.append(user)
//                    }
//                }
                topic.totalComment = Identifier((topic.totalComment.int ?? 0) + 1)
                try topic.save()
            }
            return try comment.makeJSON()
        }

        //MARK: - get comment topic
        comment.get(Int.parameter) { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                let id = try request.parameters.next(Int.self)
                var page = 0
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
                        case "page":
                            if let value = queryArray[1].int {
                                page = value
                            }
                        case "limit":
                            if let value = queryArray[1].int {
                                limit = value
                            }
                        default:
                            break
                        }
                    }
                }
                let queryStr = "SELECT cmt.id as id, content, cmt.created_at as created_at, user_id, name, avatarUrl FROM x_i_i_comments as cmt inner join users on cmt.user_id = users.id where topic_id = \(id) order by cmt.created_at desc LIMIT \(page * limit), \(limit)"
                print(queryStr)
                guard let nodes = try self.drop.database?.raw(queryStr).array else { throw Abort.contentNotFound }
                var json = JSON()
                try json.set("data", XIIComment.makeJSON(nodes: nodes))
                try json.set("have_next_page", nodes.count == limit)
                return json
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

                let queryStr1 = "SELECT topics.id as id,  topics.name as name, status, user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, topics.created_at as created_at, "
                    + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                    + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                    + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                    + "(select name from levels where levels.id = topics.level_id ) as level_name "
                    + "FROM topics inner join users on topics.user_id = users.id where topics.id = \(topicId)"
                print(queryStr1)
                guard let node = try self.drop.database?.raw(queryStr1).array?.first
                    else { throw Abort.contentNotFound }
                var json = try Topic.makeJsonTopicSocial(node: node)
                return json
            }
            throw Abort.badRequest
        }

        //MARK: - get topic like
        topics.get("like") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            var page = 0
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
                    case "page":
                        if let value = queryArray[1].int {
                            page = value
                        }
                    case "limit":
                        if let value = queryArray[1].int {
                            limit = value
                        }
                    default:
                        break
                    }
                }
            }
            let queryStr = "SELECT topics.id as id,  topics.name as name, status, topics.user_id as user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, topics.created_at as created_at, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM topics inner join favorites on topics.id = favorites.topic_id inner join users on topics.user_id = users.id where is_system = false and favorites.user_id = \(userID) order by favorites.created_at desc LIMIT \(page * limit), \(limit)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try Topic.makeJsonTopicSocials(nodes: nodes))
                try json.set("have_next_page", nodes.count == limit)
                return json
            }
            throw Abort.contentNotFound
        }

        //MARK: - get topic save
        topics.get("save") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            guard let userID = try user.assertExists().int else { throw Abort.badRequest }
            let queryStr = "SELECT topics.id as id,  topics.name as name, status, is_system, topics.user_id as user_id, users.name as user_name, email, avatarUrl, topics.level_id as level_id, total_like, total_comment, "
                + "(select count(id) FROM topic_vocabulary where topics.id = topic_vocabulary.topic_id) as total_vocab, "
                + "IFNULL((select score FROM scores WHERE topics.id = scores.topic_id and scores.user_id =\(userID)), 0) as achieved_score, "
                + "case when description IS NULL or description = '' then (select GROUP_CONCAT(word) FROM vocabularys inner join topic_vocabulary on  vocabularys.id = topic_vocabulary.vocabulary_id WHERE topic_vocabulary.topic_id = topics.id) else description end as description, "
                + "exists (select id FROM favorites WHERE topics.id = favorites.topic_id  and user_id = \(userID)) as isFavorite, "
                + "(select name from levels where levels.id = topics.level_id ) as level_name "
                + "FROM  topics inner join favorites on topics.id = favorites.topic_id inner join users on topics.user_id = users.id where is_system = true and favorites.user_id = \(userID)"
            print(queryStr)
            if let nodes = try self.drop.database?.raw(queryStr).array {
                var json = JSON()
                try json.set("data", try Topic.makeJsonTopics(nodes: nodes))
                return json
            }
            throw Abort.contentNotFound
        }

        //MARK: - get ranking
        auth.get("ranking") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            var limit = 20
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

            if let userID = user.id?.int, let totalScore = user.totalScore.int {

                let queryStrRanking = "SELECT @rownum := @rownum + 1 AS rank,  users.id, users.name, avatarUrl, total_score FROM users, (SELECT @rownum := 0) as r where is_admin = 0 ORDER BY total_score DESC LIMIT \(limit)"
                let queryStrUser = "SELECT users.id, users.name, avatarUrl,  total_score, ((SELECT count(id) FROM users where is_admin = 0 and total_score > \(totalScore)) + (SELECT count(id) FROM users where is_admin = 0 and total_score = \(totalScore) and id < \(userID))  + 1) as rank FROM users where id = \(userID)"
                print(queryStrUser)
                guard var nodes = try self.drop.database?.raw(queryStrRanking).array,
                    let user = try self.drop.database?.raw(queryStrUser).array?.first
                    else { throw Abort.badRequest }
                nodes.append(user)

                func makeJSON(nodes: [Node]) throws -> [JSON] {
                    var datas: [JSON] = []
                    try nodes.forEach({ (node) in
                        var json = JSON()
                        try json.set(User.Keys.id, node.get(User.Keys.id) as Int)
                        try json.set(User.Keys.name, node.get(User.Keys.name) as String)
                        try json.set(User.Keys.totalScore, node.get(User.Keys.totalScore) as Int)
                        let avatarUrl: String? = try node.get(User.Keys.avatarUrl)
                        if let avatarUrl = avatarUrl {
                            try json.set(User.Keys.avatarUrl, avatarUrl)
                        }
                        try json.set("rank", node.get("rank") as Int)
                        datas.append(json)
                    })
                    return datas
                }
                let datas = try makeJSON(nodes: nodes)


                var json = JSON()
                try json.set("data", datas)
                return json
            }
            throw Abort.contentNotFound
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

        auth.get("thisweek") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            if let userID = user.id?.int, let totalScore = user.totalScore.int {
                let queryStr = "SELECT (SELECT count(id) FROM scores where week(updated_at) = week(now()) and user_id = \(userID) and scores.score >= (select count(id) from topic_vocabulary where topic_id = scores.topic_id) * 15 * 0.8) as pass, (SELECT count(id) FROM topics where user_id = \(userID) and week(now()) = week(created_at)) as created, ((SELECT count(id) FROM users where is_admin = 0 and total_score > \(totalScore)) + (SELECT count(id) FROM users where is_admin = 0 and total_score = \(totalScore) and id < \(userID))  + 1) as rank"
                print(queryStr)
                guard let node = try self.drop.database?.raw(queryStr).array?.first else {
                    throw Abort.contentNotFound
                }
                var json = JSON()
                try json.set("pass", node.get("pass") as Int)
                try json.set("created", node.get("created") as Int)
                try json.set("rank", node.get("rank") as Int)
                return json
            }
            throw Abort.badRequest
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
