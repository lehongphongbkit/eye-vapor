//
//  T1Middleware.swift
//  DemoVaporPackageDescription
//
//  Created by Mai Anh Tuan on 12/6/17.
//

import HTTP
import AuthProvider

class T1Middleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        
        let response = try next.respond(to: request)
        
        response.headers["team"] = "tuan_tam_hanh_huy"
        
        return response
    }
}
