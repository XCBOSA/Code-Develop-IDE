//
//  Tokenizer.swift
//  CDBuild
//
//  Created by xcbosa on 2021/8/20.
//

import Foundation

// MARK: - Extension of optional

extension Optional where Wrapped == CDBuildTokenizer.Token {
    
    func makeSure(type: CDBuildTokenizer.Token.`Type`) -> String? {
        if self == .none { return nil }
        return self!.type == type ? self!.value : nil
    }
    
}

// MARK: - A tiny tokenizer for CDBuild

/// 简易词法分析器
class CDBuildTokenizer {
    
    // MARK: - Structure Definition
    
    /// 描述一个Token
    class Token: NSObject {
        let type: Type
        let value: String
        
        init(type: Type, value: String) {
            self.type = type
            self.value = value
        }
        
        enum `Type` {
            case symbol
            case stringLiterial
            case token
            case shellLiterial
        }
        
        func makeSure(type: Type) throws -> String {
            if type != self.type { throw TokenizeError("Token type error.") }
            return value
        }
        
        override var description: String { value }
    }
    
    /// 变量定义，描述一个变量运行时数据来源，是未初始化的变量模型
    class VariableDef: NSObject {
        let type: Type
        let name: String?
        let string: String?
        let commands: [(String, String)]?
        
        init(withName name: String) {
            self.name = name
            self.type = .name
            self.commands = nil
            self.string = nil
        }
        
        init(withLiterial literial: [(String, String)]) {
            self.name = nil
            self.type = .literial
            self.commands = literial
            self.string = nil
        }
        
        init(withStringLiterial literial: String) {
            self.name = nil
            self.type = .string
            self.commands = nil
            self.string = literial
        }
        
        enum `Type` {
            case name
            case literial
            case string
        }
        
        
        /// 执行初始化，按照变量模型填充数据
        /// - Parameter env: 脚本上下文环境
        /// - Throws: 无法填充数据：Macro 未定义等
        /// - Returns: 初始化的变量
        func execute(env: CDBuildRuntimeContext) throws -> CDBuildVariable {
            switch type {
            case .name:
                return env.get(name: name!)
            case .string:
                return CDBuildVariable(fromStringLiterial: string!)
            case .literial:
                let vari = CDBuildVariable()
                for cmd in commands! {
                    if cmd.0 == "name" {
                        vari.add(variable: env.get(name: cmd.1))
                    } else if let act = VariableDefMacro[cmd.0] {
                        vari.add(variable: try act(cmd.1, env))
                    } else {
                        throw TokenizeError("Undefined macro \(cmd.0)")
                    }
                }
                return vari
            }
        }
    }
    
    // MARK: - Tokenizer
    
    let EOF = Character("\0")
    let tokenCharacters: Set<Character>
    let spaceCharacters: Set<Character>
    var code: [Character]
    var ptr = 0
    
    init(code: String) {
        var build = ""
        code.enumerateLines(invoking: {
            str, _ in
            let t = str.trimmingCharacters(in: ["\t", " "])
            if t.count == 0 { return }
            if t.first == ";" { return }
            build.append(t)
            build.append("\n")
        })
        self.code = [Character](build)
        self.tokenCharacters = Set<Character>([Character]("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890@-_."))
        self.spaceCharacters = Set<Character>([Character](" \t\n"))
    }
    
    @inlinable func isToken(ch: Character) -> Bool { tokenCharacters.contains(ch) }
    @inlinable func isSpace(ch: Character) -> Bool { spaceCharacters.contains(ch) }
    @inlinable func isStringLiterial(ch: Character) -> Bool { ch == "\"" }
    @inlinable var isEOF: Bool { ptr < 0 || ptr >= code.count }
    
    @discardableResult func next() -> Character {
        let v = peek()
        ptr += 1
        return v
    }
    
    @discardableResult func next(until: Set<Character>) -> String {
        var v = EOF, build = ""
        while true {
            v = next()
            if v == EOF { break }
            if !until.contains(v) { ptr -= 1; break }
            build.append(v)
        }
        return build
    }
    
