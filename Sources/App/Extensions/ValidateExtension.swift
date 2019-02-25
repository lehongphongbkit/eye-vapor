//
//  ValidateExtension.swift
//  DemoVapor
//
//  Created by Hanh Pham N. on 1/17/18.
//

import Foundation
import Validation
import MySQL
import Vapor

extension String {
    
    func validateEmail() throws {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        if try !User.makeQuery().filter(User.Keys.email, self).all().isEmpty {
            throw Abort.init(.conflict, reason: "email \(self) exists")
        }
        guard self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            throw Abort.init(.badRequest, reason: "\(self) is not a email address .. ")
        }
    }
    
    func validateEmailNotCompare() throws {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        guard self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            throw Abort.init(.badRequest, reason: "\(self) is not a email address .. ")
        }
    }
    
    func validatePassword() throws {
        let pattern = "[A-Z0-9a-z]{6,16}"
        guard self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            throw Abort.init(.badRequest, reason: "\(self) is not a correct password")
        }
    }
    
    func validateName() throws {
        let pattern = "[A-Za-z ]{3,70}"
        guard self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            throw Abort.init(.badRequest, reason: "\(self) is not correct name")
        }
    }
    
    func validatePhone() throws {
        let pattern = "[0-9]{10,12}"
        guard self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            throw Abort.init(.badRequest, reason: "\(self) is not a phone number")
        }
    }
}
