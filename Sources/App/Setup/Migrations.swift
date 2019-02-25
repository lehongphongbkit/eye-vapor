//
//  Migrations.swift
//  DemoVaporPackageDescription
//
//  Created by Mai Anh Tuan on 11/28/17.
//

import Vapor
import Foundation
import MySQLProvider

struct AddPostEntries: Preparation {
    static func prepare(_ database: Database) throws {
//        try database.modify(Post.self, closure: { modifier in
//            modifier.string("owner", optional: true)
//        })
    }
    
    static func revert(_ database: Database) throws {
        try database.revertBatch([AddPostEntries.self])
    }
}
