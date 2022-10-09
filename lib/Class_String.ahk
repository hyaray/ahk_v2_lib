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
    static fileQP := A_LineFile . "\..\汉字拼音对照表.txt"
    static fileTS := A_LineFile . "\..\繁体简体.txt"
    static regNum := "^-?\d+(\.\d+)?$"
    static regHostname := "^[\w\-]+(\.[\w\-]+)+$"
    static regIP := "^(25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d?)(\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d?)){3}$"
    static regSfz := "^\d{17}[\dXx]$" ;身份证
    static regSheng := "浙江|上海|北京|天津|重庆|黑龙江|吉林|辽宁|内蒙古|河北|新疆|甘肃|青海|陕西|宁夏|河南|山东|山西|安徽|湖北|湖南|江苏|四川|贵州|云南|广西|西藏|江西|广东|福建|台湾|海南|香港|澳门"
    static regMAC := "^(\w{2}(\W\w{2}){5}|\w{4}(-\w{4}){2})$"
    ;static regChepai := "^[浙沪京津渝黑吉辽蒙冀新甘青陕宁豫鲁晋皖鄂湘苏川黔滇桂藏赣粤闽台琼港澳][A-Z]\w{5,6}$"
    ;文件类型
    static regImage := "i)^(bmp|jpe|jpeg|jpg|png|gif|ico|psd|tif|tiff)$"
    ;   编程源代码
    static regCode := "i)^(ah[k2]|js|vim|html?|wxml|css|wxss|lua|hh[cpk])$"
    static regText := "i)^(ah[k2]|js|vim|html?|wxml|css|wxss|lua|hh[cpk]|csv|json|txt|ini)$"
    static regAudeo := "i)^(wav|mp3|m4a|wma)$"
    static regVideo := "i)^(mp4|wmv|mkv|m4a|rm(vb)?|flv|mpeg|avi)$"
    static regZip := "i)^(7z|zip|rar|iso|img|gz|cab|jar|arj|lzh|ace|tar|GZip|uue|bz2)$"

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
    repeat(n) => StrReplace(format(format("{:{1}}",n),""), " ", this)

    left(n) => substr(this,1,n)
    right(n) => substr(this,strlen(this)-n+1)

    ;路径相关
    fn() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp, &fn)
        return fn
    }
    dir() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,, &dir)
        return dir
    }
    ext() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,,, &ext)
        return ext
    }
    noExt() {
        fp := this
        if (instr(fp, "/"))
            fp := StrReplace(fp, "/", "\")
        SplitPath(fp,,,, &noExt)
        return noExt
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
    extRep(extNew) {
        return RegExReplace(this, "\.\K\w+$", extNew)
    }

    ;在arr里的第1个序号
    index(arr) {
        for k, v in arr {
            if (v = this)
                return k
        }
        return false
    }

    upper() {
        return StrUpper(this)
    }
    lower() {
        return StrLower(this)
    }
    capitalize() {
        return StrTitle(this)
    }

    trim() { ;删除头尾的大小空格、tab和换行符，以及重复的大小空格和tab ;全角空格unicode码为\u3000，用正则表示为\x{3000}
        return trim(this, "　`t`r`n ")
        ; return RegExReplace(str, "[[:blank:]\x{3000}]+", A_Space) ;替换重复空格
    }

    count(str, caseSense:=0) {
        StrReplace(this, str, "", caseSense, &cnt)
        return cnt
    }

    json() {
        return json.parse(this)
    }

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

    ;Excel列转数字
    ;"XAR.toNum() ;16268
    toNum() {
        res := 0
        loop parse, StrUpper(this)
            res := res * 26 + ord(A_LoopField)-64
        return res
    }

    toIframe() {
        return format('<iframe src="{1}"></iframe>', this)
    }

    ;charLine为不空，则行
    toArr(charLine:="", arrIdx:="", funLineFilter:="") {
        if (!isobject(funLineFilter))
            funLineFilter := (p*)=>1
        arr := []
        loop parse, rtrim(this,"`r`n"), "`n", "`r" {
            if (charLine != "") {
                arrLine := StrSplit(A_LoopField, charLine)
                if (funLineFilter.call(arrLine)) {
                    if (isobject(arrIdx)) { ;arrLine进一步提取
                        arrTmp := []
                        for i in arrIdx
                            arrTmp.push(arrLine[i])
                        arr.push(arrTmp)
                    } else
                        arr.push(arrLine)
                }
            } else
                arr.push(A_LoopField)
        }
        return arr
    }

    ;按行转成obj，key为 A_LoopField，值为个数n
    toObj() {
        obj := map()
        obj.default := 0
        loop parse, rtrim(this,"`r`n"), "`n", "`r" {
            if (A_LoopField != "")
                obj[A_LoopField] += 1
        }
        return obj
    }

    toPipInstall(toCmd:=false, bUpdate:=false) {
        str := this
        obj := map( ;NOTE v 为数组(可能有依赖)
            "bs4", ["beautifulsoup4"],
            "cv2", ["opencv-python"],
            "magic", ["python-magic"],
            "skimage", ["scikit-image"],
            "smtplib", ["pyEmail"],
            "win32api", ["pywin32"],
            "PIL", ["Pillow"],
            "paddleocr", ["python_Levenshtein","paddleocr"],
        )
        if (obj.has(str)) {
            arr := obj[str]
        } else if (str = "Django") {
            arr := inputbox("输入Django版本")
            if (arr.result=="Cancel" || !(arr.value ~= "^\d+$"))
                arr := ["django"] ;安装最新版
            else
                arr := ["django==" . arr.value]
        } else
            arr := [str]
        if (toCmd) {
            sUpgrade := bUpdate ? "--upgrade " : ""
            for v in arr
                arr[A_Index] := format('pip install -i https://mirrors.aliyun.com/pypi/simple {1}{2}', sUpgrade,v)
        }
        return arr
    }

    ;转成正则能匹配的内容
    toReg() {
        str := this
        sChar := "\.*?+[{|()^$"
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

    ;返回数字的列表
    toArrNum() {
        str := trim(this)
        nums := str.grem("\d+(\.\d+)?")
        arr := []
        for v in nums
            arr.push(v[0])
        ;hyf_objView(arr, arr[2]-arr[1])
        return arr
    }

    ;\转成/
    toSlash() {
        return StrReplace(this, "\", "/")
    }
    ;/转成\
    toBackslash() {
        return StrReplace(this, "/", "\")
    }
    ;\或/转成\\
    toBackslash2() {
        return RegExReplace(this, "\/|\\", "\\")
    }

    toUrlLnk(fn, dir:="") {
        if (dir == "")
            dir := A_Desktop
        run(format("nircmd urlshortcut {1} {2} {3}",this,dir,fn)) ;参数分别是网址，目录和文件名
    }

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

    ;16进制rgb
    colorShow() {
        ;strRGB := substr(strRGB, 3)
        strRGB := RegExReplace(this, "^(0x|\$|#)")
        r := substr(strRGB, 1, 2)
        g := substr(strRGB, 3, 2)
        b := substr(strRGB, 5, 2)
        ;定义
        obj := map()
        obj["RGB"] := map()
        obj["RGB"]["hex"] := map()
        obj["RGB"]["hex"][1] := map()
        obj["RGB"]["十进制"] := map()
        obj["RGB"]["十进制"][1] := map()
        ;开始写入
        obj["RGB"]["hex"][1][1] := r
        obj["RGB"]["hex"][1][2] := g
        obj["RGB"]["hex"][1][3] := b
        obj["RGB"]["hex"][2] := strRGB
        obj["RGB"]["hex"][3] := "#" . strRGB
        obj["RGB"]["hex"][4] := "0x" . strRGB
        obj["RGB"]["hex"]["BGR"] := b . g . r
        obj["RGB"]["十进制"][1][1] := h2d(r)
        obj["RGB"]["十进制"][1][2] := h2d(g)
        obj["RGB"]["十进制"][1][3] := h2d(b)
        obj["RGB"]["十进制"][2] := h2d(strRGB)
        obj["RGB"]["十进制"]["BGR"] := h2d(b . g . r)
        ;strBGR := b . g . r
        return obj
        h2d(num) { ;16进制转十进制
            if (instr(num, "0x") != 1)
                num := "0x" . num
            return format("{:d}", num)
        }
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
            ;hyf_objView(arrLine)
        }
        ;添加最后一个结果
        arrRes.push(arrLine)
        ;hyf_objView(arrRes)
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
        ;hyf_objView(obj)
        loop(n2 := strlen(str2)-1) {
            k := substr(str2,A_Index,2)
            if (obj[k] > 0) {
                obj[k]--
                n++
                ;msgbox(A_Index . "`n" . k . "`n" . n . "`n" . obj[k])
            }
            ;else
                ;hyf_objView(obj, A_Index . k . "`n" . obj[k])
        }
        ;hyf_objView(obj)
        vDSC := round((2*n)/(n1+n2), 3)
        if (!vDSC || vDSC < 0.005) { ;round to 0 if less than 0.005
            return 0
        }
        if (vDSC = 1) {
            return 1
        }
        return vDSC
    }

    ;字符串
    rgb2bgr() {
        return substr(this,5,2) . substr(this,3,2) . substr(this,1,2) ;字符串FF00BB
        ; return (nColor & 0xFF) << 16 | nColor & 0x0000FF00 | nColor >> 16 ;数字 0x12345678 或 0x123456
    }

    argb2abgr() {
        return (this & 0xFF)<<16 | (this & 0xFF00) | (this & 0xFF0000)>>16 | (this & 0xFF000000) >> 24
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
        ;hyf_objView(arrSimilar)
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

    ;当前字符串和str0比较
    ;精确匹配参考 findFirstDiff
    compareByBC(str0, ext:="txt") {
        ;获取文本 str0 str1
        str0 := rtrim(str0, "`r`n")
        str1 := rtrim(this, "`r`n")
        ;生成ext文件路径 p0和p1
        fn := A_Now
        p0 := format("{1}\{2}a.{3}",A_Desktop,fn,ext)
        p1 := format("{1}\{2}b.{3}",A_Desktop,fn,ext)
        ;保存剪切板内容到临时文件
        objEncode :=  map(
            "ah1", "`n utf-8",
            "ahk", "`n utf-8",
        )
        objEncode.default := ""
        FileAppend(str0, p0, objEncode[ext])
        FileAppend(str1, p1, objEncode[ext])
        ;开始比较
        run(format('d:\TC\soft\BCompare\BCompare.exe /fv="text Compare" "{1}" "{2}"',p0,p1),,, &thisPid)
        WinWaitActive("ahk_pid " . thisPid)
        if (WinActive("ahk_class TQuickCompareDialog")) ;相同内容
            WinClose()
        else {
            tooltip("等待BCompare关闭后删除临时文件", 0, 0)
            WinWaitClose("ahk_pid " . thisPid)
            tooltip
        }
        FileDelete(p0)
        FileDelete(p1)
    }

    ;一般不要用，很傻
    findFirstDiff(str0) {
        str1 := this
        if (str0 == str1)
            return true
        l0 := strlen(str0)
        l1 := strlen(str1)
        if (l0 > l1) {
            arr := [str1, str0]
            longer := 1
        } else {
            arr := [str0, str1]
            longer := 0
        }
        loop parse, arr[2] {
            if (substr(arr[1], A_Index, 1) != A_LoopField) {
                obj := map(
                    "longer",longer,
                    "index",A_Index,
                    "char0",A_LoopField,
                    "char1",substr(arr[1], A_Index, 1)
                )
                msgbox(json.stringify(obj, 4))
            }
        }
        return 0
    }

    ;繁体→简体
    t2s() {
        str := fileread(_String.fileTS, "utf-8")
        res := ""
        loop parse, this {
            if (ord(A_LoopField) > 127) && RegExMatch(str, "(.)" . A_LoopField, &m)
                res .= m[1]
            else
                res .= A_LoopField
        }
        return res
    }

    ;通过文件名快速获取完整路径
    ;noExt.fp(ext, dir)
    noExt2fp(ext, dir:="") {
        if (dir == "")
            dir := A_Desktop
        return format("{1}\{2}.{3}",dir,this,ext)
    }
    fn2fp(dir:="") {
        if (dir == "")
            dir := A_Desktop
        return format("{1}\{2}",dir,this)
    }

    ;-----------------------多行-------------------------
    ;获取重复项
    getSame() {
        res := map()
        for k, v in this.toObj() {
            if (v > 1)
                res[k] := v
        }
        return res
    }
    deleteSame() {
        obj := map()
        obj.default := 0
        res := ""
        loop parse, rtrim(this,"`r`n"), "`n", "`r" {
            strLine := rtrim(A_LoopField)
            if (strLine == "")
                continue
            if !obj[strLine] {
                res .= strLine . "`r`n"
                obj[strLine]++
            }
        }
        return rtrim(res, "`r`n")
    }
    ;删除重复行
    deleteSameOrderByObj() {
        res := ""
        for k, _ in this.toObj()
            res .= k . "`n"
        return substr(res, 1, strlen(res)-1)
    }

    addIndex(i:=1) {
        res := ""
        loop parse, this, "`n", "`r"
            res .= format("{1}. {2}`n", string(A_Index+i-1),A_LoopField)
        return res
    }

    index1234(i:=1) {
        res := ""
        loop parse, this, "`n", "`r"
            res .= RegExReplace(A_LoopField, "^(\d+\.)?", A_Index+i-1) . "`n"
        return res
    }

    ;批量普通替换
    ;arr := [
    ;   ["狐狸","懒狗"],
    ;   ["AAA","BBB"],
    ;}
    replaces(arr) {
        res := this
        for arrTmp in arr  {
            res := StrReplace(res, arrTmp[1], arrTmp[2])
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
        zh2num(str) { ;必须全是(一|二|三|四|五|六|七|八|九|壹|贰|叁|肆|伍|陆|柒|捌|玖)，不支持 拾佰仟
            res := ""
            obj := map("零",0,"一",1,"二",2,"三",3,"四",4,"五",5,"六",6,"七",7,"八",8,"九",9,"十",10,
                "壹",1,"贰",2,"叁",3,"肆",4,"伍",5,"陆",6,"柒",7,"捌",8,"玖",9)
            loop parse, str
                res .= obj[A_LoopField]
            return res
        }
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
    forWifi(pwd) {
        return format("WIFI:T:WPA;S:{1};P:{2};;", this, pwd)
    }

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
        if (tp = "ahk") {
            obj := map(
                "A_Desktop", A_Desktop,
                "A_MyDocuments", A_MyDocuments,
                "A_LOCALAPPDATA", "c:\Users\Administrator\AppData\local", ;自定义
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
        } else if (tp = "windows") {
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
        } else if (tp = "tc") {
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
    ;   'xx'.join('abc') 结果为axxbxxc
    ;   'xx'.join(["a","b","c"]) 结果为axxbxxc
    ;   'xx'.join([["a","b"],["c","d"]], "-") 结果为a-bxxc-dxx
    ;data[1]为数组，funcObj则为子数组连接符
    join(data, funcObj:="") {
        if (data is array) {
            res := ""
            if (!data.length)
                return res
            if (isobject(data[1])) { ;funcObj视作小数组连接符
                for v in data {
                    str := ""
                    for v1 in v {
                        if (A_Index == 1)
                            str := v1
                        else
                            str .= funcObj . v1
                    }
                    if (A_Index == 1)
                        res := str
                    else
                        res .= this . str
                }
                return res
            } else {
                if (isobject(funcObj)) { ;有处理函数
                    for v in data {
                        if (A_Index == 1)
                            res := funcObj(v)
                        else
                            res .= this . funcObj(v)
                    }
                    return res
                } else {
                    for v in data
                        res .= v . this
                    return substr(res, 1, strlen(res)-strlen(this))
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
    joinK(obj) {
        res := ""
        for k, v in obj
            res .= k . this
        return substr(res, 1, strlen(res)-strlen(this))
    }
    joinV(obj) {
        res := ""
        for k, v in obj
            res .= v . this
        return substr(res, 1, strlen(res)-strlen(this))
    }
    joinO(obj, char:=":") {
        res := ""
        for k, v in obj
            res .= k . char . v . this
        return substr(res, 1, strlen(res)-strlen(this))
    }

    ; /k在执行完命令后保留命令提示窗口，而/c则在执行完命令之后关闭提示窗口
    runCmd(op:="/c") {
        run(this.toCmd(op))
    }
    runCmdHide(op:="/c") {
        run(this.toCmd(op),, "hide")
    }
    runWaitCmd(op:="/c") {
        RunWait(this.toCmd(op))
    }
    runWaitCmdHide(op:="/c") {
        RunWait(this.toCmd(op),, "hide")
    }
    toCmd(opt:="/c") {
        ;cmd.exe /k %windir%\system32\ipconfig.exe
        return format("{1} {2} {3}", A_ComSpec,opt,this)
    }
    toCmdStr() { ;命令行很多符号需要转义 https://blog.csdn.net/kucece/article/details/46716069
        return StrReplace(this, "&", "^&")
    }

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
                if(A_Index & 1 = 0 && IsNumber(A_LoopField) || A_Index & 1 == 1 && !IsNumber(A_LoopField)) {
                    throw(ValueError("Incomplete expression",, -7))         ;  for eg '2/2+' is incomplete.
                } else {
                    if(A_Index & 1 = 0) {
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
        BitwiseNot(n:=0) {
            return( ~(n) )
        }
        LogicalNot(n:=0) {
            return( !(n) )
        }
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
        while RegExMatch(str, reg, &m, startPos) { ; 由于每次要计算，必须一个个处理
            str := RegExReplace(str, reg, sNew:=funMatch.call(m),, 1, startPos)
            startPos := m.pos(0) + strlen(sNew)
        }
        return str
    }

    ;NOTE 实用
    add1(n:=1) { ;类似Excel的填充，最后一个数字+1
        if (n == 0)
            return this
        str := this
        if (str ~= "\d") { ;有数字
            RegExMatch(this, "^(.*?)(\d+)(\D*)$", &m)
            return m[1] . format(format("{:0{1}s}",strlen(m[2])), m[2]+n) . m[3]
        } else if (i := (str ~= "一|二|三|四|五|六|七|八|九|十")) {
            idx := map("零",0,"一",1,"二",2,"三",3,"四",4,"五",5,"六",6,"七",7,"八",8,"九",9,"十",10)[substr(str,i,1)]
            sBefore := substr(str,1,i-1)
            sAfter := substr(str,i+1)
            arr := ["零","一","二","三","四","五","六","七","八","九","十"]
            return format("{1}{2}{3}", sBefore,arr[idx+2],sAfter)
        }
        ;return m[1] . (m[2]+1).zfill(strlen(m[2])) . m[3]
    }

    ;参考python
    ;左边补0
    zfill(l) {
        return format(format("{:0{1}s}",l), this)
    }

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

    wordAddQuote() { ;单词增加双引号(af:day转成"af":"day")
        return RegExReplace(this, "([a-zA-Z_]\w+)", "$1".addQuote())
    }

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

    noHotkey(reg:="\(&.\)") { ;删除菜单的(&A)字符串
        return trim(RegExReplace(this, reg))
    }

    ;noExt64名称再替换空格为_
    noExt64(dealSpace:=false) { ;去除_x64.exe内容的名称(比如abc_x64.exe转成abc)
        res := RegExReplace(this, "i)_?(x?(64))?(\.\w+)?$")
        if (dealSpace)
            res := StrReplace(res, A_Space, "_")
        return res
    }

    ;删除文件名前面的序号
    noIndex() {
        return RegExReplace(this, "^\d{1,2}([.、]\s*)?")
    }

    ;判断拼音是否有效
    ;比如yuan 或 yuan1
    hasPy() {
        py := StrLower(this)
        sFile := StrReplace(fileread(_String.fileSZM, "utf-8"), "&nbsp", " ")
        if (py ~= "\d") { ;有声调
            py := py.py2sd()
            return instr(sFile, py)
        } else {
            reg := format("\s{1}(\s|$)", py.py2reg())
            res := (sFile ~= reg)
            ;if !res
            ;    msgbox(reg . "`n" . res . "`n" . substr(sFile, res, 9))
            return res
        }
    }

    ;判断拼音有哪些声调
    ;for cell in ox().selection {
    ;    if (cell.value == "")
    ;        continue
    ;    arr := cell.value.pyArrShengdiao()
    ;    xl.ScreenUpdating := false
    ;    if (arr.length < 5) {
    ;        s := "12345"
    ;        for v in arr
    ;            s := StrReplace(s, v)
    ;        ;msgbox(cell.address(false, false) . "`n" . s,,0x40000)
    ;        Excel_Comment._addString(cell, s)
    ;    }
    ;    xl.ScreenUpdating := true
    ;}
    pyArrShengdiao() {
        static sFile := StrReplace(fileread(_String.fileSZM, "utf-8"), "&nbsp", " ")
        py := StrLower(this)
        arr := []
        loop(5) {
            reg := format("\s{1}(\s|$)", py.py2reg(A_Index))
            if (sFile ~= reg)
                arr.push(A_Index)
        }
        return arr
    }

    ;拼音转成声调
    ;xuan1 → xuān
    py2sd() {
        py := StrLower(this)
        sd := (py ~= "\d") ? RegExReplace(py, "\D") : 5
        reg := "[āáǎàōóǒòēéěèīíǐìūúǔùǖǘǚǜ]"
        if (instr(py, "a"))
            return StrReplace(py, "a", substr("āáǎàa", sd, 1))
        else if (instr(py, "o"))
            return StrReplace(py, "o", substr("ōóǒòo", sd, 1))
        else if (instr(py, "e"))
            return StrReplace(py, "e", substr("ēéěèe", sd, 1))
        else if (py ~= "[iu]") {
            l := strlen(py)
            loop(l) { ;逆向遍历
                char := substr(py, l-A_Index+1, 1)
                if (char ~= "[iu]") {
                    if (char == "i")
                        return StrReplace(py, char, substr("īíǐìi", sd, 1))
                    else if (char == "u")
                        return StrReplace(py, char, substr("ūúǔùu", sd, 1))
                }
            }
        } else { ;ü
            return StrReplace(py, "ü", substr("ǖǘǚǜü", sd, 1))
        }
    }

    ;拼音转成正则
    ;xuan → xu[āáǎàa]n
    py2reg(sd:=0) {
        py := StrLower(this)
        reg := "[āáǎàōóǒòēéěèīíǐìūúǔùǖǘǚǜ]"
        if (instr(py, "a"))
            return sd==0 ? StrReplace(py, "a", "[āáǎàa]") : StrReplace(py, "a", substr("āáǎàa", sd, 1))
        else if (instr(py, "o"))
            return sd==0 ? StrReplace(py, "o", "[ōóǒòo]") : StrReplace(py, "o", substr("ōóǒòo", sd, 1))
        else if (instr(py, "e"))
            return sd==0 ? StrReplace(py, "e", "[ēéěèe]") : StrReplace(py, "e", substr("ēéěèe", sd, 1))
        else if (py ~= "[iu]") {
            l := strlen(py)
            loop(l) { ;逆向遍历
                char := substr(py, l-A_Index+1, 1)
                if (char ~= "[iu]") {
                    if (char == "i")
                        return sd==0 ? StrReplace(py, char, "[īíǐìi]") : StrReplace(py, char, substr("īíǐìi", sd, 1))
                    else if (char == "u")
                        return sd==0 ? StrReplace(py, char, "[ūúǔùu]") : StrReplace(py, char, substr("ūúǔùu", sd, 1))
                }
            }
        } else { ;ü
            return sd==0 ? StrReplace(py, "ü", "[ǖǘǚǜü]") : StrReplace(py, "ü", substr("ǖǘǚǜü", sd, 1))
        }
    }

    shouzimu() { ;获取大写首字母(热键用)
        firstChar := substr(this, 1, 1) ;获取第一个字作为关键字，搜索拼音首字母
        if (firstChar.isZh()) {
            if (RegExMatch(fileread(_String.fileSZM, "utf-8"), firstChar . "\s\K.", &c)) {
                obj := map(
                    "ā","a1",
                    "á","a2",
                    "ǎ","a3",
                    "à","a4",
                    "ō","o1",
                    "ó","o2",
                    "ǒ","o3",
                    "ò","o4",
                    "ē","e1",
                    "é","e2",
                    "ě","e3",
                    "è","e4",
                    "ī","i1",
                    "í","i2",
                    "ǐ","i3",
                    "ì","i4",
                    "ū","u1",
                    "ú","u2",
                    "ǔ","u3",
                    "ù","u4",
                    "ǖ","v1",
                    "ǘ","v2",
                    "ǚ","v3",
                    "ǜ","v4",
                )
                if (obj.has(c[0]))
                    return StrUpper(substr(c[0],1,1))
                else
                    return StrUpper(c[0])
            }
        } else
            return StrUpper(firstChar)
    }

    shouzimus(isUpper:=1) { ;中文转拼音首字母（不支持多音字）
        static sShouzimu := '
(
安案按爱阿奥岸澳埃艾碍啊癌暗昂傲鞍哀氨挨俺熬矮凹盎胺隘鳌铵谙庵蔼敖黯遨唉鏖袄皑哎坳翱嗷肮懊岙鹌霭捱嗄螯骜暧桉嫒獒嗳鏊吖瑷埯锕嗌媪廒聱犴揞锿砹 A
不部报本北保表办并比步把标被别变百必备包布八便版边病白巴半班波编兵补宝帮币笔博般倍播遍板毕败宾背摆冰避暴闭奔杯颁伴勃拨拔胞贝薄邦伯爆滨吧玻饱壁捕抱拜辈搬搏悲堡斌榜碑坝辩爸柏泊舶霸弊彼逼罢碧剥渤饼彬炳斑鼻鲍鞭棒臂扮濒秉辨卜泵贬彪膀丙埠驳镑绑傍芭崩簿鳖哺怖蔽匾跋苯葆瀑豹扒殡叭卑脖璧蚌悖庇拌扁褒扳痹缤瓣膊惫摒毙憋笨蹦坂柄簸弼菠靶阪礴迸绊夯绷谤甭雹佰疤箔蓓匕鄙陛鬓卞槟镖梆孢裨掰铂汴苞裱陂煲笆钚辫亳贲钵浜帛敝鲅飚钡狈瘪呗砭禀膘飙蓖粑岜焙擘褓镳饽苄摈跛灞膑吡蝙捭篦嘣钹俾铋稗钣蒡碚钯瘢婊蹩毖筚趵荸薜婢檗舨哔卟褙鳊邴鸨跸骠弁玢锛瓿濞镔逋捌秕荜愎窆畚妣飑豳髌龅甏箅傧啵鹁晡庳髀笾鞴畀滗煸褊孛宀菝魃癍鹎坌狴萆嬖襞碥髟鳔醭疒茇勹邶鐾舭忭缏瘭踣钸 B
产出成场长从次程厂此车持城村处常创查传才参采策财存础层承初称促超材春除充陈察措曾菜差吃测草藏川船彩朝筹彻冲潮偿残储裁昌册茶唱纯操错词乘穿诚沉床餐抽畅畜呈触楚撤辞窗倡崇虫池拆迟曹晨仓侧柴刺琛尝闯赤瓷粗臣惩绸磁蔡插尘丛炒吹串酬驰匆尺辰撑苍灿催寸聪肠厕慈阐衬惨崔脆垂磋沧擦愁钞茨翠蚕斥敞丑叉厨挫齿抄刹舱醇凑臭翅澄萃巢缠宠葱掺槽扯趁痴猜粹禅喘锤颤摧雏仇猖秤畴耻淳炊吵窜矗娼踩簇辍忱赐茬揣唇忡铲璀陲醋疮糙橙璨槌炽祠蝉骋岑绰稠橱嘲椿锄褚岔澈郴逞侈憧瞅戳雌弛搀瘁搓诧潺滁囱瞠蠢惭蹴睬踌躇撮掣叱猝嘈徜啻昶怅篡疵漕琮丞蟾捶碴馋嚓怵椽悴忖宸怆姹忏晁惆铛谌淙淬嫦绌鹑蹭杈搐蹉踹钗嗤恻涔埕墀刍粲汊碜塍蜍锉哧舛衩婵孱蹿嗔茌菖鲳厝嵯觇黜焯抻豉敕噌杵啜蹙豺痤枞皴搽槎榇舂伧棰阊笞饬钏蛏蹰龊辏踟柽啐伥苌鹚铖俦侪坼蚩嘬糍骢廛瘳亍遄谄谶酲茺樗憷莼撺镲谗踔苁砗铳楮蔟毳艹檫媸氚呲殂矬氅魑篪澶龀裎雠蝽腠刂骣羼耖褫彳艟璁爨榱螬虿瘥惝怊鸱螭瘛徂汆脞礤骖黪艚锸猹躔蒇冁鬯屮枨眵傺搋巛舡楱镩鹾膪 C
的大地到对多定动等得电第代当度都点达道调导东党但队单带打德断段低担店吨待底独斗督贷读短登邓订岛顿典答档倒毒抵盾夺董丹端冬渡掉胆灯顶旦洞丁弟蛋迪杜淡递戴刀诞盗豆帝袋敦懂稻荡兑敌雕堆奠搭跌堤蒂冻吊锻蹈堵缔丢栋鼎歹甸碘赌淀殿钓呆睹滴朵挡垫涤盯肚叠逮悼蝶迭钉躲颠蹲抖锭氮兜镀叮郸陡滇墩耽娣岱凳傣笛碟逗铎捣窦咄棣爹荻渎怠囤瞪刁缎癫笃巅堕惦谍仃蹬侗谛掂瘩叨狄牒邸咚祷舵殆嘀垛黛沌惰钝铤殚炖宕貂凋甙嘟犊惮癜妒嗒町砥玷牍儋耋坻哆盹遁砀哒喋踱埭诋眈跺嫡蠹碓佃碉耷鞑裆趸疸峒噔鲷氡踮叼镝蚪凼恫掇剁澹酊掸碲靛靼啶煅痘砘钿碇亻嗲胴磴硐椴绐氘骶玳啖蔸菪嶝箪缍镫腚谠簟氐褡垌椟柢聃镦锝堞疔笪迨纛簦玎怛籴礅妲铥黩怼沲萏坫鸫篼簖裰哚帱瘅忉羝睇瓞鲽岽胨芏骀夂丶戥觌铞垤揲蹀耵髑憝卩赕 D
而二尔额儿俄恩恶耳鹅遏鄂厄饿峨扼迩娥鳄饵洱蛾噩愕讹锷垩婀嗯鹗萼唔摁贰铒谔莪腭锇颚呃阏屙苊轭蒽珥佴鸸鲕诶 E
发方法分放府费服风副反非负富份房防复范访飞福夫犯丰纷否妇奋幅繁饭付罚扶封纺泛肥父符翻附腐凡峰乏伐奉赴废返番佛粉凤芳锋贩仿浮覆辅冯菲氛傅芬伏抚赋逢辐腹缝坊烦弗肤蜂阜帆袱樊愤肺妨啡沸缚匪甫枫氟粪疯阀坟汾斐斧焚孚敷肪俯拂讽俘咐腑烽孵藩芙涪蜚釜妃诽扉酚翡矾梵筏霏蕃邡舫吩茯馥钒忿吠幡砝俸畈绂绯讣呋罘麸蝠匐腓沣痱芾蜉垡淝枋跗凫滏珐蝮鲂悱狒棼驸榧绋蚨酆砩桴赙砜鲱葑缶菔鼢钫攵犭蘩趺苻拊鲋蹯瀵怫燔偾稃郛幞篚镄鲼唪祓艴黻黼鳆 F
国工个公高关过改各管规革广共干更果格给观构该供告港股光根感功购搞古钢顾馆官刚故贵歌够贯固鼓贡骨归岗挂攻估轨冠哥赶盖敢甘耕跟郭宫谷概稿沟惯桂瓜滚锅怪纲隔灌巩柜姑割孤阁肝狗戈杆罐钩雇圭葛赣刮龚冈溉鬼辜勾杠膏菇拐莞硅糕庚耿瑰逛裹棍鸽恭钙缸寡柑搁拱苟嘎躬跪尬尴龟竿帼弓秆橄梗沽胳棺垢舸闺噶卦咕丐呱镐辊疙犷亘乖皋汞铬锢矸钴埂诡羹枸哽旮骼伽箍淦汩褂咯羔圪胱赓肛篝癸尕梏痼镉赅锆崮倌炔杲苷郜轱罡佝睾媾擀酐鸪牯蛊呷鹳鳜艮诰蚣椁诂桧藁珙鳏盥皈鲑觥毂刽蝈绀虢咣晷篙肱傀泔硌鹘缟聒槁嗝剐诟掼钆岣菰罟嘏埚坩臌垓旰妫衮鬲膈疳彀胍磙缑诖炅鲧绠觚鸹涫戆纥哏鲠笱瞽庋簋刿掴猓陔筻蛄绲崞蜾栝澉槔袼搿茛鞲觏酤牿鲴宄匦呙馘尜戤塥哿虼遘桄 G
和会行化合后好海还华活很划或回环话护户河花何货获黄号红火挥汇核湖换画航黑害欢互汉宏孩候洪乎呼哈韩惠怀胡含辉厚患衡坏荒缓伙恢婚混贺煌横毫豪徽皇杭忽耗绘虎滑旱寒浩毁汗喝赫慧淮荷灰狠轰涵贿侯恒唤函惑虹鸿弘喊焕沪魂霍盒糊憾罕幻焊鹤卉浑昏翰祸哄恨凰壶悔郝痕徊猴邯呵亨喉慌秽晃撼荟晖彗讳槐潢哗痪烘豁骅葫泓狐瀚蝴禾桦谎惶憨弧皓菏捍桓簧璜诲壑亥寰珲恍昊涣褐吼咳酣悍瑚骸幌湟蝗哼磺蒿诙浒宦涸嘿骇珩鹄壕荤蕙琥蛤隍徨晦扈灏猾唬麾阂滹阖氦嚎劾铧惚馄诃濠嗨鼾颌訇烩邗蚝踝颔嗬祜遑桁蚶囫茴晗喙逅洹浣豢沆奂颢蘅蕻肓蛔闳斛菡篁圜鳇讧笏蟥洄浍诨绗嚯藿曷嗥铪醐獾鲩虺顸薅翮猢怙唿戽鬟恚颃篌锪蠖槲觳萑癀蟪钬盍荭黉糇骺後鲎煳鹕冱瓠逭漶耠镬焓瘊虍岵鹱咴隳缋溷夥胲醢撖嚆薨堠烀轷锾缳擐阍劐攉砉 H
军均君菌钧筠皲麇俊峻竣骏隽郡捃经家进建济加机就金技将基今记计教际及京决交结解价间界集件局级据江近几接见究精具积举极己仅境节较纪坚检九即奖届健竞继紧监居尽讲减景降介剧击阶假酒巨既久激绝警津角绩觉急简街救斤旧艰吉季借践兼鉴竟禁键疾叫佳架锦杰聚迹卷井距惊径渐疆脚静句洁鸡剂捐劲缴敬辑纠净籍截胶姐甲拒轿郊焦揭镜寄晋柬嘉捷挤蒋俱贾姜掘驾剑尖肩舰崛睛荐劫晶戒箭嫁剪皆谨菊圾冀筋夹骄俭巾碱浆竭拘颈亟寂暨浇浸脊跻椒炬荆肌稽忌桔饥兢匠酱礁僵靖佼茧祭稼眷娟蕉奸倦惧缉棘矩诫钾诀矶襟歼娇獗汲畸矫拣搅鞠姬绞舅窘捡酵煎秸炯驹抉爵锯贱睫泾剿灸嚼绢藉饺瘠靳窖跤挟踞疚桨咀蛟骥瑾拮憬镌鲸揪溅羁茎迥腈涓倔菁胫涧狡鹃妓讥稷迦蓟咎悸姣掬绛沮嫉芥笺岌韭厥蕨颊叽缰玖攫皎珏伎臼烬阱旌莒粳矍浃缙柩鲫诘楫赳谏痉橘戟钅箕蹶枷矜饯碣犟飓霁嵇锏茭戛鸠缄谲疽鄄觊镢荚鹫痂嗟颉蚧儆钜厩趄孑睑麂謇蹇觐啾踽腱镓遽畿玑婕琚笈笳菅龃噱珈犄翦铰椐芨戬醮疖唧桀毽迳屐讦婧苣髻裾笕堇馑荩榘豇狙岬胛桷鲛疥戢阄噘撅犍硷噤佶偈倨橛笄袈羯肼跽榉郏鞯徼孓葭牮礓苴讵蒺廑妗袷瘕枧洚桕雎蠲纟廴乩咭赍嵴铗湔槿赆僦虮掎鲣囝裥踺茳糨鹪狷齑殛鲚跏蛱搛缣鹣僬噍衿糸剞洎恝蒹谫僭艽挢敫卺扃锔窭锩觖劂丌墼蕺芰哜戋趼楗耩喈鲒骱刭弪獍鬏鞫犋屦醵桊爝 J
开可科口看快况款克客考空困控康矿扩靠苦括卡库刻刊亏抗块课跨宽肯阔扣昆孔恐勘颗框堪垦凯慨坑狂哭渴酷喀壳烤坎裤夸奎愧柯砍坤恳棵咖魁馈枯窟侃捆溃垮坷扛慷楷旷啃眶恪匮廓苛寇炕叩匡亢筷筐葵窥磕抠拷糠槛恺铿瞰珂铐盔吭挎脍逵咔睽稞邝琨蒯揩髋伉馗聩阚喟瞌夔溘轲窠篑岿锴龛嗑锟鲲铠倥疴崆喹揆胯忾骷蝌侩蔻栲岢圹哐戡尻贶垲郐堀绔犒暌钪侉夼跬颏裉诳髁醌剀诓佧箜蒉蚵芤刳愦髡悃缂喾狯纩蛞氪骒哙悝蝰胩锎蒈莰闶钶锞眍筘阃 K
了来理力利立量里两路领联老流论林李料率劳列拉律历类连落乐刘旅例六粮良令龙罗离兰留临略烈另陆楼疗录练励绿轮乱累零辆灵冷雷礼虑丽露鲁辽览亮梁浪络勒劣龄廉洛隆炼黎伦蓝卢莱陵篮炉履朗邻脸泪赖栏柳岭璃凌厉牢郎漏裂岚赁吕铝烂凉滥廊莲玲缆屡鹿铃揽恋垃垄厘捞笼粒猎俩廖瘤莉链睐琳磷腊啦禄涝逻辣澜赂聊蕾拦硫垒梨陋淋螺麟芦谅菱锣庐隶仑溜栗磊纶碌狼拢蜡寥氯骆聋荔萝喇帘懒沥霖陇卵擂琅缕掠僚怜犁漓裸沦榄滤鳞麓涟浏哩漯侣狸娄滦燎缭凛颅藜驴泸愣罹镭榴胧棱徕敛伶峦拎烙篱羚姥撂楞琉苓聆粱卤斓摞珑鲤潞剌佬晾砺馏吏搂澧俐鹭鸾撩冽肋骊琏溧栾辘遴榈旯蔺骡窿虏璐婪崂翎篓砾吝阑粼唠泠镰嘹莅茏抡榔锂笠瓴酪箩蠡遛銮靓蛎濂痢喽雳咙漉挛噜孪楝闾潦镂籁涞珞俪嶙砻傈螂叻垅偻咧褛醴栎鎏镣骝瘘郦踉躏戮褴阆鲢囹寮俚枥绫羸鲈囵锒赉趔捋掳橹耒濑洌呤荦棂殓髅轳逯喱逦廪绺渌癞蓼娌潋蛉酃崃罱痨儡鹂檩莨啉谰戾撸鸬雒砬唳辚椤醪坜疠椋邋耧蝼啷蒗蜊獠鬣黧猁钌镏铼嫘栌氇镙粝魉旒瘌镧铑鳓蓠呖跞裢裣埒捩鲮熘嵝瘰缧酹嘞疬臁膦泷蒌泺缡鲡鳢奁墚尥柃胪镥脔冫稂塄嫠詈蠊鹩躐鹨簏膂脶诔苈篥娈瞵锍栊癃舻辂稆猡漤铹栳耢仂泐檑轹蔹懔垆锊倮蠃 L
民们面目明名门美没每贸么马模米命满买卖毛某密木亩棉煤免幕母蒙秘末牧盟梅矛冒莫吗摩麦谋敏麻码迈忙梦墨盲猛苗貌慢曼妈默灭迷媒漫穆磨枚孟鸣秒摸漠姆茂妹妙描墓脉慕茅膜帽埋玛弥庙铭眉绵缅魅牟牡猫魔茫募闽瞄勉蔓芒眠霉蜜沫嘛骂睦陌抹萌谜闷觅缪瞒髦寞靡昧蛮媚蚂玫沐酶泌镁氓蘑鳗暮锚馒冕拇湄朦闵莽冥摹眸锰懋寐渺谬莓袤蓦眯麋猕馍茉袂蔑檬皿楣谧泯谟茗娩淼咪牦岷卯勐铆耄钼糜懵腼悯溟峁宓渑幔酩嵋藐蟒汨谩珉螨秣霾醚湎瞑篾缈苜扪焖懑沔唛仫蟆邈貉抿邙瑁螟嘧弭蜢嫫犸暝虻熳黾镆缦殁蟊茆哞蝥缗呒镘脒荬颟旄泖镅蠓幂耱杩劢墁玟嬷昴瞀浼艨祢縻蘼芈眄鹋杪咩愍麽瘼鍪蛑甍艋敉眇蠛侔鞔硭漭猸鹛钔瞢礞喵苠鳘貊貘毪坶 M
年能农内南难那女你念宁努纳拿尼脑男呢哪牛泥诺您纽娘乃凝奶浓扭耐暖拟闹弄鸟挪酿娜尿奈逆嫩囊聂倪怒恼妮奴挠虐楠腻捏钮匿钠呐霓辗碾涅拧镍瑙溺喃讷疟泞柠馁糯脓袅侬捺弩廿淖旎孽拗懦捻傩鼐撵昵拈咛蔫妞坭狞萘鲶埝蘖钕啮蹑铌馕嗫囡氖孬喏鲵鲇垴辇臬囔曩黏镊颞忸伲脲佞哝铙乜怩驽恁赧睨柰衲腩蝻呶搦廾硇猱茑镎肭艿蛲陧衄锘攮猊嬲聍甯狃耨孥胬恧 N
欧偶殴呕藕讴鸥哦瓯噢沤耦怄 O
品平批配评破牌培片排普票派贫判拍皮鹏篇坡盘迫跑朋怕聘偏赔凭铺浦频颇辟骗彭炮膨佩旁陪瓶朴潘攀葡蓬屏啤拼谱埔匹喷漂萍盼盆碰飘扑泡婆庞苹棚披疲帕抛乒拚爬沛泼捧魄乓坪畔仆剖僻徘蒲胖曝毗烹坯磅脾翩篷嫖叛譬溥刨裴劈媲莆澎袍圃胚屁璞湃濮趴菩粕瞥琶琵瓢螃鄱啪撇脯珀邳蹒葩抨磐硼痞癖怦丕蹼彷耙杷枇剽咆噼霹俳枰滂砰爿蟠哌逄颦缥疱匍嘭庖狍纰匏叵砒姘娉铍骈掊泮霈淠胼殍噗瞟郫旆埤蹁谝嘌袢帔睥苤嫔笸氆呸醅芘蚍圮榀筢耪辔牝冖襻鼙湓罴蜱俜鲆皤镨脬蟛貔仳犏钋莩堋庀擗甓螵钷攴蒎锫陴氕丿裒镤 P
全企区前其起去强期情求取权确气青群清千钱切请却且七球亲器轻汽缺庆签桥奇券曲齐趋启秋勤抢渠潜旗倾侵乔泉穷趣棋侨迁秦妻欠弃圈墙枪巧恰牵钦琴驱悄拳洽歧浅禽劝顷丘欺琼屈骑契卿敲窃邱俏迄遣谦腔犬漆乾铅戚岂岐歉晴雀黔裙谴琦栖瞧氢琪泣酋躯芹嵌衢沁乞茄砌祁裘翘崎窍绮娶祺蹊寝祈凄倩峭擒擎祛锲囚钳淇杞铨痊瞿鹊茜锹虔氰锵脐撬怯麒圻岖诠憩呛阙荃掐堑惬穹羌荞芪噙钎跷醛骞樵遒罄憔龋觑阡瘸榷畦荠磬蜷蔷蜻耆鞘葺沏朐萋襁掮羟骐鳍跄箐綦妾蛐鳅讫橇嗪虬揿蚯峤癯蛆蕲钤泅屺邛樯挈戕扦颀亓碛芊茕柒颧郄阕溱荨芩逡汔诮楸阒绻髂仟芡谯湫悭缱衾鲭綮嫱筇犰佥箧跫萁苘逑诎劬蕖匚嘁蛴戗蛩巯悫炝愀蘧氍槭镪黢芑葜愆锓蠼筌鬈桤褰肷锖鞒吣黥俅璩悛辁蜞岍搴箝慊椠蜣硗劁缲檎螓圊檠謦銎赇鼽糗麴鸲磲畎 Q
人日入如任然认热让容荣仍融染瑞润肉若仁软弱绕燃扰绒乳忍锐壤柔儒辱溶饶汝扔蓉韧阮熔刃纫惹冉攘茹戎饪榕嚷睿偌褥芮茸揉冗孺濡蕊闰嵘妊蠕糅荏苒鞣稔娆瓤蹂髯壬蕤仞轫嚅衽缛箬溽穰铷蚋朊禳桡洳枘蚺荛肜狨蝾薷襦颥蓐 R
是上市生时实设社说事三司水省商十所术使收山世书四少手施深式数受税势视首思身斯色神识速屾师售史示石食始赛士失双算善素声随适试什审属苏损升送室岁树沙私胜输绍授索申诉顺死虽束甚述尚松摄伤散孙谁署盛似守涉塞射诗熟丝沈森殊萨厦缩塑肃宋蔬饰舍杀烧陕释俗赏寿圣酸桑扫锁刷驶剩伸饲氏舒衰闪睡硕逝牲丧寺洒慎疏衫湿擅撒讼碎稍鼠纱淑艘渗蛇叔帅汕暑扇枢砂绳啥搜蚀狮隧瘦颂邵爽莎兽墅骚遂瞬誓哨肆摔杉霜拾尸笋甩筛髓伞蒜傻肾舌曙匙抒穗晒耸梭韶珊瑟绥竖僧粟蜀烁仕柿朔薯奢涩溯梳撕诵舜嫂嗓琐矢栓泗耍隋慑煞删膳戍恕邃缮侍绅孰酥嵩夙捎莘噬勺嗜伺赡梢鄯拴笙嗣栅昇祀沭狩缫涮赎庶煽赦赊裳姗跚拭漱佘屎麝呻恃厮驷嘶荪鳝淞塾擞婶甥嗦娠砷嗽唆唢墒锶啬轼睢嬗畲祟嵊绶晌愫吮腮潸晟蟀铄俟鲨飒娑虱倏澍濉霎嗖簌蜃怂稣卅芍榫孀搔悚仨搡叟讪唰舢劭纾僳苫燧姝垧氵菽隼疝馊觞谡巳崧蓑蛳咝凇穑膻羧忪谇殇舐黍薮眭噻铯瘙痧竦厍裟挲叁臊钐腧闩菘鳃艄莳艏铩猞眚铈谥耜飕筲哂炻豕秫笥涑鲥狲桫蟮饣杓葚熵绱蛸螫毹妁嗾糁馓酾槊狻芟埏渖筮殳飧埽潲诜埘弑嗍蒴鸶缌澌姒蔌睃忄凵颡谂礻摅汜溲嗉荽灬丨脎毵磉鳋唼歃彡骟滠矧胂蓍鲺贳搠厶兕锼螋瞍觫宿 S
他同体天提通题条特投统团台头推谈它土她铁突图太田态套听庭托讨探退停厅脱童堂途坦拓泰塔透贴唐痛挑跳摊弹陶腾拖炭糖坛替徒涛铜添滩偷填踏逃贪妥叹腿涂廷梯挺桃汤塘甜抬胎吐亭萄吞汰淘艇谭桶潭疼掏桐屠塌碳毯屯兔躺藤筒踢瘫趟滔惕滕倘棠驼烫剔榻蹄沓淌迢陀彤韬婷秃凸汀帖眺啼沱佟膛潼鸵钛荼檀痰捅苔恬湍袒獭褪驮坍搪酮豚覃颓薹蜕屉剃涕烃唾霆椭焘腆锑倜臀蜓忐坨忑昙肽砼挞饨瞳悌恸佗洮砣郯跎苕窕镗啕蹋跆舔邰忒疃傥仝逖嚏庹螳绦誊笤佻嗵柁钽钍钭抟暾阗忝橐趿遢鲐醍僮氽饕餮骰乇铊呔扌溏铽殄酞帑葶菟鳎绨粜锬羰鼗鹈畋髫萜堍溻饧樘醣酡缇梃彖鼍冂闼炱螗耥裼莛箨镡铴瑭慝掭祧龆蜩鲦茼酴煺柝 T
为我外万务文位问委物无五完王望闻未往维稳武卫围网晚湾午温违吴舞威伟伍危味微污握瓦乌误忘亡唯谓屋旺伪玩挖慰汪尾窝魏晤碗娃顽韦悟沃翁卧吾挽纹雾弯胃畏帷喂芜丸歪巍萎蔚皖纬宛潍梧尉挝婉洼袜吻蛙腕渭惟蚊勿薇苇巫炜侮枉妄雯坞涡紊毋诬哇呜娓瘟诿蜿惋钨斡玮邬烷渥捂汶鹜幄兀婺嗡惘瓮妩琬蜗佤崴戊桅罔畹偎鹉豌喔逶倭娲猥剜浯蜈囗葳隗痿猬蓊骛纨涠嵬韪仵煨莴艉龌辋焐刎芴绾帏闱鋈脘洧肟魍庑菀沩鼯牾璺怃圬芄隈鲔硪忤痦亠蕹迕杌寤腽軎阌阢 W
新学现下小心向些系西性项先相信县形效想销乡协需型消选兴许线续讯象席限息校须响香宣显修希险习星写训献像吸秀序喜鲜细血迅夏谢雄徐械析休寻晓笑雪戏享峡刑箱询洗悉辛祥鞋幸姓蓄循宪欣锡醒虚辖吁溪纤旋旬陷闲惜肖稀巡袭贤兄熊绪夕霞湘薪胁斜详削仙携胸懈叙衔晰悬昔汛孝萧牺橡巷袖卸掀勋邢咸凶绣翔谐烯薛虾潇泄旭杏熙襄嫌狭厢匈逊蟹馨轩穴邪吓朽羡歇鑫锈弦芯媳熏侠镶暇腺硝喧锌宵遐玄膝羞泻隙绚徇汹啸恤犀浚屑墟嚣栩絮忻圩硒兮瞎熄殉霄痫娴舷渲驯馅曦燮璇榭禧淆嬉腥酰婿蝎玺昕哮筱炫靴戌奚鲟胥汐匣逍嘘萱徙撷煦羲铣淅癣偕嗅漩嘻眩酗衅猩薰瑕飨岫歙暄溴熹冼荀浔悻涎暹籼箫矽蟋庥骁煊铉诩洵郗锨苋枭亵唏陉惺谑峋饷盱缃楔蚬骧蓿皙隰缬馐歆邂黠跹芗埙樨巽岘浠瀣藓鳕郇庠溆醺蜥楦恂勰檄芎硖罅燹泫翕阋踅窨鹇鲞舾屣狎哓绡咻洫葸氙谖螅顼泶蕈崤囟粞觋莶霰榍薤髹曛欷僖醯鼷跣枵擤勖痃碹穸饩舄禊猃绁渫廨獬硎荇鸺貅糈揎镟獯彐菥蓰柙祆筅葙蟓魈躞醑儇 X
一有业要以用于月元也与员已应由意营议义因院原研运育又益样亿优易引亚严源医影验约艺养越央银游依油英远药余友阳预域演言眼印予云遇愿园音洋压迎扬杨永移拥语映右烟沿誉玉夜叶邮鱼延雨衣异伊跃仪尤宜硬饮勇遗野疑邀援盐雅羊盈渔牙裕涌忧圆液毅谊允赢幼炎亦愈泳娱燕摇欲阴押岩疫冶舆缘隐役宇忆耀阅抑羽颖袁犹诱乙译宴逾腰艳页遥氧颜岳爷悠姚鸭豫怨耶仰翼窑姻郁呀粤幽寓悦孕婴溢殷椅彦狱喻御蕴淫涯韵掩浴沂尹鹰淹阎庸衍愉瑶咬雁秧渊禹俞逸崖苑俑芽荫榆曰愚尧踊咽酝耘哑厌钥蚁吟渝夷焰佣淤荧邑佑怡瘾谣椰绎冤寅咏虞屿彝裔峪晕讶肴莹匀樱堰姨鸦瑛驭茵砚熠贻瑜矣媛雍烨唁禺芸蝇毓屹娅陨颐钰猿夭垣倚诣胰釉痒萦纭焉奕漾晏疡翌哟檐柚隅莺泱甬颍侥吆蜒镛铀鱿殃奄膺衙芋俨熨腌妍掖弈轶缨瀛瘀驿囿沅妖谚壹迂塬恙臃郧垸曳兖筵垠焱猗鸳煜鸯楹偃徉闫晔昱酉攸黝幺臆弋罂铱丫嫣旖谒於辕荥漪鄢鄞臾杳萤莠邕猷蚜湮盂赝迤胭佚鹦蛹聿琰腋滢蓥翊诒舀佯恿竽萸垭噎妪恽韫伢怿痍懿郢饴峄腴圄谕窈揖眙觎曜蚓鸢郓镒茔仡氤怏揄氲揶黟滟龉钺殒氩桠胤蝣瑗琊嘤疣炀烊肄龈谀靥咿翳挹缢慵呦呓俣愠阉刈壅馀庾蚴妤瘐魇酽咦嶷羿郾鹞钇殪痈揠邺鳙恹鬻爰崦芫荑薏莸欤鹬鼋樾喑墉昀爻蜴镱铟莜噫璎铕宥阈癔洇嵛剡鞅狺夤嬴瘿饔雩鹆橼鼹繇苡悒吲喁卣牖睚痖菸餍徭瘗唷圉蜮疋迓衤欹佾埸霪茚鼬伛谳轺铘圯纡窬窳饫蓣瀹蝤铫讠厣罨蛘鳐崾舣媵尢蚰侑狳螈龠阽哕肀岈砑珧酏劓堙撄潆舁蝓燠眢箢掾刖狁玥雲祎 Y
在中这作展主资制政重自者之种总子着增正最组治质造专职只志战至指证织支张转准做争镇值走装众责州整知真则直再族占抓住周足照注助致字执洲站章终置止泽逐座早著征状综招针筑找罪召灾圳左债追植怎纸振障祖杂择赞驻朱租赵智钟庄宗珠郑涨浙载坐掌震壮忠珍扎祝折尊阵猪帐诸柱殖秩遭暂遵咨阻宅胀症竹昨仲纵赠钻赚诊寨炸旨址邹滞彰奏滋哲摘桌卓兆栽铸枝衷撞砖踪丈株瞩嘴仔脏舟姿紫侦挣骤芝肿咱昭兹撰妆葬脂轴崭诈帜枣幢宰醉蒸仗轧汁孜粘湛佐捉噪闸肇灶淄桩窄嘱砸贮赃籽渣昼肢挚蔗斋沾罩宙瞻遮燥琢煮睁臻贞糟凿铮躁漳坠稚筝咋钊乍詹枕翟斩沼藻皂棕灼粥攒澡纂缀皱拯椎浊酯贼踵梓掷烛樟哉峙鲻桢账杖辙酌榨篆赈盏炙臧楂卒拙绽谆栉侄肘苎璋祯辄帧札爪渍毡茁栈甄芷锥姊涿蛛拄铢斟啧洙窒咫竺拽蘸眨蛀峥渚吱攥伫缜咒咤匝杼箴赘憎趾柘祚疹痔秭镯柞恣冢唑蜘帚郅喳胄嶂仉崽绉粽侏锗鬃桎锃雉褶诏怔惴蚤俎蜇瘴祉盅啄蛰甾咂奘砧鳟诅揍蟑诛陟诤鹧谪昝赭狰孳纣獐幛榛偬铡濯簪訾茱滓鸩痣蛭糌倬帙馔蚱锱瓒枳啭樽箸仄炷妯躅擢轸甑踯翥啁稹徵诌隹砦蓁胝颛栀斫镞錾吒旃箦鄣摺钲贽缵祗豸辎趑龇酢磔胗肫赀眦椹赜潴骓缁诹怍笮舴罾棹鸷碡砟谵朕摭轵诼笫阝瘵畛卮轾彘觯锺邾槠谘嵫髭蕞辶茈趱驵缯揸笊絷跖舯螽籀舳粢驺陬阼馇昃痄搌浈埴黹酎橥缒窀菹拶唣迮帻谮哳齄嫜忮骘膣踬荮瘃麈疰丬浞禚觜耔腙鄹鲰躜撙胙 Z
)'
        static obj := map(
            "ā","a1",
            "á","a2",
            "ǎ","a3",
            "à","a4",
            "ē","e1",
            "é","e2",
            "ě","e3",
            "è","e4",
            "ō","o1",
            "ó","o2",
            "ǒ","o3",
            "ò","o4",
            "ī","i1",
            "í","i2",
            "ǐ","i3",
            "ì","i4",
            "ū","u1",
            "ú","u2",
            "ǔ","u3",
            "ù","u4",
            "ǖ","v1",
            "ǘ","v2",
            "ǚ","v3",
            "ǜ","v4",
        )
        str := this
        if (str == "")
            return
        res := ""
        loop parse, str {
            if (A_LoopField ~= "[[:ascii:]]|（|）") {
                res .= A_LoopField
            } else {
                if (RegExMatch(sShouzimu, A_LoopField . ".*\K\w", &m)) {
                    if (obj.has(m[0]))
                        res .= substr(obj[m[0]],1,1)
                    else
                        res .= isUpper ? StrUpper(m[0]) : StrLower(m[0])
                } else {
                    res .= A_LoopField
                }
                ;msgbox(A_LoopField . "`n没找到拼音")
            }
        }
        return res
    }

    quanpins(tp:="T") { ;获取全拼
        str := this
        if (str == "")
            return
        strFile := fileread(_String.fileQP)
        res := ""
        loop parse, str {
            if (A_LoopField ~= "[[:ascii:]]")
                res .= A_LoopField
            else {
                if (RegExMatch(strFile, A_LoopField . ".*\s\K\w+", &c))
                    res .= StrTitle(c[0])
                else {
                    msgbox(A_LoopField . "`n不在列表，请完善")
                    run(_String.fileQP)
                    res .= A_LoopField
                }
            }
        }
        return res
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

    ;n1 := 3.06
    ;n2 := 2.14
    ;msgbox((n1+n2) . "`n" . (n1+n2).floatErr())
    ;msgbox((n1-n2) . "`n" . (n1-n2).floatErr())
    floatErr() {
        return round(this+0.00000001,6).delete0() ;+号为了解决全是9的问题
    }

    ; arr := [
    ;     0.01,
    ;     1.0100,
    ;     2.10010,
    ;     3.19999999996,
    ; ]
    ;arrV要用这个方法 整数可用 integer() 代替
    ;NOTE 日期表示为 3.20，会影响实际数据
    delete0() {
        num := this
        if (num ~= "^-?\d+\.\d+$") {
            if (num ~= "\.\d{8,}$") ;小数位太多的异常
                num := round(num+0.00000001, 6)
            return rtrim(RegExReplace(num, "\.\d*?\K0+$"), ".")
        } else {
            return num
        }
    }

    isZh() { ;是否中文
        return (this ~= "^[\x{4E00}-\x{9FA5}]")
    }

    isabs() { ;判断字符串是否为路径格式
        return (this ~= "i)^[a-z]:[\\/]")
    }

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
    isMAC() { ;判断字符串是否为路径格式
        return (this ~= _String.regMAC)
    }

    isIP() {
        return (this ~= _String.regIP)
    }

    isText() { ;是否文本文件
        return instr(this, ".") ? (this.ext() ~= _String.regText) : (this ~= _String.regText)
    }

    isImage() { ;是否图片文件
        return instr(this, ".") ? (this.ext() ~= _String.regImage) : (this ~= _String.regImage)
    }

    isAudio() {
        return instr(this, ".") ? (this.ext() ~= _String.regAudeo) : (this ~= _String.regAudeo)
    }

    isVideo() { ;是否视频
        return instr(this, ".") ? (this.ext() ~= _String.regVideo) : (this ~= _String.regVideo)
    }

    isZip() { ;是否压缩包
        return instr(this, ".") ? (this.ext() ~= _String.regZip) : (this ~= _String.regZip)
    }

    isExcel() {
        if (1)
            return StrLower(this.ext()) ~= "i)^xls"
        else {
            SplitPath(this, &fn, &dir)
            oFloder := ComObject("Shell.application").NameSpace(dir)
            return instr(oFloder.GetDetailsOf(oFloder.ParseName(fn), 2), "Microsoft Excel")
        }
    }

    isWord() {
        if (1)
            return (StrLower(this.ext()) ~= "i)^doc")
        else {
            SplitPath(this, &fn, &dir)
            oFloder := ComObject("Shell.application").NameSpace(dir)
            return instr(oFloder.GetDetailsOf(oFloder.ParseName(fn), 2), "Microsoft Excel")
        }
    }

    isPPT() {
        return (StrLower(this.ext()) ~= "i)^ppt")
    }

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
    githubForClone(tp:="github"){
        return format("{1}.git", this.githubUrl(tp)) ;TODO 增加 .git 的作用
    }
    ;比如 a/b 转成 git clone https://github.com/a/b.git --depth 1
    githubCloneCmd(tp:="github") {
        return format("git clone {1} --depth 1", this.githubForClone()) ; --single-branch
    }

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
        if (instr(sNow,"?")) {
            ;obj["search"] :=  "?" . RegExReplace(sNow, ".*\?")
            obj["search"] :=  substr(sNow, instr(sNow,"?"))
            sNow := substr(sNow, 1, strlen(sNow)-strlen(obj["search"]))
        } else
            obj["search"] := ""
        ;剩余即是 pathname
        obj["pathname"] := rtrim(sNow, "/")
        ;hyf_objView(obj)
        return (strlen(key) && obj.has(key)) ? obj[key] : obj
    }

    ;删除网址多余部分
    urlClean() {
        objUrl := this.jsonUrl()
        if (objUrl["hostname"] == "www.bilibili.com") {
            if (instr(objUrl["pathname"], "/video/"))
                return objUrl["origin"] . RegExReplace(objUrl["pathname"], "^\/video\/\w+\K.*") ;. objUrl["search"]
            else
                return objUrl["href"]
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
            ;msgbox(json.stringify(m, 4))
            return strlen(m[3]) ? format("{1}?pwd={2}", m[1],m[3]) : m[1] ;2022年03月28日经胡杨介绍更新格式
        } else {
            if (RegExMatch(str, reg, &m))
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
            oBuf := buffer(strlen(str), 0)
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
    ; hyf_objView("八".getEncode("516B"))
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

    hyf_strForRegex(s) { ;字符串转换成原义匹配（正则时用）
        str := ".^$*+\?{}|()[]``" ;todo
        loop parse, s {
            if (A_LoopField = '"') ;"转成""
                r .= "" . A_LoopField
            else
                r .= instr(str, A_LoopField) ? "\" . A_LoopField : A_LoopField ;其他前置\
        }
        return r
    }

    */

}

;msgbox("d:\我.txt".encode())
;s := "U9数据字典V2.0SP1"
;msgbox(s.UrlEncode() . "`n" . s.uriEncode())
;msgbox("U9%E6%95%B0%E6%8D%AE%E5%AD%97%E5%85%B8V2%2E0SP1".uriDecode())
