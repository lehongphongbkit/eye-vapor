//
//  StringExtension.swift
//  App
//
//  Created by Mai Anh Tuan on 1/2/18.
//

import Foundation

extension String {
    static func randomString(length: Int) -> String {
        
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        var randomString = ""
        
        for _ in 0 ..< length {
            #if os(Linux)
                do {
                    let rand = try Int(Glibc.random() % 62)

                    let nextChar = letters[rand]
                    randomString += "\(nextChar)"
                } catch {
                }
            #else
                let len = UInt32(letters.count)
                let rand = Int(arc4random() % len)
                let nextChar = Array(letters)[rand]
                randomString += String(nextChar)
            #endif

        }
        return randomString
    }
    
    static func getCurrentTime() -> String {
        
        let date = Date()
        let calender = Calendar.current
        let components = calender.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
        
        guard let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second else { return "" }
        
        return "\(year)-\(month)-\(day) \(hour):\(minute):\(second)"
    }
}
