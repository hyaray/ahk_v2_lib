;多个数字的处理，可用 arr* 方式，使用 _Array 的功能
;NOTE 很多时候数字是当字符串用的，字符串不在此功能内
;复杂运算可用 thqby 的 NTLCalc

defprop := object.DefineProp.bind(number.prototype)
proto := _Number.prototype
for k in proto.OwnProps() {
    if (k != "__Class")
        defprop(k, proto.GetOwnPropDesc(k))
}

class _Number {

    ;获取
    next {
        get => this+1
    }

    ;计算
    pidGetCommandLine() {
        for item in ComObjGet("winmgmts:").ExecQuery(format("Select * from Win32_Process where ProcessId={1}", this))
            return item.CommandLine
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
    delete0() => string(this).delete0()

    ;左边填充0
    zfill(l) => format(format("{:0{1}s}",l), string(this))

    mod1(num, m) => mod(num-1, m)+1

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

    toRectAsHwnd() {
        WinGetPos(&x, &y, &w, &h, "ahk_id " . this)
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
        ;hyf_objView(obj)
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
