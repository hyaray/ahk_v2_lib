﻿;多个数字的处理，可用 arr* 方式，使用 _Array 的功能
;NOTE 很多时候数字是当字符串用的，字符串不在此功能内
;复杂运算可用 thqby 的 NTLCalc

defprop := object.DefineProp.bind(number.prototype)
proto := _Number.prototype
for k in proto.OwnProps() {
    if (k != "__Class")
        defprop(k, proto.GetOwnPropDesc(k))
}

class _Number {

    highParam() => this >> 16
    lowParam() => this & 0xffff

    hasDialog() => WinGetStyle(this) & 0x08000000

    ;TODO 不靠谱
    ;hwnd 对应窗口是否弹框
    isDialog(hwndMain:=0) {
        ;过滤主窗口
        if (hwndMain && this == hwndMain)
            return false
        style := WinGetStyle(this)
        if !(style & 0x10000000) { ;不可见
            ;OutputDebug(format("i#{1} {2}:{3} style={4} not visible", A_LineFile,A_LineNumber,A_ThisFunc,style))
            return false
        }
        if (style & 0x80000000)
            return true
        ;if (style & 0x1000000) ;可最大化(不靠谱)
        ;    return false
        ;hParent := dllcall("GetParent", "Ptr",this) ;不靠谱，往往为0
        ;if (hParent) {
        ;    exe0 := WinGetProcessName(this)
        ;    try {
        ;        exe1 := WinGetProcessName(hParent)
        ;    } catch {
        ;        OutputDebug(format("i#{1} {2}:{3} this={4}, hParent={5} get exeName failed", A_LineFile,A_LineNumber,A_ThisFunc,this,hParent))
        ;        return false
        ;    } else {
        ;        OutputDebug(format("i#{1} {2}:{3} exe0={4},exe1={5}", A_LineFile,A_LineNumber,A_ThisFunc,exe0,exe1))
        ;        return (exe0 == exe1)
        ;    }
        ;} else {
        ;    OutputDebug(format("w#{1} {2}:{3} style={4} unknown", A_LineFile,A_LineNumber,A_ThisFunc,style))
        ;}
        return true
    }

    ;转大写金额
    ;作者：sikongshan
    ;更新日期：2022年09月14日
    ;限制：因为不涉及到大数值计算，可以到20位或者更高，但是中文转回阿拉伯的时候，超过17位数值则会有问题（受限于ahk计算），下次考虑拼接方式避免
    toAmount() {
        sNum := string(this)
        arrNum := StrSplit(sNum,".")
        if (strlen(arrNum[1])>17) ;设定20位，
            return sNum
        res:=""
        objNum := {0:"零",1:"壹",2:"贰",3:"叁",4:"肆",5:"伍",6:"陆",7:"柒",8:"捌",9:"玖"}
        objDanwu := {1:"元",2:"拾",3:"佰",4:"仟",5:"万",6:"拾",7:"佰",8:"仟",9:"亿",10:"拾",11:"佰",12:"仟",13:"兆",14:"拾",15:"佰",16:"仟",17:"万",18:"拾",19:"佰",20:"仟"}
        objDicimal := {1:"角",2:"分",3:"毫",4:"厘"}
        ;整数部分
        loop(strlen(arrNum[1]))
            res := objNum[substr(arrNum[1], -A_Index, 1)] . objDanwu[A_Index] . res
        loop 3 {
            res:=RegExReplace(res,"零(拾|佰|仟)","零")
            res:=RegExReplace(res,"零{1,3}","零")
            res:=RegExReplace(res,"零(?=(兆|亿|万|元))","")
            res:=RegExReplace(res,"亿零万","亿")
            res:=RegExReplace(res,"兆零亿","兆")
        }
        ;小数部分
        if(arrNum.length > 1) {
            DP := arrNum[2]
            res .= "零"
            loop parse, DP {
                A_LoopField
                if(A_Index>5)
                    break
                if(A_LoopField=0)
                    continue
                res .= format("{1}{2}", objNum[A_LoopField],objDicimal[A_Index])
            }
        } else {
            res .= "整"
        }
        return res
    }

    ;超过numA用 A-Z
    ;逆向见 _String.toNum(10)
    toABCD(numA:=10, bLower:=false) {
        if (this < numA)
            return string(this)
        else
            return chr(65+bLower*32-numA+this)
    }

    ;获取
    next {
        get => this+1
    }

    ;计算
    pidGetCommandLine() {
        for item in ComObjGet("winmgmts:").ExecQuery(format("Select * from Win32_Process where ProcessId={1}", this))
            return item.CommandLine
    }

    part(v, vOutRange:=0) {
        w := this ;一般是总宽
        if (v == 0)
            return 0
        if (v < 0) {
            if (v > -1) { ;小数点
                v := round(w * (1-abs(v)))
            } else {
                v := w - abs(v)
                if (v < 0)
                    v := vOutRange
            }
        } else if (v <= 1) { ;小数点 TODO 是否按小数点计算
            v := round(w * v)
        } else if (v > w) {
            v := vOutRange
        }
        return v
    }

    ;分区整数
    diskInt() {
        mb := this*1024
        ;return this*1024
        n := 7.84423828125
        return ceil(ceil(mb/n) * n)
    }

    ;用NTLCalc(str)
    floatErr() => number(string(round(this+0.00000001,6)).delete0())
    delete0() {
        if (integer(this) == this)
            return integer(this)
        return float(string(this).rtrim("0"))
    }

