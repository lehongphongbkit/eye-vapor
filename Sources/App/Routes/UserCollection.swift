//
//  UserCollection.swift
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

class UserCollection: RouteCollection {

    struct Keys {
        static let user = "user"
        static let login = "login"
        static let favorites = "favorites"
        static let token = "token"
        static let promotions = "promotions"

        static let branches = "branches"
        static let products = "products"
        static let shopIdParam = ":shopId"
        static let shopId = "shopId"
        static let branchIdParam = ":branchId"
        static let branchId = "branchId"
        static let productIdParam = ":productId"
        static let productId = "productId"
        static let promotionId = "promotionId"
        static let register = "register"
        static let content = "content"
        static let comments = "comments"
        static let notifications = "notifications"
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

        // MARK: - Register
        user.post(Keys.register) { req -> ResponseRepresentable in
            var nameValue = ""
            var passwordValue = ""
            var emailValue = ""
            var phoneValue: String?
            var gender: Bool?
            var birthday: String?
            if let json = req.json {
                if let name: String = try json.get(User.Keys.name),
                    let email: String = try json.get(User.Keys.email),
                    let password: String = try json.get(User.Keys.password) {
                    nameValue = name
                    emailValue = email
                    passwordValue = password
                } else {
                    throw Abort.validUser
                }
                phoneValue = try json.get(User.Keys.phone)
                gender = try json.get(User.Keys.gender)
                birthday = try json.get(User.Keys.birthday)
            } else {
                guard let formData = req.formData else {
                    throw Abort.badRequest
                }
                guard let name = formData[User.Keys.name]?.string,
                    let password = formData[User.Keys.password]?.string,
                    let email = formData[User.Keys.email]?.string else {
                        throw Abort.validUser
                }
                nameValue = name
                emailValue = email
                passwordValue = password
                phoneValue = req.formData?[User.Keys.phone]?.string
                gender = req.formData?[User.Keys.gender]?.bool
                birthday = req.formData?[User.Keys.birthday]?.string
            }

            try emailValue.validateEmail()
//            try nameValue.validateName()
            try passwordValue.validatePassword()

            if let phoneValue = phoneValue {
                try phoneValue.validatePhone()
            }

            let passwordBytes = passwordValue.makeBytes()
            let passwordHart = try self.drop.hash.make(passwordBytes).makeString()

            let user = User(name: nameValue,
                phone: phoneValue,
                email: emailValue,
                avatarUrl: nil,
                passWord: passwordHart,
                deviceToken: nil,
                gender: gender,
                birthday: birthday)

            if let filebytes = req.formData?["avatar"]?.part.body,
                let imageType = req.formData?["avatar"]?.part.headers["Content-Type"]
            {
                var imageName = String.randomString(length: 60)
                switch imageType {
                case "image/jpeg":
                    imageName += ".jpg"
                case "image/png":
                    imageName += ".png"
                default:
                    throw Abort.init(.badRequest, metadata: nil, reason: "Image wrong")
                }
                let upload = UploadImage(droplet: self.drop)
                let link = try upload.post(data: Data(bytes: filebytes))
                user.avatarUrl = link
            }
            try user.save()
            guard let userID = user.id?.int else { throw Abort.badRequest }
            let token = AuthToken(userID: userID)
            let call = "call newToken('\(token.token)', \(userID))"
            try self.drop.database?.raw(call)
            var json = try user.makeJSON()
            try json.set(Keys.token, token.token)
            return json
        }

        // MARK: - Login
        user.post("login") { request -> ResponseRepresentable in
            guard let user = try request.login(drop: self.drop) else {
                throw Abort.init(.badRequest, reason: "Email or Password incorrect")
            }
            guard let id = try user.assertExists().int else { throw Abort.badRequest }
            let token = AuthToken(userID: id)
            let call = "call newToken('\(token.token)', \(id))"
            try self.drop.database?.raw(call)
            let queryStr = "SELECT users.id, users.name, phone, email, avatarUrl, gender, birthday, total_score, level_id, levels.name as level_name FROM users inner join levels on users.level_id = levels.id where users.id = \(id)"
            guard let node = try self.drop.database?.raw(queryStr).array?.first else { throw Abort.badRequest }
            var json = try User.makeJsonUser(node: node)
            try json.set(Keys.token, token.token)
            return json
        }

