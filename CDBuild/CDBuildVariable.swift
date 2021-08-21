//
//  Variable.swift
//  CDBuild
//
//  Created by xcbosa on 2021/8/20.
//

import Foundation

/// 描述一个运行时变量
class CDBuildVariable {
    
    var data = Set<String>()
    
    public init() { }
    
    public init(fromVariableLiterial variables: [CDBuildVariable]) {
        add(variables: variables)
    }
    
    public init(fromStringLiterial string: String) {
        data.insert(string)
    }
    
    public func add(string: String) {
        if !data.contains(string) {
            data.insert(string)
        }
    }
    
    public func add(variables: [CDBuildVariable]) {
        for it in variables { add(variable: it) }
    }
    
    public func add(variable: CDBuildVariable) {
        for dat in variable.data {
            if !data.contains(dat) {
                data.insert(dat)
            }
        }
    }
    
    public func remove(regex: String) {
        guard let reg = try? NSRegularExpression(pattern: regex, options: .useUnixLineSeparators) else { return }
        for it in data {
            if reg.numberOfMatches(in: it, options: .reportCompletion, range: NSRange(location: 0, length: it.count)) > 0 {
                data.remove(it)
            }
        }
    }
    
    public var firstString: String { data.first ?? "" }
    
    public var commandString: String {
        var build = "", id = 0
        for it in data {
            build.append("\"")
            build.append(it)
            build.append("\"")
            id += 1
            if id < data.count {
                build.append(" ")
            }
        }
        return build
    }
    
}
