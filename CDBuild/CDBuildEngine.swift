//
//  CDBuildEngine.swift
//  CDBuild
//
//  Created by xcbosa on 2021/8/20.
//

import Foundation

// 修改IO实现
func doPrint(_ str: String) {
    print(str)
}

func doPrintWarn(_ str: String) {
    print("Warn \(str)")
}

func doPrintError(_ str: String) {
    print("Error \(str)")
}

func doCallSystem(_ cmd: String) -> Int32 {
    doPrint("system call \(cmd)")
    return 0
}

class CDBuildEngine: NSObject, CDBuildParserDelegate {
    
    // MARK: - CDBuildParserDelegate Implemention
    
    func callSystem(_ cmd: String) -> Int32 { doCallSystem(cmd) }
    
    func print(_ str: String) { doPrint(str) }
    
    func printWarn(_ str: String) { doPrintWarn(str) }
    
    func printError(_ str: String) { doPrintError(str) }
    
    func cdbuild(_ variable: CDBuildVariable) throws -> CDBuildVariable {
        let build = CDBuildVariable()
        for it in variable.data {
            build.add(variable: try CDBuildEngine(buildFile: runtimeContext.directory + "/" + it).runScript())
        }
        return build
    }
    
    // MARK: - CDBuildEngine
    
    let ast: CDBuildAST
    let runtimeContext: CDBuildRuntimeContext
    let buildFile: String
    
    init(buildFile: String) throws {
        doPrint("CDBuild building \(buildFile)")
        ast = CDBuildAST()
        self.buildFile = buildFile
        let isDirectory = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
        defer { isDirectory.deallocate() }
        if !FileManager.default.fileExists(atPath: buildFile, isDirectory: isDirectory) {
            throw ASTError("CDBuild can not find file or directory.")
        }
        var buildFile = buildFile
        if isDirectory.pointee.boolValue, !FileManager.default.fileExists(atPath: buildFile + "/cdbuild", isDirectory: isDirectory) {
            throw ASTError("CDBuild can not find cdbuild file in directory.")
        } else {
            if isDirectory.pointee.boolValue {
                throw ASTError("CDBuild can not find cdbuild file in directory, but cdbuild folder founded.")
            }
            buildFile += "/cdbuild"
        }
        try ast.parse(tokenizer: CDBuildTokenizer(code: String(contentsOfFile: buildFile)))
        runtimeContext = CDBuildRuntimeContext(directory: buildFile.getParentPath())
        
        super.init()
        ast.delegate = self
    }
    
    public func runScript() throws -> CDBuildVariable {
        try ast.execute(runtimeContext)
        let ret = runtimeContext.getFullPath(runtimeContext.get(name: "@return"))
        print("CDBuild \(buildFile) return with \(ret.commandString)")
        return ret
    }
    
    
}
