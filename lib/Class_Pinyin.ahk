;msgbox(_Pinyin("A1").main("为你好"))
;msgbox(json.stringify(_Pinyin("a").obj["为"], 4))
;timeSave := A_TickCount
;_Pinyin("B1")
;msgbox(A_TickCount - timeSave)

class _Pinyin {

    static closure(tp) {
        oPinyin := _Pinyin(tp) ;NOTE oPinyin初始化比较费时，所以打包进来利用
        return (x)=>oPinyin.main(x)
    }

    ;static regAlpha := "[āáǎàōóǒòēéěèīíǐìūúǔùǖǘǚǜ]"

    ;obj["为"] = ["wei2", wei1]
    ;tpAlpab 以 hān 为列
    ;    a = h
    ;    A = H
    ;   aa = han
    ;   Aa = Han
    ;   a0 = hān
    ;   A0 = Hān
    ;   a1 = han1
    ;   A1 = Han1
    __new(tpAlpha:="Aa", toObj:=true) {
        SplitPath(A_LineFile,, &dir)
        this.sFile := rtrim(fileread("d:\TC\soft\AutoHotkey\lib\pinyin.txt","utf-8"),"`r`n")
        objTmp := map(
            "ā","a1", "á","a2", "ǎ","a3", "à","a4",
            "ō","o1", "ó","o2", "ǒ","o3", "ò","o4",
            "ē","e1", "é","e2", "ě","e3", "è","e4",
            "ī","i1", "í","i2", "ǐ","i3", "ì","i4",
            "ū","u1", "ú","u2", "ǔ","u3", "ù","u4",
            "ǖ","v1", "ǘ","v2", "ǚ","v3", "ǜ","v4",
        )
        if (instr(tpAlpha,"_")) {
            this.char := " "
            tpAlpha := StrReplace(tpAlpha, "_")
        } else {
            this.char := ""
        }
        switch strlen(tpAlpha) {
            case 1: ;删除音标
                this.sFile := RegExReplace(this.sFile, "\s.\K\S*") ;删除多余的内容
                this.sFile := RegExReplace(this.sFile, "(\s(.))(\s\2)+", "$1") ;NOTE 删除多音字重复的声母
                for sd, a1 in objTmp
                    this.sFile := RegExReplace(this.sFile, sd, substr(a1,1,1))
            case 2:
                if (substr(tpAlpha, 2, 1) != "0") { ;非 ā模式
                    for sd, a1 in objTmp
                        this.sFile := RegExReplace(this.sFile, sd . "(\w*)", format("{1}$1{2}", substr(a1,1,1),substr(a1,2,1)))
                }
                if (substr(tpAlpha, 2, 1) == "a")
                    this.sFile := RegExReplace(this.sFile, "\d")
        }
        ;转大写
        timeSave := A_TickCount
        if (substr(tpAlpha,1,1) ~= "[A-Z]")
            this.sFile := RegExReplace(this.sFile, "\s\K([a-z])", "$U1")
        if (toObj) {
            this.obj := map() ;汉字和拼音对照表
            loop parse, this.sFile, "`n", "`r" {
                arr := StrSplit(A_LoopField, "`t")
                this.obj[arr[1]] := StrSplit(arr[2]," ")
            }
        }
        OutputDebug(format("i#{1} {2}:oPinyin time={3}", A_LineFile,A_LineNumber,A_TickCount - timeSave))
        ;msgbox(json.stringify(this.obj, 4))
    }

    main(str) { ;获取全拼
        if (str == "")
            return
        res := ""
        loop parse, str {
            if (A_LoopField ~= "[[:ascii:]]") {
                res .= A_LoopField
            } else {
                if this.HasOwnProp("obj") {
                    if (this.obj.has(A_LoopField)) {
                        res .= this.obj[A_LoopField][1] . this.char ;NOTE 只能取第1个
                    } else { ;一般不会
                        res .= A_LoopField . this.char
                    }
                } else {
                    if (RegExMatch(this.sFile, A_LoopField . "\s(\S+)", &m)) { ;只提取第1个
                        res .= m[1] . this.char
                    } else { ;一般不会
                        res .= A_LoopField . this.char
                    }
                }
            }
        }
        return rtrim(res, this.char)
    }

