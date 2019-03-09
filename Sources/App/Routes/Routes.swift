import Vapor
import AuthProvider
import VaporAPNS
import Foundation
import MySQLProvider
import Sockets
import WebSockets

extension Droplet {
    func setupRoutes() throws {
        let v1 = grouped("v1")
        try v1.collection(UserCollection(drop: self))
        try v1.collection(TT12RouterCollection(drop: self))
//        v1.post("notification") { (request) -> ResponseRepresentable in
//            guard let json = request.json else {
//                throw Abort.badRequest
//            }
//
//            guard let userID: String = try json.get("user_id"),
//                let payLoadJson: JSON = try json.get("payload") else {
//                    throw Abort.badRequest
//            }
//            print(userID)
//
//            let payload = Payload()
//            payload.extra = payLoadJson.object!
//            let pushMessage = ApplePushMessage(topic: "com.tuanma.push", priority: .immediately, payload: payload, sandbox: true)
//            try NotificationManager.shared.send(pushMessage, to: "D2610321ABAAA4CA68EF14F1BCA84EE84CE8A92227205516CC62CC0807ECF3D8")
//
//            return ".Success"
//        }
    }
}
