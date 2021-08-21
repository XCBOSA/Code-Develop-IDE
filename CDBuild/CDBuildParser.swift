//
//  AST.swift
//  CDBuild
//
//  Created by xcbosa on 2021/8/20.
//

import Foundation

/// 描述脚本运行时的上下文环境
class CDBuildRuntimeContext {
    fileprivate var variables = [String : CDBuildVariable]()
    let directory: String
    
    init(directory: String) {
        self.directory = directory
    }
    
    @discardableResult func set(name: String, variable: CDBuildVariable) -> CDBuildVariable {
        variables[name] = variable
        return variable
    }
    
    func get(name: String) -> CDBuildVariable {
        if let vari = variables[name] {
            return vari
        }
        let v = CDBuildVariable()
        variables[name] = v
        return v
    }
    
    func match(regex: String) throws -> [String] {
        var reg: NSRegularExpression? = nil
        if regex.trimmingCharacters(in: ["\n", "\t", " "]) != "*" {
            reg = try NSRegularExpression(pattern: regex, options: .useUnixLineSeparators)
        }
        var build = [String]()
        let enumerator = try FileManager.default.contentsOfDirectory(atPath: directory)
        for file in enumerator {
            guard let reg = reg else {
                build.append(file)
                continue
            }
            if (reg.numberOfMatches(in: file, options: .reportCompletion, range: NSRange(location: 0, length: file.count)) > 0) {
                build.append(file)
            }
        }
        return build
    }
    
    func matchFiles(regex: String) throws -> CDBuildVariable {
        let context = try match(regex: regex)
        let isDirectory = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
        let variable = CDBuildVariable()
        for it in context {
            FileManager.default.fileExists(atPath: directory + "/" + it, isDirectory: isDirectory)
            if !isDirectory.pointee.boolValue {
                variable.add(string: it)
            }
        }
        isDirectory.deallocate()
        return variable
    }
    
    func matchFolders(regex: String) throws -> CDBuildVariable {
        let context = try match(regex: regex)
        let isDirectory = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
        let variable = CDBuildVariable()
        for it in context {
            FileManager.default.fileExists(atPath: directory + "/" + it, isDirectory: isDirectory)
            if isDirectory.pointee.boolValue {
                variable.add(string: it)
            }
        }
        isDirectory.deallocate()
        return variable
    }
    
    func getFullPath(_ name: String) -> String {
        if name.hasPrefix("/") { return name }
        return directory + "/" + name
    }
    
    func getFullPath(_ variable: CDBuildVariable) -> CDBuildVariable {
        let out = CDBuildVariable()
        for it in variable.data {
            out.add(string: getFullPath(it))
        }
        return out
    }
    
    func getSuffixInfo(_ name: String) -> (String, String) {
        if let index = name.lastIndex(of: ".") {
            var front = "", end = ""
            let iidx = Int(name.distance(from: name.startIndex, to: index))
            for i in 0..<iidx {
                front.append(name[i])
            }
            for i in iidx..<name.count {
                end.append(name[i])
            }
            return (front, end)
        } else {
            return (name, "")
        }
    }
}

let VariableDefMacro: [String : (String, CDBuildRuntimeContext) throws -> CDBuildVariable] = [
    ".files" : { name, env in try env.matchFiles(regex: name) },
    ".folders" : { name, env in try env.matchFolders(regex: name) }
]

protocol CDBuildParserDelegate: NSObject {
    func print(_ str: String)
    func printWarn(_ str: String)
    func printError(_ str: String)
    func cdbuild(_ variable: CDBuildVariable) throws -> CDBuildVariable
    func callSystem(_ cmd: String) -> Int32
}

class ASTError: Error, LocalizedError {
    let msg: String
    init(_ msg: String) {
        self.msg = msg
    }
    
    var errorDescription: String? { msg }
}

/// 语法...线 （没有分支）
class CDBuildAST: NSObject {
    
    public weak var delegate: CDBuildParserDelegate?
    
    let statementTypes: [String : (CDBuildTokenizer) throws -> Statement] = [
        "@set" : SetCommand.init,
        "@cdbuild" : CDBuildCommand.init,
        "@sh" : SHCommand.init,
        "@compile" : CompileCommand.init,
        "@link" : LinkCommand.init,
        "@return" : ReturnCommand.init
    ]
    
    var statements = [Statement]()
    
    override var description: String {
        var buf = ""
        for it in statements {
            buf.append("\(it)\n")
        }
        return buf
    }
    
