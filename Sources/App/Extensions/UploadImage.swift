//
//  UploadImage.swift
//  AdminPanel
//
//  Created by MBA0280F on 3/9/19.
//

import Foundation
import Vapor
import HTTP

class UploadImage {
    let client: ClientFactoryProtocol
    let key: String = ""

    init(droplet drop: Droplet) {
        client = drop.client
    }

    func post(data: Data) throws -> String? {
        let url = URL(string: "https://api.imgur.com/3/image/")!
        let bytes = data.makeBytes()
        let vaporHeaders: [HeaderKey: String] = [HeaderKey("Authorization"): "Client-ID 1f2f06095b5febd"]
        let result = try client.post(url.absoluteString, query: [:], vaporHeaders, Body(bytes), through: [])
        guard result.status == .ok else {
            throw Abort.badRequest
        }

        if let json = result.json,
            let dataWrap = json.wrapped["data"],
            let link = dataWrap["link"]?.string {
            return link
        }
        return nil
    }
}
