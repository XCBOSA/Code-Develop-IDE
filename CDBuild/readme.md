# CDBuild - 自动化编译你的项目

### 语法
CDBuild中只有一种变量类型 - 字符串（路径）哈希表，单个字符串也是一个单元素哈希表。  
#### 注释符号  
##### ; 整行注释
需要是那一行的第一个字符，不能在语句后面跟注释，注释必须单独一行。  
```
; Commit Hello World
```
##### 可写符号和变量定义
可写符号和变量定义都是指示一个变量的语法，可写符号是在调用指令时需要使用的写出变量名，它可以被指令读取也可以被写入，任何一个连续的英文字符+数字+下划线和减号都是一个合法的可写符号，
它指示了一个已经存在或还不存在的变量。  
变量定义可以是可写符号，也可以是一段初始化文本（Literial），由于初始化文本不可被写入，写入它没有意义，所以需要做区分。  
```
; 合法的可写符号
abc
123abc
123abc_-@

; 合法的变量定义
abc (可写符号也是变量定义)
{ abc, "123" } (代表变量abc和"123"拼接而成的变量)
{ "hi.txt" .files "\\.cpp" } (代表"hi.txt"和可以匹配"//.cpp"正则表达式的所有文件拼接而成的变量)
{ .folders "*" } (代表所有文件夹)
```

##### @Command 指令
指令是CDBuild的基本操作，比如赋值、编译、连接、Shell等。不同的指令有不同的参数个数，指令不按换行、符号等分割，按照规定的参数个数读取。  
@set 可写符号 变量定义  
```
; 指定新变量 variable 为复制 abc 中的内容（新的变量和老的变量没有引用关系）
@set variable abc

; 联合变量定义的直接合并功能
@set variable {
    abc
    "abc"
}
```
@cdbuild 变量定义 可写符号  
调用其它CDBuild文件，或包含默认CDBuild文件（cdbuild）的文件夹  
```
; 调用自身目录下的 "cdbuild-prepare" 文件和此目录下的其它目录，并将结果写入 result
@cdbuild {
    "cdbuild-prepare"
    .folders "*"
} result
```
@sh 整行Shell指令  
一整行Shell指令，其中可以使用 %VAR 调用CDBuild中的 VAR 变量  
```
; 输出CDBuild中variable变量的值
; 在Shell中调用CDBuild变量时，哈希表变量会自动变为一长串字符串，其中每项均加双引号，以空格分割
@sh echo %variable
```
@compile 变量定义 可写符号  
编译所有输入的文件，输出所有编译后文件的路径，顺序：左侧源文件，右侧目标文件  
注意，只能指定左侧的源文件，不能指定右侧的目标文件  
```
@compile "hello.c" output
@compile {
    "hello.c"
    .files "\\.cpp"
}
```
@link 变量定义 变量定义  
连接所有左侧的文件到右侧的路径，需要同时指定源文件和目标文件  
```
@link {
    .files "\\.bc"
    "childModule/childout.bc"
} "output.bc"
```
@return 变量定义  
将结果返回给调用方  
```
@return {
    .files "\\.bc"
    "Success"
}
```
##### 修饰符
修饰符是用来修饰指令调用的，其本身是一个没有实际作用的指令。  
@failable @Command  
描述忽略（不中断后续指令，但输出错误内容）一个指令运行中产生的错误。错误包括：编译错误，变量初始化错误，Shell指令执行结果不为0。  
```
; link指令发生错误后不中断其它编译过程
@failable @link {
    "unknownFile.bc"
} "output.bc"
```

