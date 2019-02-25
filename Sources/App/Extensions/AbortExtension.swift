//
//  AbortExtension.swift
//  DemoVapor
//
//  Created by Hanh Pham N. on 1/17/18.
//

import Foundation
import Vapor
import HTTP

extension Abort {
    static var validUser: Abort {
        return Abort(.badRequest, reason: "Please input all obligatory fields: name, password, email", identifier: "BadRequest")
    }
    
    static var validEmail: Abort {
        return Abort(.badRequest, reason: "Email incorrect format", identifier: "BadRequest")
    }
    
    static var validPhone: Abort {
        return Abort(.badRequest, reason: "Phone incorrect format", identifier: "BadRequest")
    }
    
    static var validPassword: Abort {
        return Abort(.badRequest, reason: "Password incorrect format", identifier: "BadRequest")
    }
    
    static var validName: Abort {
        return Abort(.badRequest, reason: "Name incorrect format", identifier: "BadRequest")
    }
    
    static var promotionNotFound: Abort {
        return Abort(.notFound, reason: "Promotion not found", identifier: "NotFound")
    }
    
    static var promotionAlreadyExits: Abort {
        return Abort(.conflict, reason: "Promotion already exits", identifier: "Conflict")
    }
    
    static var authenTokenInCorrect: Abort {
        return Abort(.badRequest, reason: "Authentoken incorrect", identifier: "BadRequest")
    }
    
    static var notPermission: Abort {
        return Abort(.badRequest, reason: "You not permission", identifier: "NotPermission")
    }
    
    static var contentNotFound: Abort {
        return Abort(.notFound, reason: "Content not found", identifier: "notFound")
    }
}