    ;判断拼音是否有效
    ;比如yuan 或 yuan1
    check(pinyin) {
        pinyin := StrLower(pinyin)
        if (pinyin ~= "\d") { ;有声调
            pinyin := this.toSd(pinyin)
            return instr(this.sFile, pinyin)
        } else {
            reg := format("\s{1}(\s|$)", pinyin.toReg())
            res := (this.sFile ~= reg)
            ;if !res
            ;    msgbox(reg . "`n" . res . "`n" . substr(this.sFile, res, 9))
            return res
        }
    }

    ;拼音转成正则
    ;xuan → xu[āáǎàa]n
    ;可指定 sd
    toReg(pinyin, sd:=0) {
        pinyin := StrLower(pinyin)
        if (instr(pinyin, "a"))
            return sd==0 ? StrReplace(pinyin,"a","[āáǎàa]") : StrReplace(pinyin,"a",substr("āáǎàa",sd,1))
        if (instr(pinyin, "o"))
            return sd==0 ? StrReplace(pinyin,"o","[ōóǒòo]") : StrReplace(pinyin,"o",substr("ōóǒòo",sd,1))
        if (instr(pinyin, "e"))
            return sd==0 ? StrReplace(pinyin,"e","[ēéěèe]") : StrReplace(pinyin,"e",substr("ēéěèe",sd,1))
        if (pinyin ~= "[iu]") {
            loop(strlen(pinyin)) { ;逆向遍历
                char := substr(pinyin, -A_Index, 1)
                switch char {
                case "i":
                    return sd==0 ? StrReplace(pinyin, char, "[īíǐìi]") : StrReplace(pinyin, char, substr("īíǐìi", sd, 1))
                case "u":
                    return sd==0 ? StrReplace(pinyin, char, "[ūúǔùu]") : StrReplace(pinyin, char, substr("ūúǔùu", sd, 1))
                }
            }
        } else { ;ü
            return sd==0 ? StrReplace(pinyin, "ü", "[ǖǘǚǜü]") : StrReplace(pinyin, "ü", substr("ǖǘǚǜü", sd, 1))
        }
    }

    ;拼音转成声调
    ;xuan1 → xuān
    toSd(pinyin) {
        pinyin := StrLower(pinyin)
        sd := (pinyin ~= "\d") ? RegExReplace(pinyin, "\D") : 5
        if (instr(pinyin, "a"))
            return StrReplace(pinyin, "a", substr("āáǎàa", sd, 1))
        if (instr(pinyin, "o"))
            return StrReplace(pinyin, "o", substr("ōóǒòo", sd, 1))
        if (instr(pinyin, "e"))
            return StrReplace(pinyin, "e", substr("ēéěèe", sd, 1))
        if (pinyin ~= "[iu]") {
            loop(strlen(pinyin)) { ;逆向遍历
                char := substr(pinyin, -A_Index, 1)
                switch char {
                case "i":
                    return StrReplace(pinyin, char, substr("īíǐìi", sd, 1))
                case "u":
                    return StrReplace(pinyin, char, substr("ūúǔùu", sd, 1))
                }
            }
        } else { ;ü
            return StrReplace(pinyin, "ü", substr("ǖǘǚǜü", sd, 1))
        }
    }

    ;判断拼音有哪些声调
    ;for cell in ox().selection {
    ;    if (cell.value == "")
    ;        continue
    ;    arr := cell.value.toArrSd()
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
    toArrSd(pinyin) {
        pinyin := StrLower(pinyin)
        arr := []
        loop(5) {
            reg := format("\s{1}(\s|$)", this.toReg(A_Index))
            if (this.sFile ~= reg)
                arr.push(A_Index)
        }
        return arr
    }

}