        auth.get("logout") { request throws -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            guard let id = try user.assertExists().int else { throw Abort.badRequest }
            try self.drop.database?.raw("DELETE FROM auth_tokens WHERE user_id = \(id)")
            return Response(status: .noContent)
        }

        //MARK: - Me:
        auth.get("me") { (request) -> ResponseRepresentable in
            let user = try request.auth.assertAuthenticated(User.self)
            return try user.makeJSON()
        }

        //MARK: - update avatar
        auth.patch("avatar") { (req) -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)

            guard let filebytes = req.formData?["avatar"]?.part.body,
                let imageType = req.formData?["avatar"]?.part.headers["Content-Type"] else {
                    throw Abort.badRequest
            }
            var imageName = String.randomString(length: 60)
            switch imageType {
            case "image/jpeg":
                imageName += ".jpg"
            case "image/png":
                imageName += ".png"
            default:
                throw Abort.init(.badRequest, metadata: nil, reason: "image sai dinh dang")
            }
            let upload = UploadImage(droplet: self.drop)
            if let link = try upload.post(data: Data(bytes: filebytes)) {
                user.avatarUrl = link
                try user.save()
                return try user.makeJSON()
            }
            throw Abort.badRequest
        }

        // MARK: - Update
        auth.patch("update") { req -> ResponseRepresentable in
            let user = try req.auth.assertAuthenticated(User.self)
            var check = false
            var nameValue: String?
            var passwordValue: String?
            var emailValue: String?
            var phoneValue: String?
            var gender: Bool?
            var birthday: String?
            var levelId: Int?
            if let json = req.json {
                nameValue = try json.get(User.Keys.name)
                emailValue = try json.get(User.Keys.email)
                passwordValue = try json.get(User.Keys.password)
                phoneValue = try json.get(User.Keys.phone)
                gender = try json.get(User.Keys.gender)
                birthday = try json.get(User.Keys.birthday)
                levelId = try json.get(User.Keys.levelId)
            } else {
                guard let formData = req.formData else {
                    throw Abort.badRequest
                }
                nameValue = formData[User.Keys.name]?.string
                emailValue = formData[User.Keys.email]?.string
                passwordValue = formData[User.Keys.password]?.string
                phoneValue = req.formData?[User.Keys.phone]?.string
                gender = req.formData?[User.Keys.gender]?.bool
                birthday = req.formData?[User.Keys.birthday]?.string
                levelId = req.formData?[User.Keys.levelId]?.int
            }
            if let name = nameValue {
                try name.validateName()
                user.name = name
                check = true
            }
            if let email = emailValue {
                try email.validateEmailNotCompare()
                user.email = email
                check = true
            }
            if let phone = phoneValue {
                try phone.validatePhone()
                user.phone = phone
                check = true
            }
            if let gender = gender {
                user.gender = gender
                check = true
            }


            if let birthday = birthday {
                user.birthday = birthday
                check = true
            }

            if let levelId = levelId {
                user.levelId = Identifier(levelId)
                check = true
            }

            if let password = passwordValue {
                try password.validatePassword()
                let passwordBytes = password.makeBytes()
                let passwordHart = try self.drop.hash.make(passwordBytes).makeString()
                user.password = passwordHart
                check = true
            }

            guard let filebytes = req.formData?["avatar"]?.part.body,
                let imageType = req.formData?["avatar"]?.part.headers["Content-Type"] else {
                    try user.save()
                    if !check {
                        throw Abort.badRequest
                    }
                    return try user.makeJSON()
            }
            var imageName = String.randomString(length: 60)
            switch imageType {
            case "image/jpeg":
                imageName += ".jpg"
            case "image/png":
                imageName += ".png"
            default:
                throw Abort.init(.badRequest, metadata: nil, reason: "image sai dinh dang")
            }

            let upload = UploadImage(droplet: self.drop)
            if let link = try upload.post(data: Data(bytes: filebytes)) {
                user.avatarUrl = link
            }

            try user.save()
            return try user.makeJSON()
        }

        // MARK: - Favorites
//        try auth.resource(Keys.favorites, FavoriteController.self)
//
//        // MARK: - Comments
//        auth.resource(Keys.comments, CommentController(drop))
//
//        // MARK: - Natification
//        try auth.resource(Keys.notifications, NotificationController.self)
    }
}
