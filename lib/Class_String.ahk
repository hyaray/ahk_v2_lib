;只针对字符串和数字可以定义基类(只能定义其中1个)
; https://www.autohotkey.com/boards/viewtopic.php?f=83
;NOTE 字符串包含数字

defprop := object.DefineProp.bind(string.prototype)
proto := _String.prototype
for k in proto.OwnProps() {
    if (k != "__Class")
        defprop(k, proto.GetOwnPropDesc(k))
}

class _String {
    static fileSZM := "d:\TC\hy\Rime\opencc\jiayin.txt"
    static fileTS := "d:\TC\hy\Rime\opencc\backup\TSCharacters.txt" ;来源于 opencc，稍微调整
    static regNum := "^-?\d+(\.\d+)?$"
    static regIP := "^(25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d?)(\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d?)){3}$"
    static regSfz := "^\d{17}[\dXx]$" ;身份证
    static regSheng := "浙江|上海|北京|天津|重庆|黑龙江|吉林|辽宁|内蒙古|河北|新疆|甘肃|青海|陕西|宁夏|河南|山东|山西|安徽|湖北|湖南|江苏|四川|贵州|云南|广西|西藏|江西|广东|福建|台湾|海南|香港|澳门"
    static regMAC := "^(\w{2}(\W\w{2}){5}|\w{4}(-\w{4}){2})$"
    ;static regChepai := "^[浙沪京津渝黑吉辽蒙冀新甘青陕宁豫鲁晋皖鄂湘苏川黔滇桂藏赣粤闽台琼港澳][A-Z]\w{5,6}$"
    ;文件类型
    static regImage := "i)^(bmp|jpe|jpeg|jpg|png|gif|ico|psd|tif|tiff)$"
    ;   编程源代码
    static regCode := "i)^(ah[k1]|js|sh|vim|bas|html?|wxml|css|wxss|lua|hh[cpk])$"
    static regText := "i)^(ah[k1]|js|sh|vim|bas|html?|wxml|css|wxss|lua|hh[cpk]|md|yaml|log|csv|json|txt|ini)$"
    static regAudeo := "i)^(wav|mp3|m4a|wma)$"
    static regVideo := "i)^(mp4|wmv|mkv|m4a|m4s|rm(vb)?|flv|mpeg|avi)$"
    static regZip := "i)^(7z|zip|rar|iso|img|gz|cab|arj|lzh|ace|tar|GZip|uue|bz2)$"

    __item[i] {
        get => substr(this, i, 1)
    }

    __enum(n) {
        str := this
        _i := 0
        l := strlen(str)
        if (n == 1)
            return (&c) => (_i<l ? (c:=substr(str,++_i,1)) : false)
        else if (n == 2)
            return (&i, &c) => (_i<l ? (c:=substr(str,i:=++_i,1)) : false)
    }

 ;字符串长度（宽字符算2）
    lenByte() => strlen(RegExReplace(this, "[^\x00-\xff]", 11))

    reverse() { ;字符串反转
        dllcall("msvcrt\_wcsrev", "str",str:=this, "cdecl")
        return str
    }

    length => strlen(this)
    repeat(n, char:="") => rtrim(StrReplace(format(format("{:{1}}",n),""), " ", this . char), char)
    repeatArr(n, index:=unset) {
        if (isset(index)) { ;当序号
            arr := [this]
            loop(n-1)
                arr.push(this.add1(index*A_Index))
        } else {
        arr := []
            loop(n)
                arr.push(this)
        }
        return arr
    }

    left(n) => substr(this, 1, n)
    right(n) => substr(this, -n)
    split(p*) => StrSplit(this, p*)