    @discardableResult func next(to: Set<Character>) -> String {
        var v = EOF, build = ""
        while true {
            v = next()
            if v == EOF { break }
            if to.contains(v) { ptr -= 1; break }
            build.append(v)
        }
        return build
    }
    
    func peek() -> Character {
        if isEOF { return EOF }
        return code[ptr]
    }
    
    func skipSpace() {
        while true {
            let ch = next()
            if !isSpace(ch: ch) {
                ptr -= 1
                break
            }
        }
    }
    
    class TokenizeError: Error, LocalizedError {
        let msg: String
        init(_ msg: String) {
            self.msg = msg
        }
        
        var errorDescription: String? { msg }
    }
    
    var nextShell: Token?
    
    /// 从词法分析器中读取下一个Token
    /// - Throws: 当第2-n次EOF时抛出异常
    /// - Returns: Token (当第一次EOF时返回nil)
    func nextToken() throws -> Token? {
        if let ns = nextShell {
            nextShell = nil
            return ns
        }
        skipSpace()
        if isEOF { return nil }
        if isToken(ch: peek()) {
            let title = next(until: tokenCharacters)
            if title == "@sh" {
                skipSpace()
                nextShell = Token(type: .shellLiterial, value: next(to: Set<Character>([Character]("\n"))))
                return Token(type: .token, value: "@sh")
            } else {
                return Token(type: .token, value: title)
            }
        } else if peek() == "\"" {
            next()
            var build = ""
            while !isEOF {
                if peek() == "\\" {
                    next()
                    let v = next()
                    if v == EOF {
                        throw TokenizeError("String literial not ended.")
                    }
                    build.append(v)
                } else if peek() == "\"" {
                    next()
                    break
                } else {
                    build.append(next())
                }
            }
            return Token(type: .stringLiterial, value: build)
        } else {
            return Token(type: .symbol, value: next().description)
        }
    }
    
    /// 从词法分析器中读取下一个变量定义
    /// - Throws: 任何异常
    /// - Returns: 变量定义
    func nextVariable() throws -> VariableDef {
        skipSpace()
        if peek() == "{" {
            next()
            var commands = [(String, String)]()
            while true {
                guard let first = try nextToken() else {
                    throw TokenizeError("VariableDef literial not ended.")
                }
                var breakWhile = false
                switch first.type {
                case .shellLiterial:
                    throw TokenizeError("VariableDef literial can not contain shell literial.")
                case .stringLiterial:
                    commands.append(("string", first.value))
                    break
                case .symbol:
                    if first.value == "}" {
                        breakWhile = true
                        break
                    } else {
                        throw TokenizeError("VariableDef literial not ended.")
                    }
                case .token:
                    if first.value.first == "." {
                        guard let then = try nextToken() else {
                            throw TokenizeError("VariableDef literial: Inline Macro literial: not ended.")
                        }
                        if then.type != .stringLiterial {
                            throw TokenizeError("VariableDef literial: Inline Macro literial: can not contain macro call in a macro call.")
                        }
                        if VariableDefMacro[first.value] == nil {
                            throw TokenizeError("VariableDef literial: Inline Macro literial: macro \(first.value) not founded.")
                        }
                        commands.append((first.value, then.value))
                    } else {
                        commands.append(("name", first.value))
                    }
                }
                if breakWhile { break }
            }
            return VariableDef(withLiterial: commands)
        }
        else if isToken(ch: peek()) {
            if let tok = try nextToken() {
                return VariableDef(withName: tok.value)
            } else {
                throw TokenizeError("VariableDef not ended.")
            }
        }
        else if isStringLiterial(ch: peek()) {
            if let tok = try nextToken(), tok.type == .stringLiterial {
                return VariableDef(withStringLiterial: tok.value)
            } else {
                throw TokenizeError("VariableDef not ended.")
            }
        }
        else {
            throw TokenizeError("Expected VariableDef, but got \(try nextToken()?.value ?? "EOF")")
        }
    }
    
}