    /// 语法分析
    /// - Parameter tokenizer: 词法分析器
    /// - Throws: 任何语法分析异常
    public func parse(tokenizer: CDBuildTokenizer) throws {
        statements.removeAll()
        var canThrow = false
        while !tokenizer.isEOF {
            guard let ntitle = try tokenizer.nextToken() else { break }
            if ntitle.type != .token {
                throw ASTError("Unexcept top level type.")
            }
            if ntitle.value == "@failable" {
                canThrow = true
                continue
            }
            if let action = statementTypes[ntitle.value] {
                let statement = try action(tokenizer)
                statement.canThrow = canThrow
                canThrow = false
                statements.append(statement)
            } else {
                throw ASTError("Unknown top level command \(ntitle.value).")
            }
        }
    }
    
    /// 执行脚本
    /// - Parameter env: 运行环境
    /// - Throws: 运行时异常
    public func execute(_ env: CDBuildRuntimeContext) throws {
        for it in statements {
            do {
                try it.eval(env, delegate!)
            } catch {
                if it.canThrow {
                    delegate?.printWarn(error.localizedDescription)
                } else {
                    throw error
                }
            }
        }
    }
    
    // MARK: - Statements Definition
    
    class Statement {
        var canThrow = false
        func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws { }
    }
    
    class SetCommand: Statement {
        
        let name: String
        let value: CDBuildTokenizer.VariableDef
        
        init(tokenizer: CDBuildTokenizer) throws {
            guard let name = try tokenizer.nextToken().makeSure(type: .token) else { throw ASTError("@set need a token (variable write to name).") }
            value = try tokenizer.nextVariable()
            self.name = name
        }
        
        override func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws {
            env.set(name: name, variable: try value.execute(env: env))
        }
        
    }
    
    class CDBuildCommand: Statement {
        
        let inputVariable: CDBuildTokenizer.VariableDef
        let name: String
        
        init(tokenizer: CDBuildTokenizer) throws {
            inputVariable = try tokenizer.nextVariable()
            guard let name = try tokenizer.nextToken().makeSure(type: .token) else { throw ASTError("@cdbuild need a token (variable write to name).") }
            self.name = name
        }
        
        override func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws {
            env.set(name: name, variable: try delegate.cdbuild(inputVariable.execute(env: env)))
        }
        
    }
    
    class SHCommand: Statement {
        
        let cmd: String
        
        init(tokenizer: CDBuildTokenizer) throws {
            guard let cmd = try tokenizer.nextToken().makeSure(type: .shellLiterial) else { throw ASTError("@sh need sh statement.") }
            self.cmd = cmd
        }
        
        override func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws {
            var output = cmd
            for it in env.variables {
                output = output.replacingOccurrences(of: "%\(it.key)", with: it.value.commandString)
            }
            let ret = delegate.callSystem(output)
            if ret != 0 {
                throw ASTError("Shell command \(output) return non zero value \(ret).")
            }
        }
        
    }
    
    class CompileCommand: Statement {
        
        let outputVariable: String
        let inputVariable: CDBuildTokenizer.VariableDef
        
        init(tokenizer: CDBuildTokenizer) throws {
            inputVariable = try tokenizer.nextVariable()
            guard let outputVariable = try tokenizer.nextToken().makeSure(type: .token) else { throw ASTError("@compile need output argument.") }
            self.outputVariable = outputVariable
        }
        
        override func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws {
            let src = try inputVariable.execute(env: env)
            let dst = CDBuildVariable()
            for it in src.data {
                let source = env.getFullPath(it), dest = env.getSuffixInfo(source).0 + ".bc"
                // compilebc 指令是单参数指令，不需要加引号！
                if delegate.callSystem("compilebc \(source)") != 0 {
                    throw ASTError("compilebc command return non zero value.")
                }
                dst.add(string: dest)
            }
            env.set(name: outputVariable, variable: dst)
        }
        
    }
    
    class LinkCommand: Statement {
        
        let outputVariable: String
        let inputVariable: CDBuildTokenizer.VariableDef
        
        init(tokenizer: CDBuildTokenizer) throws {
            inputVariable = try tokenizer.nextVariable()
            guard let outputVariable = try tokenizer.nextToken().makeSure(type: .token) else { throw ASTError("@link need output argument.") }
            self.outputVariable = outputVariable
        }
        
        override func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws {
            let src = try inputVariable.execute(env: env)
            var build = "llvm-link "
            for it in src.data {
                let source = env.getFullPath(it)
                build.append("\"\(source)\" ")
            }
            build.append("-o \"\(env.getFullPath(outputVariable))\"")
            if delegate.callSystem(build) != 0 {
                throw ASTError("llvm-link command return non zero value.")
            }
        }
        
    }
    
    class ReturnCommand: Statement {
        
        let value: CDBuildTokenizer.VariableDef
        
        init(tokenizer: CDBuildTokenizer) throws {
            value = try tokenizer.nextVariable()
        }
        
        override func eval(_ env: CDBuildRuntimeContext, _ delegate: CDBuildParserDelegate) throws {
            try env.set(name: "@return", variable: value.execute(env: env))
        }
        
    }
    
}