    ;路径相关
    fn() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp, &fn)
        return fn
    }
    dn() { ;文件夹名
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        if (DirExist(fp)) { ;已是目录路径
            SplitPath(fp, &dn)
        } else {
            SplitPath(fp,, &dir)
            SplitPath(dir, &dn)
        }
        return dn
    }
    dir() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,, &dir)
        return dir
    }
    ext(toLower:=false) {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        if instr(fp, ".")
            SplitPath(fp,,, &ext)
        else
            ext := this
        return toLower ? StrLower(ext) : ext
    }
    fnn() { ;不带扩展名的文件名
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,,,, &fnn)
        return fnn
    }
    drv() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,,,,, &drv)
        return drv
    }
    dirName() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,, &dir)
        SplitPath(dir, &dirName)
        return dirName
    }
    dirRep(dirOld, dirNew) => dirNew . substr(this, strlen(dirOld)+1)
    extRep(extNew:="") => (extNew=="") ? RegExReplace(this, "\.\w+$") : RegExReplace(this, "\.\K\w+$", extNew)
    fnRep(fn) {
        SplitPath(this,, &dir)
        return format("{1}\{2}", dir,fn)
    }
    fnnRep(noExtNew) {
        SplitPath(this,, &dir, &ext)
        return format("{1}\{2}.{3}", dir,noExtNew,ext)
    }
    ;fnn64名称再替换空格为_
    fnn64(dealSpace:=false) { ;去除_x64.exe内容的名称(比如abc_x64.exe转成abc)
        res := RegExReplace(this, "i)_?(x?(64))?(\.\w+)?$")
        if (dealSpace)
            res := StrReplace(res, A_Space, "_")
        return res
    }

    fn2fp(dir:="") {
        (dir == "") && dir := A_Desktop
        return format("{1}\{2}",dir,this)
    }
    fnn2fp(ext:="", dir:="") {
        (dir == "") && dir := A_Desktop
        return (ext=="") ? format("{1}\{2}",dir,this) : format("{1}\{2}.{3}",dir,this,ext)
    }
    fnn2fn(ext:="") {
        return (ext=="") ? this : format("{1}.{2}",this,ext)
    }
    dir2files(sFile:="*", opt:="RF", hasExt:=false) {
        dir := this
        arr := []
        l := strlen(dir)
        loop files, format("{1}\{2}", dir,sFile), opt {
            if (A_LoopFileAttrib ~= "[HS]")
                continue
            fpp := substr(A_LoopFileFullPath, l+2)
            if (!hasExt)
                fpp := RegExReplace(fpp, "\.\w+$")
            arr.push(fpp)
        }
        return arr
    }

    ;会先删除文件/文件夹(p1)
    ;this为实体所在路径
    ;mklink /j "c:\Users\Administrator\AppData\local\Chromium\User Data\" "s\User Data"
    ;判断文件是否是 mklink 用 _TC._info(fp, 2) == ".symlink"
    ;NOTE mklink的文件和文件夹，打包的时候，zip 都会打包原始文件，7z则会忽略文件
    mklink(p1) {
        p0 := this
        if (!FileExist(p0))
            return
        if (DirExist(p1)) { ;文件夹
            try
                DirDelete(p1, true)
            catch
                msgbox("删除文件夹出错`n" . p1)
        } else if (FileExist(p1)) { ;文件
            try
                FileDelete(p1)
            catch
                msgbox("删除文件出错`n" . p1)
            ;保证有文件夹
            dir := p1.dir()
            if (!DirExist(dir))
                DirCreate(dir)
        }
        RunWait(format('{1} /c mklink{2} "{3}" "{4}"',A_ComSpec,DirExist(p0)?" /j":"",p1,p0),, "hide")
    }

    ;删除文件名前面的序号
    noIndex() => RegExReplace(this, "^\d{1,2}([.、]\s*)?")

    noHotkey(reg:="\(&.\)") => trim(RegExReplace(this, reg)) ;删除菜单的(&A)字符串

    ;在arr里的第1个序号
    index(arr) {
        for k, v in arr {
            if (v = this)
                return k
        }
        return false
    }

    upper() => StrUpper(this)
    lower() => StrLower(this)
    capitalize() => StrTitle(this)

    trim() { ;删除头尾的大小空格、tab和换行符，以及重复的大小空格和tab ;全角空格unicode码为\u3000，用正则表示为\x{3000}
        return trim(this, "　`t`r`n ")
        ; return RegExReplace(str, "[[:blank:]\x{3000}]+", A_Space) ;替换重复空格
    }

    count(str, caseSense:=0) {
        StrReplace(this, str,, caseSense, &cnt)
        return cnt
    }

    json() => json.parse(this)

    ;hyf_GuiMsgbox(".三.四".chengyu())
    ;NOTE 包含多个字 (?=.*高)(?=.*山)
    chengyu() {
        str := StrReplace(this, "。", ".")
        if (instr(str, "|")) { ;需要同时包含
            reg := ""
            loop parse, str, "|"
                reg .= format("(?=.*{1})", A_LoopField)
        } else if (strlen(str)) < 4 {
            reg := format(".*{1}.*", str)
        } else {
            reg := format("^{1}$", str)
        }
        arr := json.parse(FileRead("d:\BB\lib\成语.json", "utf-8"))
        objRes := map()
        objRes.Default := []
        arrRes := []
        for obj in arr {
            cy := obj["word"]
            if (cy ~= reg)
                arrRes.push(cy)
        }
        return arrRes
    }

    ;返回Url，并对有没有复制到内容做判断
    getUrl() {
        str := trim(this)
        loop parse, str, " `r`n`t￥，。" { ;￥是淘宝分享分隔符
            if (A_LoopField ~= "\w+\.\w+") { ;含有基本网址格式
                if (RegExMatch(A_LoopField, "(https?:|www\.)\S+", &m))
                    return m[0]
                ;else if !(substr(A_LoopField, 1, 1) ~= "[\x00-\xFF]") ;非ord字符开头如：【访问】www.baidu.com
                ;RegExMatch(A_LoopField, "https?:.+", &m)
                else
                    url := A_LoopField
                if (url.isUrl())
                    return url
                else
                    return ""
            }
        }
        return ""
    }

    ;ip地址生成，比如16.1转成 192.168.1.1
    ipCreate(_ip:="192.168.1.1") {
        str := this
        arr := StrSplit(str, ".")
        arrBase := StrSplit(_ip, ".")
        loop(arr.length)
            arrBase[-A_Index] := arr[-A_Index]
        return ".".join(arrBase)
    }

    ;比如 192.168.1.2 取前 n个ip，并带后面的.
    ipPart(n:=4) {
        ip := this
        if (ip == "")
            ip := "192.168.1.1"
        if (n == 4)
            return ip
        arr := StrSplit(ip, ".")
        res := ""
        loop(n)
            res .= arr[A_Index] . "."
        return res
    }

    ;猜测分隔符号
    guessChar(reg:="\w", sCharDelete:=" ") {
        str := trim(this, "`r`n")
        str := RegExReplace(str, reg)
        if ((str == ""))
            return ""
        obj := map()
        loop parse, str
            obj[A_LoopField] := 1
        ;有多个结果，则不认为空格为符号
        while (obj.count > 1 && sCharDelete!="") {
            if (sCharDelete.length)
                break
            loop parse, sCharDelete {
                if (obj.has(A_LoopField)) {
                    obj.delete(A_LoopField)
                    break
                }
            }
        }
        if (obj.count == 1) {
            return substr(str,1,1)
        } else { ;有多个符号
            res := ""
            for k, _ in obj
                res .= k
            return res
        }
    }

    ;处理不可见字符
    toShow() {
        str := this
        res := ""
        loop parse, str {
            switch A_LoopField {
            case " ":
                res .= "{space}"
            case "`t":
                res .= "\t"
            case "`r":
                res .= "\r"
            case "`n":
                res .= "\n"
            default:
                res .= A_LoopField
            }
        }
        ;msgbox(res . "`n" . ord(str))
        return res
    }

    toUse() {
        switch this {
            case "\t": return A_Tab
            case "\n": return "`n"
            default: return this
        }
    }

    ;Excel列 或 ABCD 转数字
    ;"XAR.toNum() ;16268
    toNum(numA:=unset) {
        key := this
        if (!isset(numA)) {
            res := 0
            loop parse, StrUpper(key)
                res := res * 26 + ord(A_LoopField)-64
            return res
        } else {
            if (key ~= "\d")
                return integer(key)
            key := StrUpper(key)
            return ord(key) - 65 + numA
        }
    }

    toIframe() => format('<iframe src="{1}"></iframe>', this)

    ;每个字符转成ASCII
    ;fmt会进制数
    toAsc(fmt:=10) {
        arr := []
        switch fmt {
            case 10:
                loop parse, this
                    arr.push(ord(A_LoopField))
            case 16:
                loop parse, this
                    arr.push(format("0x{:04X}", ord(A_LoopField)))
            default:
        }
        return arr
    }

    ;按行
    toArr(charLine:="", arrIdx:="", funLineFilter:=unset) {
        if (!isset(funLineFilter))
            funLineFilter := (p*)=>1
        arr := []
        loop parse, rtrim(this,"`r`n"), "`n", "`r" {
            if (charLine != "") {
                arrLine := StrSplit(A_LoopField, charLine)
                if (funLineFilter(arrLine)) {
                    if (isobject(arrIdx)) { ;arrLine进一步提取
                        arrTmp := []
                        for i in arrIdx
                            arrTmp.push(arrLine[i])
                        arr.push(arrTmp)
                    } else {
                        arr.push(arrLine)
                    }
                }
            } else {
                arr.push(A_LoopField)
            }
        }
        return arr
    }

    ;返回数字的列表
    toArrNum() {
        str := trim(this)
        nums := str.grem("\d+(\.\d+)?")
        arr := []
        for v in nums {
            if instr(v[0], ".")
                arr.push(float(v[0]))
            else
                arr.push(integer(v[0]))
        }
        return arr
    }

    ;s := "(1+2)*3a`n(1-2.1)*3"
    ;比如每行提取所有的数字，返回二维数组
    toArrEx(reg:="\d+(?:\.\d+)?") {
        arr2 := []
        loop parse, this, "`n", "`r" {
            arr2.push([])
            for v in A_LoopField.grem(reg)
                arr2[-1].push(v[0])
        }
        return arr2
    }

    ;按行转成obj
    ;   charLine为空：key为 A_LoopField，值为个数n
    ;   charLine非空：param为是否互为key
    toMap(charLine:="", param:=true) {
        obj := map()
        if (charLine == "")
            obj.default := 0
        loop parse, rtrim(this,"`r`n"), "`n", "`r" {
            if (A_LoopField=="" && param)
                continue
            if (charLine != "") {
                if (!instr(A_LoopField, charLine))
                    continue
                arrLine := StrSplit(A_LoopField, charLine)
                obj[arrLine[1]] := arrLine[2]
                if (param)
                    obj[arrLine[2]] := arrLine[1]
            } else {
                obj[A_LoopField] += 1
            }
        }
        return obj
    }

    ;转成正则能匹配的内容
    toReg() {
        str := this
        sChar := "^$\.*+?{}|()[]"
        loop parse, sChar
            str := StrReplace(str, A_LoopField, "\" . A_LoopField)
        return str
    }

    ;如果是路径，想读取文件，用 fileread(str, "RAW")
    ;来源：strput 帮助
    toBuffer(enc:="UTF-8") {
        str := this
        buf := buffer(strput(str, enc)) ;- ((enc = "UTF-16" || enc = "cp1200") ? 2 : 1)) ;TODO 是否要减后面的内容
        strput(str, buf, enc)
        return buf
    }

    ;\转成/
    toSlash() => StrReplace(this, "\", "/")
    ;/转成\
    toBackslash() => StrReplace(this, "/", "\")
    ;\或/转成\\
    toBackslash2() => RegExReplace(this, "\/|\\", "\\")

    ;删除不符合文件名的字符
    toFn() {
        res := RegExReplace(this, '.*[\\/|<>:*"]')
        ;OutputDebug(format("i#{1} {2}:res={3}", A_LineFile,A_LineNumber,res))
        return res
    }

    ;reg文件内容 Windows Registry Editor Version 5.00
    ;转成 ahk 的 RegRead/RegWrite
    toAhkReg(isRegWrite) {
        lastIsPath := false
        res := isRegWrite ? "" : "arr := []`r`n"
        p := ""
        loop parse, trim(this,"`r`n"), "`n", "`r" {
            str := trim(A_LoopField)
            if (str == "") {
                p := ""
                continue
            }
            if (substr(str,1,5) = "[HKEY") {
                p := substr(str, 2, strlen(str)-2)
            } else if (p != "") {
                arr := StrSplit(str, "=")
                k := arr[1] == "@" ? "" : arr[1] ;NOTE @为默认值
                if (!isRegWrite) {
                    res .= (k!="") ? format('arr.push(RegRead("{1}", {2}))`r`n', p,k) : format('arr.push(RegRead("{1}"))`r`n', p)
                    continue
                }
                if (substr(arr[2],1,1) = '"') {
                    tp := "REG_SZ"
                    v := arr[2]
                } else if (arr[2] ~= '^hex:') {
                    tp := "REG_BINARY"
                    v := format('"{1}"', StrReplace(substr(arr[2], 5), ","))
                } else if (arr[2] ~= '^dword:') {
                    tp := "REG_DWORD"
                    v := format('{1}', ltrim(substr(arr[2],7), "0"))
                    if (v == "")
                        v := 0
                } else {
                    tp := "REG_DWORD"
                    v := trim(arr[2], '"')
                }
                if (ltrim(v,'"') ~= "i)^[a-z]:\\\\")
                    v := RegExReplace(v, "[^\\]\K\\")
                res .= (k!="") ? format('RegWrite({1}, "{2}", "{3}", {4})`r`n', v,tp,p,k) : format('RegWrite({1}, "{2}", "{3}")`r`n', v,tp,p)
            }
        }
        return rtrim(res, "`r`n")
    }

    ;根据 fp 批量删除文件
    deleteFiles() {
        arr := []
        loop parse, this, "`n", "`r" {
            if (FileExist(A_LoopField)) {
                try
                    FileRecycle(A_LoopField)
                catch
                    arr.push(A_LoopField)
            } else {
                arr.push(A_LoopField)
            }
        }
        return arr
    }

    ;删除每行首 cnt 个空格
    ;cnt 0=所有 -1=参考第1行
    ltrims(cnt:=0, cr:="`r`n") {
        str := this
        res := ""
        if (cnt == -1)
            cnt := format("{{1}}", str.firstIndentCount())
        else if (cnt == 0)
            cnt := "*"
        else
            cnt := format("{{1}}", cnt)
        loop parse, this, "`n", "`r"
            res .= RegExReplace(A_LoopField, format("^\s{1}", cnt)) . cr
        res := trim(res, "`r`n")
        return res
    }

    ;获取第1个行首空白字符数量
    ;tab 返回1
    ;空格 返回空格数量
    ;应用：iThoughts 复制节点转成 Excel
    ;TODO 空格+tab 会有问题
    firstIndentCount() {
        loop parse, this, "`n", "`r" {
            ;过滤空行
            if ((A_LoopField=="") || (trim(A_LoopField)==""))
                continue
            ;行首有空白字符
            if (A_LoopField ~= "^\s") {
                if (substr(A_LoopField,1,1) == A_Tab)
                    return 1
                else if (substr(A_LoopField,1,1) == A_Space)
                    return strlen(A_LoopField) - strlen(RegExReplace(A_LoopField, "^ *"))
            }
        }
    }

    ;11
    ;   21
    ;   22
    ;       31
    ;       32
    ;   23
    ;12
    ;转成
    ;[
    ;   [11,21]
    ;   [11,22,31]
    ;   [11,22,32]
    ;   [11,23]
    ;   [12]
    ;]
    ;arrA := A_Clipboard.indent2table(true)
    ;_Excel.arrayA2cell(arrA, _Excel.get().ActiveCell)
    indent2table(toArrayA:=false) {
        str := this
        cnt := str.firstIndentCount()
        arrLine := [] ;这是临时的，匹配完整一行后才会添加到arrRes
        arrRes := [] ;结果，每项为数组
        cs := 0 ;最大列号
        loop parse, str, "`n", "`r" {
            ;过滤空行
            if (trim(A_LoopField) == "")
                continue
            ;去掉右边的空白
            sLine := rtrim(A_LoopField)
            ;行首有空白字符
            if (sLine ~= "^\s") {
                ;获取等级(没空白为1)
                level := ((strlen(sLine) - strlen(ltrim(sLine))) // cnt) + 1
                ;清空左空白
                sLine := ltrim(sLine)
                ;NOTE 处理逻辑
                lenLast := arrLine.length
                if (level == lenLast + 1) ;上一行的下级
                    arrLine.push(sLine)
                else {
                    ;添加结果并记录最大列号 cs NOTE 用 clone
                    arrRes.push(arrLine.clone())
                    if (arrLine.length > cs)
                        cs := arrLine.length
                    ;设置 arrLine[level]
                    arrLine[level] := sLine
                    ;清空 arrLine[level] 及后面的内容
                    if (lenLast > level) {
                        loop(lenLast - level)
                            arrLine.pop()
                    }
                }
            } else { ;第1级
                ;添加结果并记录最大列号 cs
                if (arrLine.length) {
                    arrRes.push(arrLine.clone())
                    if (arrLine.length > cs)
                        cs := arrLine.length
                }
                ;重置 arrLine
                arrLine := [sLine]
            }
            ;hyf_msgbox(arrLine)
        }
        ;添加最后一个结果
        arrRes.push(arrLine)
        ;hyf_msgbox(arrRes)
        if (!toArrayA)
            return arrRes
        ;转成 arrayA 供Excel写入
        rs := arrRes.length
        arrA := ComObjArray(12, rs, cs)
        loop(rs) {
            r := A_Index
            for v in arrRes[r]
                arrA[r-1,A_Index-1] := v
        }
        return arrA
    }

    ; https://github.com/Chunjee/string-similarity.ahk
    ;比较字符串相似度
    similarity(str2) {
        n := 0
        obj := map()
        obj.default := 0
        loop(n1 := strlen(this)-1)
            obj[substr(this,A_Index,2)]++
        ;hyf_msgbox(obj)
        loop(n2 := strlen(str2)-1) {
            k := substr(str2,A_Index,2)
            if (obj[k] > 0) {
                obj[k]--
                n++
                ;msgbox(A_Index . "`n" . k . "`n" . n . "`n" . obj[k])
            }
            ;else
                ;hyf_msgbox(obj, A_Index . k . "`n" . obj[k])
        }
        ;hyf_msgbox(obj)
        vDSC := round((2*n)/(n1+n2), 3)
        if (!vDSC || vDSC < 0.005) { ;round to 0 if less than 0.005
            return 0
        }
        if (vDSC = 1) {
            return 1
        }
        return vDSC
    }

    ;备用(较慢)
    ;计算两个字符串相似度，返回值范围0-1
    similaritySlow(str2) {
        arr1 := StrSplit(this)
        arr2 := StrSplit(str2)
        arrSimilar:=[]
        arrSimilar[0,0]:=0
        for k, v in arr2
            arrSimilar[0,A_Index] := A_Index
        for k, v in arr1
            arrSimilar[A_Index,0] := A_Index
        ;hyf_msgbox(arrSimilar)
        cnt := 0
        loop(arr1.length) {
            cnt += 1
            loop(arr2.length) {
                tempx := arrSimilar[cnt,A_Index-1]+1
                tempy := arrSimilar[cnt-1,A_Index]+1
                tempz := (arr1[cnt] == arr2[A_Index]) ? arrSimilar[cnt-1,A_Index-1] : arrSimilar[cnt-1,A_Index-1]+1
                arrSimilar[cnt,A_Index] := min([tempx,tempy,tempz])
            }
        }
        if(arr1.length>arr2.length)
            return 1-arrSimilar[arr1.length,arr2.length]/arr1.length
        else
            return 1-arrSimilar[arr1.length,arr2.length]/arr2.length
        min(arr) {
            res := arr.pop()
            for v in arr {
                if (v < res)
                    res := v
            }
            return res
        }
    }

    ; https://www.autohotkey.com/boards/viewtopic.php?f=6&t=5538
    ; 在线方式 run(format("http://qr.liantu.com/api.php?text={1}", "abc你好".uriEncode()))
    toQRCode(fp:="") { ;生成二维码 ;此文件同目录需要quricol32.dll
        sText := this.toCmdStr()
        format("python -B d:\BB\tool\python\createQrcode.py {1}", sText).runCmdHide() ;&符会被丢失
        return
        ;方法2
        ;if (fp == "")
            ;fp := format("{1}\{2}.png", A_Temp,A_Now)
        ;sText := this.toCmdStr()
        ;dllcall(format("{1}\quricol{2}.dll\GeneratePNG", A_LineFile.dir(),A_PtrSize*8), "str",fp, "str",sText, "int",4, "int",2, "int",0)
        ;return fp
    }

    similarByArr(arr, atLeast:=0) {
        max := 0 ;用max来获取最相似的值
        for v in arr {
            nThis := this.similarity(v)
            if (nThis > max) {
                max := nThis
                res := v
            }
        }
        return (max > atLeast) ? res : ""
    }

    similarByArrV(arrV, atLeast:=0) {
        max := 0 ;用max来获取最相似的值
        loop(arrV.MaxIndex(1)) {
            r := A_Index
            loop(arrV.MaxIndex(2)) {
                nThis := this.similarity(arrV[r,A_Index])
                if (nThis > max) {
                    max := nThis
                    res := arrV[r,A_Index]
                }
            }
            ;msgbox(nThis)
        }
        return (max > atLeast) ? res : ""
    }

    ;繁体→简体
    t2s() {
        str := fileread(_String.fileTS, "utf-8")
        res := ""
        loop parse, this {
            if (ord(A_LoopField) > 0xFF) && RegExMatch(str, format("{1}\s(.)", A_LoopField), &m)
                res .= m[1]
            else
                res .= A_LoopField
        }
        return res
    }

    ;-----------------------多行-------------------------
    ;获取重复项
    getSame() => this.toMap().filter((k,v)=>v>1)
    deleteSame(hasEmpty:=false) {
        obj := map()
        obj.default := 0
        res := ""
        loop parse, rtrim(this,"`r`n"), "`n", "`r" {
            strLine := rtrim(A_LoopField)
            if (strLine == "" && !hasEmpty)
                continue
            if !obj[strLine] {
                res .= strLine . "`r`n"
                obj[strLine]++
            }
        }
        return rtrim(res, "`r`n")
    }
    ;删除重复行
    deleteSameOrderByObj(hasEmpty:=false) => "`n".join(this.toMap(hasEmpty).keys())

    ;fun(A_LoopField, A_Index)
    dealByLine(fun) {
        res := ""
        loop parse, this, "`n", "`r"
            res .= format("{1}`n", fun(A_LoopField,A_Index))
        return res
    }

    ;批量普通替换
    ;obj为 array|map
    ;obj := [
    ;   ["狐狸","懒狗"],
    ;   ["AAA","BBB"],
    ;}
    replaces(obj) {
        res := this
        if (obj is array) {
            for arrTmp in obj
                res := StrReplace(res, arrTmp*)
        } else if (obj is map) {
            for k, v in obj
                res := StrReplace(res, k, v)
        }
        return res
    }

    ;连续数字一次性处理(方便正则判断不处理的地方)
    ;比如【于贰零一七年一起住】，不替换【一起住】里的一
    ;"于贰零一七年一起住".zh2numByReg()
    ;tp 1=\a+全部替换为数字 2=指定正则
    zh2numByReg(tp:=1) {
        str := this
        if (tp == 1)
            reg := "[零一二三四五六七八九十壹贰叁肆伍陆柒捌玖]+"
        else {
            oInput := inputbox("匹配中文数字的正则用`n用\a表示中文数字",,,"\a+")
            if (oInput.result=="Cancel" || oInput.value == "")
                return str
            reg := StrReplace(oInput.value, "\a", "[零一二三四五六七八九十壹贰叁肆伍陆柒捌玖]")
        }
        startPos := 1
        if (1) { ;替换1次
            RegExMatch(str, reg, &m)
            str := RegExReplace(str, reg, m[0].zhNum2num(),, 1)
        } else {
            while RegExMatch(str, reg, &m, startPos) {
                startPos := m.pos(0)+m.len(0)
                str := RegExReplace(str, reg, m[0].zhNum2num(),, 1)
            }
        }
        return str
    }

    ;一二三全部转成123(简单替换)
    zh2num() {
        res := ""
        obj := map("零",0,"一",1,"二",2,"三",3,"四",4,"五",5,"六",6,"七",7,"八",8,"九",9
            ,"壹",1,"贰",2,"叁",3,"肆",4,"伍",5,"陆",6,"柒",7,"捌",8,"玖",9)
        loop parse, this
            res .= obj[A_LoopField]
        return res
        ;str := this
        ;for k, v in {'一':1,'二':2, '三':3, "四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"零":0}
            ;str := StrReplace(str, k, v)
        ;return str
    }

    ;中文数字转数字
    ;"一亿二千万三十一".zhNum2num()
    zhNum2num() {
        str := this
        ;o := map("零",0,"一",1,"二",2,"两",2,"三",3,"四",4,"五",5,"六",6,"七",7,"八",8,"九",9,"十",10,"百",100,"千",1000,"万",10000,"亿",100000000)
        oDw := map("十",10,"百",100,"千",1000,"万",10000,"亿",100000000)
        oNum := map("零",0,"一",1,"二",2,"两",2,"三",3,"四",4,"五",5,"六",6,"七",7,"八",8,"九",9)
        for v in ["亿","万"] {
            if (instr(str, v)) {
                arr := StrSplit(str, v)
                return %A_ThisFunc%(arr[1]) * oDw[v] + %A_ThisFunc%(arr[2])
            }
        }
        str := StrReplace(str,"零")
        res := 0
        n := 0
        loop parse, str {
            if (oNum.has(A_LoopField))
                n := oNum[A_LoopField] ;记录单位前的数字
            else if (oDw.has(A_LoopField)) {
                if (n) {
                    res += n * oDw[A_LoopField]
                    n := 0
                } else ;单位前没数字，则直接取单位值
                    res += oDw[A_LoopField]
            }
        }
        if (n) ;个位数
            res += n
        return res
    }

    ;user.forWifi(pwd)
    forWifi(pwd) => format("WIFI:T:WPA;S:{1};P:{2};;", this, pwd)

    parseVar() { ;把%var%(只匹配\w的字符串)转换成变量的值
        str := this
        reg := "(.*?)%([a-zA-Z_]\w+)%(.*)"
        startPos := 1
        loop { ;有变量
            p := RegExMatch(str, reg, &m, startPos)
            if (p) {
                varPath := EnvGet(m[2])
                if (varPath != "") {
                    startPos := m.pos(2)+ strlen(varPath) - 1
                    str := format("{1}{2}{3}{4}", substr(str,1,p-1),m[1],varPath,m[3])
                } else { ;没有变量(一般没用)
                    startPos := m.pos(2)+ strlen(m[2]) + 1
                    str := format("{1}{2}%{3}%{4}", substr(str,1,p-1),m[1],m[2],m[3])
                }
            } else
                return str
        }
    }

    ;路径转变量(TC ahk windows)
    toVar(tp) {
        str := this
        if (str == "")
            return ""
        switch tp {
            case "ahk":
                obj := map(
                    "A_ScriptDir", A_ScriptDir,
                    "A_Desktop", A_Desktop,
                    "A_MyDocuments", A_MyDocuments,
                    "A_LocalAppdata", "c:\Users\Administrator\AppData\local", ;自定义
                    "A_Temp", A_Temp,
                    "A_AppData", A_AppData,
                    "A_StartMenu", A_StartMenu,
                    "A_Programs", A_Programs,
                    "A_Startup", A_Startup,
                    "A_DesktopCommon", A_DesktopCommon,
                    "A_ProgramFiles", A_ProgramFiles,
                    "A_AppDataCommon", A_AppDataCommon,
                    "A_StartMenuCommon", A_StartMenuCommon,
                    "A_StartupCommon", A_StartupCommon,
                    "A_WinDir", A_WinDir,
                    ;"%TCDir%", _TC.dir,
                )
            case "windows":
                obj := map(
                    ;"SystemDrive","c,",
                    "%ProgramFiles%","c:\Program Files",
                    "%ProgramFiles%(x86)","c:\Program Files (x86)",
                    "%CommonProgramFiles%","c:\Program Files\Common Files",
                    "%ProgramData%","c:\ProgramData",
                    "%TEMP%","c:\Users\Administrator\AppData\local\Temp",
                    "%USERPROFILE%","c:\Users\Administrator",
                    "%VIMCONFIG%","c:\Users\Administrator/vimfiles",
                    "%LOCALAPPDATA%","c:\Users\Administrator\AppData\local",
                    "%APPDATA%","c:\Users\Administrator\AppData\Roaming",
                    "%PUBLIC%","c:\Users\Public",
                    "%SystemRoot%","c:\Windows",
                    "%windir%","c:\Windows",
                    "%ComSpec%","c:\Windows\system32\cmd.exe",
                )
            case "tc":
                obj := map(
                    "%USERPROFILE%", "c:\Users\Administrator",
                    "%$DESKTOP%", A_Desktop,
                    "%$PERSONAL%", A_MyDocuments,
                    "%$LOCAL_APPDATA%", "c:\Users\Administrator\AppData\local",
                    "%TEMP%", A_Temp,
                    "%$APPDATA%", A_AppData,
                    "%$STARTMENU%", A_StartMenu,
                    "%$PROGRAMS%", A_Programs,
                    "%$STARTUP%", A_Startup,
                    "%$COMMON_DESKTOPDIRECTORY%", A_DesktopCommon,
                    "%ProgramW6432%", "c:\Program files",
                    "%$COMMON_APPDATA%", A_AppDataCommon,
                    "%$COMMON_STARTMENU%", A_StartMenuCommon,
                    "%$COMMON_STARTUP%", A_StartupCommon,
                    "%windir%", A_WinDir,
                    "%COMMANDER_PATH%", "d:\TC",
                )
        }
        len := 0
        var := ""
        for varLoop, v in obj { ;找到最长匹配的变量var
            if (instr(str, v) && strlen(v) > len) {
                len := strlen(v)
                var := varLoop
            }
        }
        if (var != "") {
            if (tp == "ahk")
                str := format('{1} . "{2}"', var,StrReplace(str, obj[var], ""))
            else
                str := StrReplace(str, obj[var], var)
        }
        return strlen(var) ? StrReplace(str, obj[var], var) : str
    }

    toClip() {
        if (FileExist(this))
            arrFp2clip(this)
        ; https://www.autohotkey.com/boards/viewtopic.php?p=63914#p63914
        ; by Justme
        ;文件路径转成 剪切板
        arrFp2clip(arrFp, DropEffect:="copy") {
            ; arrFp - list of fully qualified file pathes separated by "`n" or "`r`n"
            ; DropEffect - preferred drop effect, either "copy", "move" or "" (empty string)
            static TCS := 2 ; size of a TCHAR
            static PreferredDropEffect := dllcall("RegisterClipboardFormat", "Str", "Preferred DropEffect")
            static DropEffects := map(1,1, 2,2, "copy",1, "move",2)
            if (!isobject(arrFp))
                arrFp := [arrFp]
            ; -------------------------------------------------------------------------------------------------------------------
            ; count files and total string length
            lenTotal := 0
            FileArray := []
            for fp in arrFp {
                if (lenThis := strlen(fp)) {
                    FileArray.push(map("Path", fp, "Len", lenThis + 1))
                    lenTotal += lenThis
                }
            }
            cnt := arrFp.length
            if !(cnt && lenTotal)
                return false
            ; -------------------------------------------------------------------------------------------------------------------
            ; add files to the clipboard
            if (dllcall("OpenClipboard", "Ptr", A_ScriptHwnd) && dllcall("EmptyClipboard")) {
                ; HDROP format ---------------------------------------------------------------------------------------------------
                ; 0x42 = GMEM_MOVEABLE (0x02) | GMEM_ZEROINIT (0x40)
                hDrop := dllcall("GlobalAlloc", "uint",0x42, "uint",20 + (lenTotal + cnt + 1) * TCS, "UPtr")
                pDrop := dllcall("GlobalLock", "Ptr",hDrop)
                offset := 20
                ;numput(offset, pDrop + 0, "uint")         ; DROPFILES.pFiles = offset of file list
                numput("uint", offset, pDrop)         ; DROPFILES.pFiles = offset of file list
                numput("uint", 1, pDrop, 16) ; DROPFILES.fWide = 0 --> ANSI, fWide = 1 --> unicode
                for objFile in FileArray
                    offset += strput(objFile["Path"], pDrop + offset, objFile["Len"]) * TCS
                dllcall("GlobalUnlock", "Ptr",hDrop)
                dllcall("SetClipboardData","uint",0x0F, "UPtr",hDrop) ; 0x0F = CF_HDROP
                ; Preferred DropEffect format ------------------------------------------------------------------------------------
                if (DropEffect := DropEffects[DropEffect]) {
                    ; Write Preferred DropEffect structure to clipboard to _switch between copy/cut operations
                    ; 0x42 = GMEM_MOVEABLE (0x02) | GMEM_ZEROINIT (0x40)
                    hMem := dllcall("GlobalAlloc", "uint",0x42, "uint",4, "UPtr")
                    pMem := dllcall("GlobalLock", "Ptr",hMem)
                    numput("uchar", DropEffect, pMem)
                    dllcall("GlobalUnlock", "Ptr",hMem)
                    dllcall("SetClipboardData", "uint",PreferredDropEffect, "Ptr", hMem)
                }
                dllcall("CloseClipboard")
                return true
            }
            return false
        }
    }

    ;转成全角
    toWidth() {
        str := this
        res := ""
        loop parse, str {
            if (A_LoopField ~= "[a-zA-Z]")
                res .= chr(ord(format("{:U}",A_LoopField))+65248)
            else
                res .= A_LoopField
        }
        return res
    }

    charChange(c) { ;全角、半角转换（非按标准unicode码，以日常使用符号切换）
        ;空格12288和32，句号12290和46，书名号左12298和60，右12299和62，引号8220、8221和34
        n := (c ~= "\d") ? c : ord(c)
        o := map(32,12288, 12288,32, 46,12290, 12290,46, 60,12298, 12298,60, 62,12299, 12299,62, 8220,34, 8221,34)
        if (k := o[n])
            return chr(k)
        else if (n < 256)
            return chr(n + 65248)
        else if (n > 65248) && (n < 65504)
            return chr(n - 65248)
        else {
            tooltip("没找到匹配的字符")
            SetTimer(tooltip, -1000)
        }
    }

    ;同Python
    ;   'xx'.join('abc') ;结果为axxbxxc
    ;   'xx'.join(["a","b","c"]) ;结果为axxbxxc
    ;   'xx'.join([["a","b"],["c","d"]], "-") ;结果为a-bxxc-d
    ;data[1]为数组，funcObj则为子数组连接符
    join(data, funcObj:="") {
        if (data is array) {
            if (!data.length)
                return ""
            if (isobject(data[1])) { ;funcObj视作小数组连接符
                res := funcObj.join(data[1])
                loop(data.length-1)
                    res .= this . funcObj.join(data[A_Index+1])
                return res
            } else {
                if (isobject(funcObj)) { ;有处理函数
                    res := funcObj(data[1])
                    loop(data.length-1)
                        res .= this . funcObj(data[A_Index+1])
                    return res
                } else {
                    res := data[1]
                    loop(data.length-1)
                        res .= this . data[A_Index+1]
                    return res
                }
            }
        } else if (data != "") {
            res := substr(data, 1, 1)
            loop parse, substr(data,2)
                res .= this . A_LoopField
            return res
        }
    }

    ;连接obj
    joinO(obj, char:=":") {
        res := ""
        for k, v in obj
            res .= k . char . v . this
        return substr(res, 1, strlen(res)-strlen(this))
    }

    ; /k在执行完命令后保留命令提示窗口，而/c则在执行完命令之后关闭提示窗口
    runCmd(op:="/c") => run(this.toCmd(op))
    runCmdHide(op:="/c") => run(this.toCmd(op),, "hide")
    runWaitCmd(op:="/c") => RunWait(this.toCmd(op))
    runWaitCmdHide(op:="/c") => RunWait(this.toCmd(op),, "hide")
    toCmd(opt:="/c") {
        ;cmd.exe /k %windir%\system32\ipconfig.exe
        return format("{1} {2} {3}", A_ComSpec,opt,this)
    }
    toCmdStr() => StrReplace(this, "&", "^&") ;命令行很多符号需要转义 https://blog.csdn.net/kucece/article/details/46716069

    ;https://www.autohotkey.com/boards/viewtopic.php?t=97921
    ;另见 Class_NTLCalc.ahk
    eval() {
        ; built in AHK functions and more of them Unary support Functions UDF (User Defined Functions)
        static Functions := [
            Abs,Ceil,Exp,Floor,Log,Ln,Max,Min,Mod,Round,Sqrt,Random,Cos,Tan,ASin,ACos,ATan,LogicalNot,BitwiseNot,UnBin
        ]
        static Constants := Map("$PI$",3.141592653589793)
        static CharE := ".0x1234567890abcdef/*+-_ˉ&^|???" ; valid chars recognized by evaluator.
        static CharM := CharE . "(#)," ; valid chars recognized in preprocess.
        local Count1, Count2, K, V
        Expr := this
        Expr := StrReplace(StrReplace(Expr,")",")",,&Count1),"(","(",,&Count2) ; check for parenthesis count and fail
        if (Count1 != Count2) ; if ')' count mismatches '('
            throw(ValueError(Abs(Count1-Count2) . (Count1>Count2 ? " open " : " close ") . "parenthesis missing" ,, -1))
        ;   PRE-PROCESS :    1) remove all white spaces and linefeeds.    2) substitute all multi-character operands with singles.
        Expr := StrReplace(StrReplace(StrReplace(StrReplace(Format("{:L}", Expr), "`r"), "`n"), "`t"), A_Space)
        Expr := StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(Expr,"//","_"),"**","ˉ"),">>>","?"),"<<","?"),">>","?")
        Expr := StrReplace(StrReplace(Expr,"~(","BitwiseNot("), "!(", "LogicalNot(")
        if(StrLen(Expr) == 0)
            throw( ValueError("Null expression",, -2) )
        if (instr(Expr, "$", 1)) {
            for K,V  in  Constants ; search/replace Constants
                Expr := StrReplace(Expr, K, V)
        }
        for K,V in Functions ; search/replace function names with index.
            Expr := StrReplace(Expr, V.Name . "(",  Format( "#{:03}(", K))
        loop Parse, Expr,, CharM ; validate characters in expression
            throw(ValueError("Invalid character in expression: '" . A_LoopField . "'",, -3))
        local End, Begin, Value
        while((End := instr(Expr, ")",1)) && (Begin := instr(Expr,"(",1, End, -1))) { ; find the immediate  '(' that precedes ')'
            Value := substr(Expr, Begin+1, End-Begin-1) ; extract value between '(' and ')'
            if(substr(Expr, Begin-4,  Begin>4) = "#") { ; 'Value' belongs to a Function, for eg. 'Abs(-2)' would  appear as '#001(-2)' and '001' is index of static Functions array.
                local F_Index, Function, Values := [], NewValue
                F_Index :=  substr(Expr, Begin-3, 3) ; extract index
                if(Functions.Has(F_Index)) ;check if index is valid
                    Function := Functions[F_Index] ;create a reference
                else
                    throw( ValueError("Invalid function: '#" . F_Index . "'",, -3) )
                loop Parse, Value, "," ; Push params for function into array.
                    Values.Push(_eval(A_LoopField, CharE)) ; _eval will take care of throwing errors.
                Try
                    NewValue := Function(Values*) ; will fail on incorrect parameter count
                Catch Error as Err ; or if an UDF throws up
                    throw(ValueError(Function.Name . "(" . Value . ") : " . Err.Message,, -4))
                Expr := StrReplace(Expr, "#" . F_Index . "(" . Value . ")", NewValue)
            } else {
                Expr := StrReplace(Expr, "(" . Value . ")", _eval(Value, CharE))
            }
        }
        return(_eval(Expr, CharE))
        _eval(Expr, CharE) {
            local NewExpr:="",  TmpExpr:="", Sym:="+", Val:=0
            if(Expr == "")
                return 0
            if(IsNumber(Expr))
                return Expr
            loop Parse, Expr,, CharE ; validate characters in expression.
                throw(ValueError("Invalid character in expression: '" . A_LoopField . "'",, -5))
            loop Parse, Expr {
                if( IsNumber(TmpExpr . A_LoopField . "0") )
                    TmpExpr .= A_LoopField
                else {
                    NewExpr .= TmpExpr . "`n" . A_LoopField . "`n"
                    TmpExpr := ""
                }
            }
            if(instr(NewExpr .= TmpExpr, "`n`n"))
                throw( ValueError("Double operand in expression",, -6) ) ;for eg '2*2' is invalid.
            loop Parse, NewExpr, "`n" {
                if (A_Index & 1 = 0 && IsNumber(A_LoopField) || A_Index & 1 == 1 && !IsNumber(A_LoopField)) {
                    throw(ValueError("Incomplete expression",, -7))         ;  for eg '2/2+' is incomplete.
                } else {
                    if (A_Index & 1 = 0) {
                        Sym := A_LoopField
                    } else {
                        switch Sym {
                            case "+":
                                val += A_LoopField
                            case "-":
                                val -= A_LoopField
                            case "*":
                                val *= A_LoopField
                            case "/":
                                val /= A_LoopField
                            case "ˉ":
                                val := val ** A_LoopField
                            case "_":
                                val := Round(val) // Round(A_LoopField)
                            case "&":
                                val := Round(Val) & Round(A_LoopField)
                            case "|":
                                val := Round(Val) | Round(A_LoopField)
                            case "^":
                                val := Round(Val) ^ Round(A_LoopField)
                            case "?":
                                val := Round(Val) >>> Round(A_LoopField)
                                ;case "?":
                                ;val := Round(Val) >> Round(A_LoopField)
                                ;case "?":
                                ;val := Round(Val) << Round(A_LoopField)
                        }
                    }
                }
            }
            return(Val)
        }
        ;      Unary support Functions
        BitwiseNot(n:=0) => ~(n)
        LogicalNot(n:=0) => !(n)
        ; UDF (User Defined Functions)
        UnBin(B) { ; v0.12 on D516
            loop Parse, B,, "01"
                throw( ValueError("Invalid binary digits") )
            local  L  :=  StrLen(B)
                , F  :=  instr(B, 1, 1, -1)
                , N  :=  2**(L-F)
            while( F  :=  instr(B, 1, 1,F, -2) )
                N  |=  2**(L-F)
            return(N)
        }
        ;oSC := ComObject("ScriptControl")
        ;oSC.Language := "VBScript" ;"JavaScript"
        ;return oSC.eval(this)
    }

    ;m[0], m.Len[0], m.pos[0]分别存储子项目的值，长度和位置
    grem(reg, startPos:=1) { ;全局正则
        str := this
        ;options := "U)^[imsxACDJOPSUX`a`n`r]+\)"
        ;reg := (RegExMatch(reg, options, &Opt) ? (instr(Opt, "O", 1) ? "" : "O") : "O)") . reg
        ms := []
        while RegExMatch(str, reg, &m, startPos) {
            startPos := m.pos(0)+m.len(0)
            ms.push(m) ;非标准数组，只能用固定方法
        }
        return ms
    }

    ;msgbox("1122aaa211".grep("(\d+)(\d{2})", (m)=>m[0]+m[2]))
    ;TODO 函数表达式定义方式：用户输入字符串
    grep(reg, funMatch, startPos:=1) {
        str := this
        while (RegExMatch(str, reg, &m, startPos)) { ; 由于每次要计算，必须一个个处理
            str := RegExReplace(str, reg, sNew:=funMatch(m),, 1, startPos)
            startPos := m.pos(0) + strlen(sNew)
        }
        return str
    }

    ;NOTE 实用，中文暂时不支持超出10
    add1(n:=1) { ;类似Excel的填充，最后一个数字+1
        if (n == 0)
            return this
        str := this
        if (str ~= "\d") { ;有数字
            RegExMatch(this, "^(.*?)(\d+)(\D*)$", &m)
            return m[1] . format(format("{:0{1}s}",strlen(m[2])), m[2]+n) . m[3]
        } else if (i := (str ~= "零|一|二|三|四|五|六|七|八|九|十")) {
            arr := ["零","一","二","三","四","五","六","七","八","九","十"]
            sBefore := substr(str,1,i-1)
            sAfter := substr(str,i+1)
            idx := arr.indexOf(substr(str,i,1))
            if (!idx)
                return this
            try
                return format("{1}{2}{3}", sBefore,arr[idx+n],sAfter)
            catch
                return this
        } else {
            OutputDebug(format("i#{1} {2}:{3} add1 not matched", A_LineFile,A_LineNumber,A_ThisFunc))
            return str
        }
        ;return m[1] . (m[2]+1).zfill(strlen(m[2])) . m[3]
    }

    ;参考python
    ;左边补0
    zfill(l) => format(format("{:0{1}s}",l), this)

    ;左边补全(根据__)
    ;比如__为1000，则5变成1005，50→1050
    addLeft(__) {
        str := this
        n := strlen(__) - strlen(str)
        if (n <= 0)
            return str
        return substr(__,1,n) . str
    }

    addQuote(cSplit:="") {
        str := rtrim(this, "`r`n")
        if (instr(str, "`n")) { ;多行
            res := ""
            loop parse, str, "`n", "`r"
                res .= format('"{1}"`r`n', A_LoopField)
            return rtrim(res, "`r`n")
        } else {
            if (cSplit != "") { ;有分隔符
                res := ""
                for v in StrSplit(A_LoopField, cSplit)
                    res .= format('"{1}"{2}', v,cSplit)
                return substr(res, 1, strlen(res)-strlen(cSplit))
            } else {
                return format('"{1}"', str)
            }
        }
    }

    ;获取热键里的修饰键
    xsjOfHotkey() {
        hk := LTrim(this, "~*")
        if (instr(hk, " & "))
            return StrSplit(hk, A_Space)[1]
        obj := map("<", "L", ">","R", "^","ctrl", "+","shift", "!","alt", "#","LWin")
        c1 := substr(hk, 1, 1)
        if (c1 = "<" || c1 = ">") {
            r1 := obj[c1]
            c2 := substr(hk, 2, 1)
            if (instr("^!+", c2))
                return r1 . obj[c2]
            else if (c2 = "#")
                return r1 . "Win"
            else
                return 0
        } else if (instr("^!#+", c1))
            return obj[c1]
        return 0
    }

    wordAddQuote() => RegExReplace(this, "([a-zA-Z_]\w+)", "$1".addQuote()) ;单词增加双引号(af:day转成"af":"day")

    forJson() { ;字符串转对象(a:aa换行b:bb)转成{"a":"aa","b":"bb"}供json使用
        str1 := ""
        loop parse, this, "`n", "`r" { ;删除不带:的行
            if !(A_LoopField ~= "^[^:]+$")
                str1 .= A_LoopField . "`n"
        }
        str1 := rtrim(str1, "`n")
        str1 := str1.wordAddQuote() ;添加"
        return format("{{1}}", RegExReplace(str1,"\n",","))
    }

    getFullPath() { ;从字符串中获取路径(还原变量的值)
        if (instr(this, '"') = 1) ;如果第一个是"，则直接返回对应"中间的内容
            return StrSplit(this,'"')[2]
        return RegExReplace(this, "i)\.exe\K .*")
    }

    ;250/年*116=29000/年*3=83520元
    ;TODO 待完善
    calc() {
        char0 := "="
        reg := "-?\d+(\.\d+)?"
        regNum1 := format("^\D*\K({1})", reg)
        arrMain := StrSplit(this, char0)
        loop(arrMain.length-1) { ;最后一段不循环
            arr := StrSplit(arrMain[A_Index], "*")
            arrThis := []
            for v in arr {
                if (RegExMatch(v, reg, &m)) ;获取数字 m[0]
                    arrThis.push(m[0]) ;下一段的第一个数字
            }
            res := (arrThis.length==1 ? arrThis[1] : arrThis[1]*arrThis[2])
            arrMain[A_Index+1] := RegExReplace(arrMain[A_Index+1], regNum1, res) ;下一段的第一个数字
        }
        return char0.join(arrMain)
    }

    isFunc() => this ~= "^(ObjBindMethod|Closure|BoundFunc|Func)$" ;专门用于 type
    isZh() => (this ~= "^[\x{4E00}-\x{9FA5}]") ;是否中文
    isabs() => (this ~= "i)^[a-z]:[\\/]") ;判断字符串是否为路径格式

    ;fp是否64位程序
    is64() {
        fp := this
        SplitPath(fp,,, &ext)
        if (StrLower(ext) == "dll")
            return GetModuleBitness(fp)
        dllcall("GetBinaryType", "astr",fp, "uint*",&tp:=0)
        return (tp == 6)
        GetModuleBitness(fp) {
            if !oFile := FileOpen(fp, "r", "cp0")
                throw OSError("Can't open file")
            if !(oFile.ReadUShort() == 0x5A4D) { ;MZ
                oFile.Close()
                return 0
            }
            oFile.Pos := 0x3C
            PEoffset := oFile.ReadUInt()
            oFile.Pos := PEoffset + 4
            PE := oFile.ReadUShort()
            res := map(0x8664,64, 0x14C,32)[PE]
            oFile.Close()
            return res
        }
    }

    ; "^\w{2}(\W?\w{2}){5}$"
    ; AA-BB-CC-DD-EE-FF
    ; AA:BB:CC:DD:EE:FF
    ; AABB-CCDD-EEFF
    ; AABBCCDDEEFF
    isMAC() => (this ~= _String.regMAC)

    isIP() => (this ~= _String.regIP)
    isText() => (this.ext(1) ~= _String.regText)
    isPdf() => (this.ext(1) ~= _String.regText)
    isImage() => (this.ext(1) ~= _String.regImage) ;是否图片文件
    isAudio() => (this.ext(1) ~= _String.regAudeo)
    isVideo() => (this.ext(1) ~= _String.regVideo)

    isDoc() { ;是否文档
        ext := this.ext(1)
        return ext.isText() || ext.isPdf() || ext.isExcel() || ext.isWord() || ext.isPPT() || ext.isAudio() || ext.isVideo()
    }

    isZip() => instr(this, ".") ? (this.ext() ~= _String.regZip) : (this ~= _String.regZip) ;是否压缩包

    isExcel() {
        if (1) {
            return (this.ext(1) ~= "i)^xls")
        } else {
            SplitPath(this, &fn, &dir)
            oFloder := ComObject("Shell.application").NameSpace(dir)
            return instr(oFloder.GetDetailsOf(oFloder.ParseName(fn), 2), "Microsoft Excel")
        }
    }

    isWord() {
        if (1) {
            return (this.ext(1) ~= "i)^doc")
        } else {
            SplitPath(this, &fn, &dir)
            oFloder := ComObject("Shell.application").NameSpace(dir)
            return instr(oFloder.GetDetailsOf(oFloder.ParseName(fn), 2), "Microsoft Excel")
        }
    }

    isPPT() => (this.ext(1) ~= "i)^ppt")

    ; https://daringfireball.net/2010/07/improved_regex_for_matching_urls
    ; Thanks dperini - https://gist.github.com/dperini/729294
    isUrl() { ;是否网址
        ; Also see for comparisons: https://mathiasbynens.be/demo/url-regex
        ; Modified to be compatible with AutoHotkey. \u0000 -> \x{0000}.
        ; Force the declaration of the protocol because WinHttp requires it.
        url := StrLower(trim(this))
        if (url ~= "^(((?:ht|f)tp(?:s?))\:\/\/)") && !(url ~= "\s|，|。|,|`n")
            return true
        try
            return (url ~= "i)^(((?:ht|f)tp(?:s?))\://)?(?:[a-zA-Z0-9\.\-]+(?:\:[a-zA-Z0-9\.&amp;%\$\-]+)*)*(?:(?:25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9])\.(?:25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[0-9])|localhost|(?:[a-zA-Z0-9\-]+\.)+(?:com|edu|gov|int|mil|net|org|biz|blog|arpa|info|name|pro|aero|coop|museum|[a-zA-Z]{2}))(?:\:[0-9]+)*(?:/(?:$|[a-zA-Z0-9\.\,\?\:\'\\\+&amp;%\$#\=~_\-!@*]+))*$") ? 1 : 0 ;最后字段增加了!@*
        return url ~= "^(?i)"
            . "(?:(?:https?|ftp):\/\/)" ; protocol identifier (FORCE)
            . "(?:\S+(?::\S*)?@)?" ; user:pass BasicAuth (optional)
            . "(?:"
        ; IP address exclusion
        ; private & local networks
            . "(?!(?:10|127)(?:\.\d{1,3}){3})"
            . "(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})"
            . "(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})"
        ; IP address dotted notation octets
        ; excludes loopback network 0.0.0.0
        ; excludes reserved space >= 224.0.0.0
        ; excludes network & broadcast addresses
        ; (first & last IP address of each class)
            . "(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])"
            . "(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}"
            . "(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))"
            . "|"
        ; host & domain names, may end with dot
        ; can be replaced by a shortest alternative
        ; (?![-_])(?:[-\\w\\u00a1-\\uffff]{0,63}[^-_]\\.)+
            . "(?:(?:[a-z0-9\x{00a1}-\x{ffff}][a-z0-9\x{00a1}-\x{ffff}_-]{0,62})?[a-z0-9\x{00a1}-\x{ffff}]\.)+"
        ; TLD identifier name, may end with dot
            . "(?:[a-z\x{00a1}-\x{ffff}]{2,}\.?)"
            . ")"
            . "(?::\d{2,5})?" ; port number (optional)
            . "(?:[/?#]\S*)?$" ; resource path (optional)
    }

    ;比如 a/b 转成 https://github.com/a/b
    githubUrl(tp:="github") {
        url := this
        if !(url ~= "^http")
            url := format("https://{1}.com/{2}", tp,url)
        return url
    }
    ;比如 a/b 转成 https://github.com/a/b.git
    githubForClone(tp:="github")=> format("{1}.git", this.githubUrl(tp)) ;TODO 增加 .git 的作用
    ;比如 a/b 转成 git clone https://github.com/a/b.git --depth 1
    githubCloneCmd(tp:="github") => format("git clone {1} --depth 1", this.githubForClone()) ; --single-branch

    githubToggle() {
        url := this
        if (1)
            return StrReplace(url, "github.com", "github.com.cnpmjs.org")
        else
            return StrReplace(url, "github.com", "git.iw.mk")
    }

    /*
    http://www.a.com.cn:80/dir/aa.html?ver=1#h
    href	http://www.a.com.cn:80/dir/aa.html?ver=1#h
    protocol	http:
    origin	http://www.a.com.cn:80
    host	www.a.com.cn:80
    hostname	www.a.com.cn
    domain	a.com.cn
    main	a
    port	80
    pathname	/dir/aa.html
    pathnames	["dir","aa.html"](若有)
    search	?ver=1
    hash	#h
    */
    jsonUrl(key:="") {
        url := this
        obj := map()
        ;href (前面添加 http://，后面删除/)
        obj["href"] := rtrim(url, "/")
        if (!instr(obj["href"], "//"))
            obj["href"] := "http://" . obj["href"]
        ;protocol origin host
        arr := StrSplit(obj["href"], "/")
        obj["protocol"] := arr[1]
        obj["origin"] := StrLower(format("{1}//{2}",arr[1],arr[3]))
        obj["host"] := StrLower(arr[3])
        ; hostname 和 port
        if (instr(obj["host"], ":")) {
            arr := StrSplit(obj["host"], ":")
            obj["hostname"] := arr[1]
            obj["port"] := arr[2]
        } else {
            obj["hostname"] := obj["host"]
            obj["port"] := ""
        }
        ;获取 domain
        if (obj["hostname"] ~= "^\d+(\.\d+){3}$") {
            obj["main"] := obj["hostname"]
            obj["domain"] := obj["hostname"]
        } else {
            arr := StrSplit(obj["hostname"], ".")
            if (l := arr.length) {
                if (l == 1) { ;插件
                    obj["domain"] := obj["main"] := arr[1]
                } else if (arr[l] == "cn" && arr[l-1] ~= "^(gov|com|edu)$") { ;TODO 需完善
                    obj["main"] := arr[l-2]
                    obj["domain"] := format("{1}.{2}.{3}", obj["main"],arr[l-1],arr[l])
                } else {
                    obj["main"] := arr[l-1]
                    obj["domain"] := format("{1}.{2}", obj["main"],arr[l])
                }
            } else {
                obj["main"] := ""
                obj["domain"] := ""
            }
        }
        ;处理 origin 后面的内容
        sNow := substr(obj["href"], strlen(obj["origin"])+1)
        ;先获取末尾的 hash
        if (instr(sNow,"#")) {
            obj["hash"] :=  "#" . RegExReplace(sNow, ".*#")
            sNow := substr(sNow, 1, strlen(sNow)-strlen(obj["hash"]))
        } else
            obj["hash"] := ""
        ;再获取 search
        if (instr(sNow, "?")) {
            obj["search"] := substr(sNow, instr(sNow,"?"))
            obj["objSearch"] := map()
            for tmp in StrSplit(substr(obj["search"], 2), "&") {
                arrTmp := StrSplit(tmp, "=")
                if (arrTmp.length == 2)
                    obj["objSearch"][arrTmp[1]] := arrTmp[2]
            }
            sNow := substr(sNow, 1, strlen(sNow)-strlen(obj["search"]))
        } else {
            obj["search"] := ""
        }
        ;剩余即是 pathname
        obj["pathname"] := rtrim(sNow, "/")
        if (obj["pathname"] ~= "\S{2,}")
            obj["pathnames"] := StrSplit(ltrim(obj["pathname"],"/"), "/")
        return (strlen(key) && obj.has(key)) ? obj[key] : obj
    }

    ;删除网址多余部分
    urlClean() {
        objUrl := this.jsonUrl()
        if (objUrl["hostname"] == "www.bilibili.com") {
            if (instr(objUrl["pathname"], "/video/")) {
                ;OutputDebug(format("i#{1} {2}:bilibili-video pathname={3}", A_LineFile,A_LineNumber,objUrl["pathname"]))
                newPathname := RegExReplace(objUrl["pathname"],"^\/video\/\w+\K.*")
                newSearch := RegExReplace(objUrl["search"],"^(\?p\=\d+)?\K.*")
                ;OutputDebug(format("i#{1} {2}:new pathname={3}", A_LineFile,A_LineNumber,newPathname))
                ;OutputDebug(format("i#{1} {2}:new search={3}", A_LineFile,A_LineNumber,newSearch))
                url := format("{1}{2}{3}", objUrl["origin"], newPathname, newSearch)
                OutputDebug(format("i#{1} {2}:urlClean={3}", A_LineFile,A_LineNumber,url))
                return url
            } else {
                return objUrl["href"]
            }
        } else if (objUrl["hostname"] == "item.jd.com") {
            return objUrl["origin"] . objUrl["pathname"]
        } else
            return objUrl["href"]
    }

    /*
    ""
    ":"
    "-"
    "4"
    "aaaa-bbbb-cccc".macToggle()
    */
    macToggle(tp:="") {
        mac := RegExReplace(this, "\W")
        if !(strlen(tp))
            return mac
        if (tp == ":" || tp == "-")
            return format("{2}{1}{3}{1}{4}{1}{5}{1}{6}{1}{7}", tp,substr(mac,1,2),substr(mac,3,2),substr(mac,5,2),substr(mac,7,2),substr(mac,9,2),substr(mac,11,2))
        else if (tp == "4")
            return format("{2}{1}{3}{1}{4}", "-",substr(mac,1,4),substr(mac,5,4),substr(mac,9,4))
    }

    ;提取百度网盘网址?pwd=abcd
    ;https://pan.baidu.com/s/1s5rHZE_U5iOPmj2eyWkgUw 提取码：9mm6
    ;https://wwi.lanzoui.com/ijGuZrs2x4j 密码:fpxo
    baidupan() {
        str := trim(RegExReplace(this, "`r?`n|\x{A0}", " "))
        ;reg := "i)(https?:[\x{00}-\x{FF}]+)(?:(\s|，|。|,|\r|\n|[\x{4E00}-\x{9FA5}]).*?(\w{4})(\W|$))?"
        reg := "i)(https?:\S+)(?:(\s|，|。|,|\r|\n|[\x{4E00}-\x{9FA5}]).*?(\w{4})(\W|$))?"
        if (RegExMatch(str, reg, &m)) {
            return strlen(m[3]) ? format("{1}?pwd={2}", m[1],m[3]) : m[1] ;2022年03月28日经胡杨介绍更新格式
        } else if (RegExMatch(str, reg, &m)) {
            return format("{1}?pwd={2}", m[1],m[3])
        }
    }

    ;msgbox("\u4e2d\u4e3d".us2zh())
    us2zh() { ;unicode字符串转中文
        ;//先将字符串编码为unicode码，然后再将unicode码的数字转化为 十六进制
        ;var str = "wanshaobo";
        ;"wanshaobo".charCodeAt(i);//119 97 110 ...
        ;"wanshaobo".charCodeAt(i).toString(16);//77 61 6e 73 68 61 6f 62 6f
        s := this
        while(RegExMatch(s, "\\u(\w{4})", &m))
            s := StrReplace(s, m[0], chr(integer(format("0x{1}", m[1]))),,, 1)
        return s
    }

    ;NOTE 各种编码相互转换
    ;来源 http://www.autohotkey.com/board/topic/75390-ahk-l-unicode-uri-encode-url-encode-function/?p=480216
    ;编码知识收录 https://www.autohotkey.com/boards/viewtopic.php?p=23975#p23975
    ; https://www.bilibili.com/video/BV1gZ4y1x7p7
    ; https://docs.microsoft.com/en-us/windows/win32/intl/code-page-identifiers?redirectedfrom=MSDN
    ;enc 都用 CP* 来表示
    ;NOTE 空格和%可能要单独处理
    ;ascii 是否转换!
    encode(enc:="CP65001", charSeparate:="", toString:=true) {
        str := this
        if (enc == "base64") {
            oBuf := buffer(strlen(str), 0) ;fileread(fp, "raw")
            strput(str, oBuf,, "utf-8")
            dllcall("crypt32\CryptBinaryToString", "Ptr",oBuf, "UInt",oBuf.size, "UInt",0x40000001, "Ptr",0, "uint*",&nSize:=0)
            b64 := buffer(nSize << 1, 0)
            dllcall("crypt32\CryptBinaryToString", "Ptr",oBuf, "UInt",oBuf.size, "UInt",0x40000001, "Ptr",b64, "uint*",&nSize)
            return strget(b64)
        }
        objFix := map(
            "CP1201" , "CP1200",
        )
        bFix := objFix.has(enc)
        encFixed := bFix ? objFix[enc] : enc ;有些 enc 在 strput 有问题
        objLen := map(
            "CP65000", 3, ;同utf-7
            "CP936", 2, ;GB2312
            "CP65001", 3, ;utf-8
            "CP1200", 2, ;同 utf-16, unicode little endian
            "CP1201", 2, ;同 utf-16, unicode big endian, NOTE strput 有问题
            ;"CP12000", n, ; utf-32
            ;"CP12001", n, ; utf-32BE
        )
        len := objLen.has(encFixed) ? objLen[encFixed] : 3
        arr := []
        var := buffer(len, 0)
        loop parse, this {
            if (ord(A_LoopField) > 0xFF) { ;非 ascii 码
                ; msgbox(A_Index . "`n" . strput(A_LoopField, &var, encFixed))
                strput(A_LoopField, var, encFixed)
                sThis := ""
                loop(len)
                    sThis .= format(charSeparate . "{:02X}", numget(var, A_Index-1, "UChar"))
                ;需要调整(相反)
                if (bFix) {
                    sSave := sThis
                    l := strlen(sSave)
                    sThis := ""
                    loop(l/2)
                        sThis .= substr(sSave, l-(A_Index*2)+1, 2)
                }
                arr.push(sThis)
            } else { ;ascii 码
                code := format("{:02X}", ord(A_LoopField))
                if (enc == "CP1200") ;待完善
                    code := format("{1}{2}00", charSeparate,code)
                else if (enc == "CP1201")
                    code := format("{1}00{2}", charSeparate,code)
                else if (enc == "CP936" || enc == "CP65001") {
                    if (code == "20") { ;空格
                        if (enc == "CP65001")
                            code := "%20"
                        else if (enc == "CP936")
                            code := "+"
                    } else if (code == "25") { ;%
                        code := "%25"
                    } else if (code == "23") { ;#
                        code := "%23"
                    } else
                        code := A_LoopField
                }
                arr.push(code)
            }
        }
        if (toString) {
            res := ""
            for v in arr
                res .= v
            return res
        } else {
            return arr
        }
    }

    ;msgbox('%E5%85%B110'.decode())
    ;TODO %20(空格)或%25(%)后面再跟上中文的3个%，会有问题
    decode(enc:="utf-8") {
        uri := this
        if (enc == "base64") {
            dllcall("crypt32.dll\CryptStringToBinary", "Str",uri, "UInt",0, "UInt",0x00000001, "Ptr",0, "Uint*",&SizeOut:=0, "Ptr",0, "Ptr",0)
            dllcall("crypt32.dll\CryptStringToBinary", "Str",uri, "UInt",0, "UInt",0x00000001, "Ptr",res:=buffer(SizeOut), "Uint*",&SizeOut, "Ptr",0, "Ptr",0)
            return strget(res, "utf-8")
        }
        pos := 1
        loop {
            pos := RegExMatch(uri, "((%[[:xdigit:]]{2}){3})+", &code, pos++)
            if (pos == 0)
                break
            var := buffer(strlen(code[0]) // 3, 0)
            loop parse, ltrim(code[0], "%"), "%"
                numput("UChar", "0x" . A_LoopField, var, A_Index-1,)
            uri := StrReplace(uri, code[0], strget(var, enc))
        }
        return uri
    }

    ;字符串特殊字符转义成URL格式(来自万年书妖)
    ;TODO 2次 urlencod https://cloud.baidu.com/doc/SPEECH/s/Qk38y8lrl
    UrlEncode(enc:="UTF-8") { ;字符串特殊字符转义成URL格式(来自万年书妖)
        buff := this.toBuffer(enc)
        res := ""
        hex := "00"
        while((code:=numget(buff, A_Index-1, "UChar")) && dllcall("msvcrt\swprintf", "str",hex, "str","%%%02X", "uchar",code, "cdecl"))
            res .= hex
        return res
        ;StringReplace, str, str, `%,, A ;%为URL特殊转义符，先处理（Google对%符的搜索支持不好才删除,否则替换为%25）
        ;array := map("&","%26"," ","%20","(","%28",")","%29","'","%27",",","%3A","/","%2F","+","%2B",A_Tab,"%21","`r`n","%0A") ;`r`n必须放一起，可用记事本测试
        ;for, key, value in array  ;特殊字符url转义
        ;StringReplace, str, str, %key%, %value%, A ;此处循环，两个参数必须一样
        ;return str
    }

    ; "U9数据字典V2.0SP1"
    ; "U9%E6%95%B0%E6%8D%AE%E5%AD%97%E5%85%B8V2.0SP1"
    ; "U9%E6%95%B0%E6%8D%AE%E5%AD%97%E5%85%B8V2%2E0SP1"
    ;不转义\w，要转义见 toUrl
    ;NOTE 和 encode("CP65001","%") 的区别是空格转成%20，字母不转义
    ; v 0.3 / (w) 24.06.2008 by derRaphael / zLib-Style release
    uriEncode() {
        str := this
        if (str == "")
            return
        if (1) {
            buf := str.toBuffer()
            while (Code := NumGet(buf, A_Index-1, "UChar")) {
                if (Code >= 0x30 && Code <= 0x39 || Code >= 0x41 && Code <= 0x5A || Code >= 0x61 && Code <= 0x7A) ;0-9 A-Z a-z
                    res .= chr(code)
                else
                    res .= "%" . substr(format("{:02X}", code + 0x100), 2)
            }
            return res
        } else {
            oSC := ComObject("ScriptControl")
            oSC.Language := "JavaScript"
            return oSC.eval(format('encodeURI("{1}")', str))
        }
    }
    ;utf-8也用此方法
    uriDecode() {
        str := this
        if (1) {
            loop {
                if (RegExMatch(str, "i)(?<=%)[[:xdigit:]]{1,2}", &hex))
                    str := StrReplace(str, "%" . hex[0], chr("0x" . hex[0]))
                else
                    break
            }
            return str
        } else {
            oSC := ComObject("ScriptControl")
            oSC.Language := "JavaScript"
            return oSC.eval(format('decodeURIComponent("{1}")', this))
        }
    }

    ;单个中文和编码(不含符号)
    ; hyf_msgbox("八".getEncode("516B"))
    ;GetStringEncoding(strVar) {
    ;    return ComObj(0x200C, DllCall("UdeExport\GetStringEncoding", "Ptr",&strVar, "Ptr"), 1)
    ;}
    getEncode(code) {
        char := this
        if (strlen(char) > 1)
            char := substr(char, 1, 1)
        code := RegExReplace(code, "[^[:xdigit:]]")
        arrEnc := [
            ["CP1200","utf-16LE"],
            ["CP65001","utf-8"],
            ["CP936","GB2312"],
        ]
        arr := []
        var := buffer(3, 0)
        for aEnc in arrEnc {
            enc := aEnc[1]
            strput(char, var,, enc)
            arrIdx := []
            loop(2) { ;匹配2次应该够了
                idx := instr(code, format("{:02X}", numget(var, A_Index-1, "UChar")))
                if (!mod(idx, 2)) ;为偶数
                    continue 2
                if (!arrIdx.length)
                    arrIdx.push(idx)
                else {
                    if (idx > arrIdx[1])
                        return aEnc
                    else { ;要转换 最后数字+1
                        if (enc == "CP1200")
                            return ["CP1201","utf-16BE"]
                    }
                }
            }
        }
    }

    ;来源 超酷的音乐播放界面
    ;"HICON:" . base64ToHandleIcon()
    ;可用在 AddPicture
    ;详见帮助文件→图形用户界面→Image Handles
    base64ToHandleIcon(lenBytes:=0, W:=0, H:=0) {
        sBase64 := this
        lenBase64 := strlen(sBase64)
        if (!lenBytes) {
            StrReplace(sBase64, "=", "=",, &cnt) ;TODO 优化？
            lenBytes := ceil(lenBase64/4*3) - cnt
        }
        buf := buffer(lenBytes, 0)
        hICON := 0
        if (dllcall("Crypt32.dll\CryptStringToBinary", "ptr",strptr(sBase64), "UInt",lenBase64, "UInt",0x1 , "Ptr",buf, "uint*",lenBytes, "Int",0, "Int",0))
            hICON := dllcall("CreateIconFromResourceEx", "Ptr",buf, "UInt",lenBytes, "Int",1, "UInt","0x30000", "Int",W, "Int",H, "UInt",0, "UPtr")
        return hICON
    }

    /*
    Unicode4Ansi(&wString, sString) {
        nSize := dllcall("MultiByteToWideChar", "Uint", "932", "Uint", 0, "Uint", &sString, "int", -1, "Uint", 0, "int", 0)
        wString := buffer(nSize * 2)
        dllcall("MultiByteToWideChar", "Uint", "932", "Uint", 0, "Uint", &sString, "int", -1, "Uint", &wString, "int", nSize)
        return &wString
    }

    Ansi4Unicode(pString) {
        nSize := dllcall("WideCharToMultiByte", "UINT", "932", "Uint", 0, "Uint", pString, "int", -1, "Uint", 0, "int",  0, "Uint", 0, "Uint", 0)
        sString := buffer(nSize)
        dllcall("WideCharToMultiByte", "UINT", "932", "Uint", 0, "Uint", pString, "int", -1, "str", sString, "int", nSize, "Uint", 0, "Uint", 0)
    }

    ; s := "00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:01:02:03:04"
    ; msgbox(_Encode.base64ToBit(s))
    ;应用场景？
    base64ToBit(s) {
        Chars := "0123456789+/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        StringCaseSense("On")
        lls := (A_ListLines==0) ? "Off" : "On"
        ListLines("Off")
        loop Parse, Chars {
            i := A_Index-1
            v := (i>>5&1) . (i>>4&1) . (i>>3&1) . (i>>2&1) . (i>>1&1) . (i&1)
            s := StrReplace(s, A_LoopField, v)
        }
        ListLines(lls)
        StringCaseSense("Off")
        s := RegExReplace(s, "1[^1]*$")
        s := RegExReplace(s, "[^01]+")
        return s
    }

    ;NOTE
    ;另见 TC_Picture.um_pic_toBase64()

    hyf_splitNameAndPassword(s) { ;字符串分割用户名和密码
        s := (s = "") ? hyf_trim(A_Clipboard) : hyf_trim(s)
        RegExMatch(s, "(?<=：|:| )?[\w\.\-\=\+\~\!\@\#\$\%\^\&\*\(\)\[\]\{\}]+(?=：|:| )", &ClipboardUser)
        RegExMatch(s, "(?<=：|:| )[\w\.\-\=\+\~\!\@\#\$\%\^\&\*\(\)\[\]\{\}]+$", &ClipboardPwd)
        _Key.wait(format("获取到`n用户名：{1}`n密　码：{2}`n请点击输入框后按任意键输出账号和密码", ClipboardUser,ClipboardPwd))
        _Key.sendP(ClipboardUser, "A")
        send("{tab}")
        sleep(100)
        _Key.sendP(ClipboardPwd, "A")
        send("{enter}")
    }

    hyf_getTidyTextByFuhao(TextAll, fh:="=") { ;文本通过fh对齐
        LimitLen := 80 ;左侧超过该长度时，该行不参与对齐，该数字可自行修改
        MaxLen := 0
        hyf_trim(TextAll)
        TextAll := RegExReplace(TextAll, "m)^\s*$`r`n") ;删除空行
        TextAll := RegExReplace(TextAll, "m)^\s*|\s*$") ;删除首尾空格
        TextAll := RegExReplace(TextAll, "im)\s*" . fh . "\s*", fh) ;删除符号前后的空格★★★★★★正则
        loop parse, TextAll, "`n", "`r" { ;此语法看帮助，计算左边最大字符长度
            if !instr(A_LoopField, fh) ;忽略没有符号的行
                continue
            StrLeft := RegExReplace(A_LoopField, fh . ".*?$")
            Len := strlen(RegExReplace(StrLeft, "[^\x00-\xff]", 11)) ;本条左侧的长度
            ;Len := dllcall("MSVCRT.DLL\strlen", "astr",StrLeft) ;该方法会无故失效
            MaxLen := (Len > MaxLen && Len <= LimitLen) ? Len : MaxLen
        }
        Num_TotalTab := (MaxLen - 1) // 8 + 1
        ;开始替换左侧字符串
        loop(Num_TotalTab)
            StrTab .= A_Tab
        NewText := ""
        loop parse, TextAll, "`n", "`r" { ;`n和`r看loop的帮助
            if !instr(A_LoopField, fh) { ;没有符号
                NewText .= A_LoopField . "`n"
                continue
            }
            StrRight := RegExReplace(A_LoopField, "^.*?(?=" . fh . ".*$)")
            StrLeft := RegExReplace(A_LoopField, fh . ".*$")
            Len := strlen(RegExReplace(StrLeft, "[^\x00-\xff]", 11)) ;本条左侧的长度
            if (Len > LimitLen) {
                NewText .= A_LoopField . "`n"
                continue
            }
            Num_AddTab := Num_TotalTab - (Len // 8) ;补充tab
            NewText .= StrLeft .  substr(StrTab, 1, Num_AddTab) . StrRight . "`n"
        }
        return RTrim(NewText, "`n") ;删除最后的空行
    }

    */

    ;-----------------------------------num-----------------------------------
    b2d() { ;2进制转十进制
        sNum := this
        l := strlen(string(sNum))
        r := 0
        loop parse, sNum
            r |= A_LoopField << --l
        return r
    }

    b2h() { ;2进制转16进制
        sNum := this
        l := strlen(sNum)
        r := 0
        loop parse, sNum
            r |= A_LoopField << --l
        return format("0x{:X}", r)
    }

    ;NOTE 十进制还在 Class_Num.ahk
    d2b(r:=2) { ;十进制转2进制
        num := integer(this)
        res := ""
        while(num) {
            res := mod(num, r) . res
            num //= r
        }
        return res
    }

    ;TODO 返回数字还是字符串？
    ;如果返回数字，直接用 integer("0xa0")
    h2d() { ;16进制转十进制
        num := this
        if !(instr(num, "0x"))
            num := integer("0x" . num)
        return format("{:d}", num)
    }

    h2b() { ;16进制转二进制
        sNum := StrUpper(this)
        if (sNum ~= "i)^0x")
            sNum := substr(sNum, 3)
        obj := map(
            "0","0000",
            "1","0001",
            "2","0010",
            "3","0011",
            "4","0100",
            "5","0101",
            "6","0110",
            "7","0111",
            "8","1000",
            "9","1001",
            "A","1010",
            "B","1011",
            "C","1100",
            "D","1101",
            "E","1110",
            "F","1111",
        )
        r := ""
        loop parse, sNum
            r .= obj[A_LoopField]
        return ltrim(r, "0")
    }

    ;n1 := 3.06
    floatErr() => number(this).floatErr()

    ; arr := [
    ;     0.01,
    ;     1.0100,
    ;     2.10010,
    ;     3.19999999996,
    ; ]
    ;arrV要用这个方法 整数可用 integer() 代替
    ;NOTE 日期表示为 3.20，会影响实际数据
    delete0() {
        sNum := this
        if (sNum ~= "^-?\d+\.\d+$") {
            if (sNum ~= "\.\d{8,}$") ;小数位太多的异常
                sNum := round(sNum+0.00000001, 6)
            return rtrim(RegExReplace(sNum, "\.\d*?\K0+$"), ".")
        } else {
            return sNum
        }
    }

}

;msgbox("d:\我.txt".encode())
;s := "U9数据字典V2.0SP1"
;msgbox(s.UrlEncode() . "`n" . s.uriEncode())
;msgbox("U9%E6%95%B0%E6%8D%AE%E5%AD%97%E5%85%B8V2%2E0SP1".uriDecode())