    ;左边填充0(补0)
    ;format("{:02s}", 1)
    zfill(l) => format(format("{:0{1}s}",l), string(this))

    mod1(num, m) => mod(num-1, m)+1

    toDPI() => integer(this*A_ScreenDPI/96)
    fromDPI() => integer(this*96/A_ScreenDPI)

    ;转换
    ;Excel的列号
    ;xl.ConvertFormula("R99C99", -4150,1)
    ;xl.ConvertFormula("AZ1000", 1,-4150)
    toCol() {
        num := this
        res := ""
        while (num) {
            md := mod(num-1,26) + 1
            res := chr(md+64) . res
            num := (num-md) // 26
        }
        return res
    }

    ;hwnd
    toRect() {
        WinGetPos(&x, &y, &w, &h, this)
        return [x,y,w,h]
    }

    ;123转成一二三(语音朗读用)
    toZh() {
        res := ""
        arr := ["零","一","二","三","四","五","六","七","八","九"]
        loop parse, string(this)
            res .= arr[A_LoopField+1]
        return res
    }

    ;xx:xx:xx.xxx
    ;msgbox(60.toTime())
    ;msgbox(61.toTime())
    ;msgbox(3600.toTime())
    ;msgbox(3601.toTime())
    toTime() {
        num := this
        point := mod(num, 1)
        num := integer(num)
        res := ""
        loop(3) {
            n := 60**(3-A_Index)
            if (num >= n) {
                res .= string(num // n) . ":"
                num := mod(num, n)
            } else if (res != "") {
                res .= "00:"
            }
        }
        return rtrim(res, ":")
    }

    ;转中文数字
    toZhnum() {
        num := this
        arrNum := ["一","二","三","四","五","六","七","八","九","十"]
        if (num <= 10)
            return arrNum[num]
        else if (num < 20) ;NOTE 避免 一十一
            return "十" . arrNum[mod(num,10)]
        arrYiWan := [
            [100000000, "亿"],
            [10000, "万"],
            [1, ""],
        ]
        res := ""
        for arr in arrYiWan {
            if (num >= arr[1]) {
                res .= format("{1}{2}", qian(num//arr[1],A_Index==1),arr[2])
                ;msgbox(res . "`num" . num . "`num" . arr[1] . "`num" . (num//arr[1]))
                num := mod(num, arr[1])
            }
        }
        return ltrim(res, "零")
        qian(num, trimBoth:=true) { ;处理万以内数字
            static arrQian := [
                [1000, "千"],
                [100, "百"],
                [10, "十"],
                [1, ""],
            ]
            resQian := ""
            for arr in arrQian {
                if (num >= arr[1]) {
                    resQian .= arrNum[num // arr[1]] . arr[2]
                    num := mod(num, arr[1])
                } else {
                    if (substr(resQian, -1) != "零")
                        resQian .= "零"
                }
            }
            resQian := trimBoth ? trim(resQian, "零") : rtrim(resQian, "零")
            if (substr(resQian,1,2) == "一十") ;NOTE 处理一十
                resQian := substr(resQian, 2)
            return resQian
        }
    }

    ;--------------------------进制转换--------------------------------
    ;其他进制可用十进制中转

    ;10进制转r进制，numA默认10(同16进制)
    d2r(r, numA:=10) {
        num := this
        obj := map()
        if (numA == 10) {
            loop(10)
                obj[A_Index-1] := A_Index-1
        }
        loop(26)
            obj.push(chr(64+A_Index))
        ;hyf_msgbox(obj)
        res := ""
        while(num > 0) {
            md := mod(num,r) ;逻辑和hyf_num2Column不一样
            res := obj[md] . res
            num := (num-md) // r
        }
        return res
    }

    d2b(r:=2) { ;十进制转2进制
        num := this
        res := ""
        while(num) {
            res := mod(num, r) . res
            num //= r
        }
        return res
    }

    d2h(tp:="") { ;十进制转16进制 ;以f为例，tp："":f，"X":F，"0xx":0xf, "0xX":0xF，"0Xx":"0Xf", "0XX":"0XF"
        if (tp = "")
            f := "{:x}"
        else if (tp == "X")
            f := "{:X}"
        else if (tp == "0xx")
            f := "0x{:x}"
        else if (tp == "0xX")
            f := "0x{:X}"
        else if (tp == "0Xx")
            f := "0X{:x}"
        else if (tp == "0XX")
            f := "0X{:X}"
        return format(f, this)
    }

}

class range {
    __new(start, end?, step:=1) {
        if !step
            throw TypeError("Invalid 'step' parameter")
        if (!isset(end)) {
            end := start
            start := 1
        }
        if (end < start) && (step > 0)
            step := -step
        this.start := start, this.end := end, this.step := step
    }

    __enum(varCount) {
        start := this.start - this.step
        end := this.end
        step := this.step
        counter := 0
        EnumElements(&element) {
            start := start + step
            if ((step > 0) && (start > end)) || ((step < 0) && (start < end))
                return false
            element := start
            return true
        }
        EnumIndexAndElements(&index, &element) {
            start := start + step
            if ((step > 0) && (start > end)) || ((step < 0) && (start < end))
                return false
            index := ++counter
            element := start
            return true
        }
        return (varCount = 1) ? EnumElements : EnumIndexAndElements
    }

}
;msgbox(30.toZhnum())
