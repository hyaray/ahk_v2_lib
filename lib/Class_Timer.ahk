;记录一次性定时器
;persistent
;_Timer.add("a", tips, funA, 1000)
;_Timer.add("b", tips, funB, 3000)
;_Timer.show()
;sleep(2000)
;_Timer.show()
class _Timer {
    ;每项[key, time_do, fun, tips, info]
    ;key 为标识，作为覆盖依据
    ;time_do 用来排序
    ;getData 返回[key, info]
    static ao := []

    static add(key, tips, fun, ms, info:="") {
        time_do := DateAdd(A_Now, ms//1000, "seconds")
        found := false
        obj := map(
            "key", key,
            "time_do", time_do,
            "fun", fun,
            "tips", tips,
            "info", info,
        )
        for o in this.ao {
            if (o["key"] == key) {
                found := true
                SetTimer(this.ao[A_Index]["fun"], 0) ;NOTE 删除 SetTimer
                this.ao[A_Index] := obj
                break
            }
        }
        if (!found)
            this.ao.push(obj)
        ;OutputDebug(format("i#{1} {2}:{3} this.ao={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,json.stringify(this.ao,4)))
        this.ao.sort((a,b)=>StrCompare(a["time_do"],b["time_do"]))
        ;OutputDebug(format("i#{1} {2}:{3} this.ao={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,json.stringify(this.ao,4)))
        SetTimer(fun, -ms)
    }

    static update() {
        new_ao := []
        now := A_Now
        for a in this.ao {
            ;OutputDebug(format("i#{1} {2}:{3} {4} {5}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,substr(now,9,6),substr(a[1],9,6)))
            if (StrCompare(now, a["time_do"]) < 0)
                new_ao.push(a)
        }
        this.ao := new_ao
    }

    static getCount() => this.ao.length

    ;不update
    static getData(idx:=1) {
        if (idx == 0)
            return this.ao.map((a)=>[a["key"],a["info"]])
        if (this.ao.length >= idx) {
            obj := this.ao[idx]
            return [obj["key"], obj["info"]]
        }
        return []
    }

    static getSeconds(idx:=1) {
        if (this.ao.length >= idx) {
            sec := DateDiff(this.ao[idx]["time_do"], A_Now, "seconds")
            OutputDebug(format("i#{1} {2}:{3} sec={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,sec))
            return sec
        } else {
            return 0
        }
    }

    static show(x:=0, y:=0) {
        this.update()
        str := "`n".join(this.ao.map((a)=>format("{1}|{2}: {3}", a["key"],a["info"],a["tips"])))
        cmToolTip := A_CoordModeToolTip
        CoordMode("ToolTip", "screen")
        tooltip(str, x,y, 9)
        CoordMode("ToolTip", cmToolTip)
    }

}
