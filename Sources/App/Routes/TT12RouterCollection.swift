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
//            let queryStr = "SELECT count(tp.id) as completed_topic, "
//                + "(SELECT count(vapor.topics.id) FROM vapor.topics "
//                + "WHERE level_id = \(idLevel)) as total_topic "
//                + "FROM vapor.topics as tp inner join vapor.scores on scores.topic_id = tp.id "
//                + "WHERE is_system = 1 and level_id = \(idLevel) and "
//                + "scores.user_id = \(userID) and score>= "
//                + "\(SCORE_OF_VOCAB) * (SELECT count(topic_vocabulary.id) "
//                + "FROM vapor.topics as tp2 inner join "
//                + "vapor.topic_vocabulary on tp2.id = topic_id where tp2.id = tp.id)* 0.8"
            var datas: [JSON] = []
            let levels = try Level.all()
            for level in levels {
                datas.append(try level.makeFullJSON(user: user))
            }
            var json = JSON()
            try json.set("data", datas)
            return json
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
            let topics = try Topic.makeQuery().filter(raw: "(is_system = \(true)) AND level_id = \(levelId)").all()
            var json = JSON()
            var datas: [JSON] = []
            for topic in topics {
                datas.append(try topic.makeFullJson(userID: user.assertExists()))
            }
            try json.set("data", datas)
            return json
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
            if let userID = try user.assertExists().int {
                let id = try request.parameters.next(Int.self)
                let topic = try Topic.makeQuery().filter(raw: "(user_id = \(userID) OR status = '0' OR is_system = \(true)) AND id = \(id)").first()
                if let topic = topic {
                    var json = try topic.makeDetailJson()
                    let queryStr = "SELECT scores.topic_id, scores.score FROM scores "
                        + "WHERE `scores`.`user_id` = \(userID) and `scores`.`topic_id` = \(id) "
                    print(queryStr)
                    if let nodes = try self.drop.database?.raw(queryStr).array, let node = nodes.first {
                        let score: Int = try node.get("score")
                        try json.set("achieved_score", score)
                    } else {
                        try json.set("achieved_score", 0)

                    }
                    try json.set("total_score", topic.vocabularies.count() * SCORE_OF_VOCAB)
                    let description = try topic.vocabularies.all().reduce(into: "", { (result, vocab) in
                        result += vocab.word + ", "
                    })
                    try json.set("description", description)
                    return json
                } else {
                    throw Abort.contentNotFound
                }
            }
            throw Abort.badRequest
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
        auth.post("topic/like") { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            if let userID = try user.assertExists().int {
                var topicId = 0
                if let json = req.json {
                    topicId = try json.get("topic_id")
                } else {
                    throw Abort.badRequest
                }
                if topicId == 0 {
                    throw Abort.badRequest
                }
                if let topic = try Topic.find(topicId) {
                    if let favorite = try Favorite.makeQuery().filter(raw: "user_id = \(userID) AND topic_id = \(topicId)").first() {
                        try favorite.delete()
                        if let totalLike = topic.totalLike.int, totalLike > 0 {
                            topic.totalLike = Identifier(totalLike - 1)
                        }
                        try topic.save()
                        return Response(status: .noContent)
                    } else {
                        let favorite = Favorite(userId: userID, topicId: topicId)
                        topic.totalLike = Identifier((topic.totalLike.int ?? 0) + 1)
                        try favorite.save()
                        try topic.save()
                        return Response(status: .noContent)
                    }
                }
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

        //MARK: - topic comment
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
            let topics = try user.favorites.filter("is_system", .equals, false).all()
            var json: JSON = JSON()
            var datas: [JSON] = []
            for topic in topics {
                datas.append(try topic.makeFullJson(userID: user.assertExists()))
            }
            try json.set("data", datas)
            return json
        }

        //MARK: - get topic save
        topics.get("save") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            let topics = try user.favorites.filter("is_system", .equals, true).all()
            var json: JSON = JSON()
            var datas: [JSON] = []
            for topic in topics {
                datas.append(try topic.makeFullJson(userID: user.assertExists()))
            }
            try json.set("data", datas)
            return json
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
