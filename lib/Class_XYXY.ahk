;oXY := XYXY("A")
;msgbox(json.stringify(oXY.main(0,0.44, -5,0.55), 4))
class XYXY {

    ;tp 0=向内偏移 1=向外偏移
    __new(rect, var:=unset, tp:=0) {
        this.tp := tp
        if (isset(rect)) {
            if (rect is string || rect is integer) {
                WinGetPos(&winX, &winY, &winW, &winH, rect)
                this.wx := winX
                this.wy := winY
                this.ww := winW
                this.wh := winH
                this.rect := [winX,winY,winW,winH]
            } else if (rect is array) {
                this.wx := rect[1]
                this.wy := rect[2]
                this.ww := rect[3]
                this.wh := rect[4]
                this.rect := rect
            }
        }
        if (isset(var))
            this.var := var
    }

    ;NOTE 一般调用这个就行，
    main(args*) {
        switch args.length {
            case 1: return this.dealx(args[1]) ;默认x(获取y，手工调用 dealy)
            case 2: return [this.dealx(args[1]), this.dealy(args[2])]
            case 4: return [this.dealx(args[1]), this.dealy(args[2]), this.dealx(args[3]), this.dealy(args[4])]
            default: return this.dealx(args[1]) ;NOTE y则手工执行this.dealy
        }
    }

    ;支持批量处理x
    dealx(v:=unset, x:=unset, w:=unset) {
        ;支持传入和默认值
        if (!isset(v))
            v := this.var[1]
        if (v is array) ;NOTE 批量处理x
            return v.map((x)=>this.dealx(x))
        if (!isset(x)) {
            x := this.wx
            w := this.ww
        }
        return this._deal(v,x,w)
    }

    dealy(v:=unset, y:=unset, h:=unset) {
        ;支持传入和默认值，默认处理y，如果y需要手工传入值(this.y, this.wy, this.wh)
        if (!isset(v))
            v := this.var[2]
        if (v is array) ;NOTE 批量处理x
            return v.map((y)=>this.dealy(y))
        if (!isset(y)) {
            y := this.wy
            h := this.wh
        }
        return this._deal(v,y,h)
    }

    ;NOTE
    _deal(v, x, w) {
        if (v is float)
            v := round(w * v)
        if (this.tp == 0)
            res := x + w*(v<0) + v
        else
            res := x + w*(v>0) + v
        return res
    }

}
