//
//  main.swift
//  CDBuild
//
//  Created by xcbosa on 2021/8/20.
//

import Foundation

do {
    let engine = try CDBuildEngine(buildFile: "/Users/xcbosa/Desktop/CDBuild/testproj")
    let result = try engine.runScript()
    print("CDBuild return with \(result.commandString)")
} catch {
    print(error.localizedDescription)
}
    
