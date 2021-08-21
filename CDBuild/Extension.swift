//
//  Extension.swift
//  CDBuild
//
//  Created by xcbosa on 2021/8/20.
//

import Foundation

extension String {
    
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    
    subscript (bounds: CountableRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ..< end]
    }
    
    subscript (bounds: CountableClosedRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start ... end]
    }
    
    subscript (bounds: CountablePartialRangeFrom<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(endIndex, offsetBy: -1)
        return self[start ... end]
    }
    
    subscript (bounds: PartialRangeThrough<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ... end]
    }
    
    subscript (range: NSRange) -> String {
        var build = ""
        for i in range.location ..< range.location + range.length {
            build.append(self[i])
        }
        return build
    }
    
    subscript (bounds: PartialRangeUpTo<Int>) -> Substring {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[startIndex ..< end]
    }
    
    func getParentPath() -> String {
        if let index = lastIndex(of: "/") {
            var front = "", end = ""
            let iidx = Int(distance(from: startIndex, to: index))
            for i in 0..<iidx {
                front.append(self[i])
            }
            for i in iidx..<count {
                end.append(self[i])
            }
            return front
        } else {
            return "/"
        }
    }
    
}
