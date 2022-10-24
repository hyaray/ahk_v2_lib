;AutoHotkey原生不支持对象，都要new才能用，所以用工具类更合适
;默认都是不修改原arr，方法内都会clone()并操作
;除了方法名以r开头的会修改原arr，且无返回值(rMoveDown)
;ip 1.2 转成 192.168.1.2

; https://autohotkey.com/board/topic/83081-ahk-l-customizing-object-and-array
defprop := object.DefineProp.bind(array.prototype)
proto := _Array.prototype
for k in proto.OwnProps() {
    if (k != "__Class")
        defprop(k, proto.GetOwnPropDesc(k))
}

class _Array extends Array {

    static __new() {
        defprop := {}.DefineProp.bind(super.prototype)
        proto := this.prototype
        for k in proto.OwnProps() {
            if (k != "__Class")
                defprop(k, proto.GetOwnPropDesc(k))
        }
    }

    toString() {
        return this.toJson()
    }

    ;获取
    count(value) {
        res := 0
        for v in this {
            if (v = value)
                res++
        }
        return res
    }

    index(value) {
        for k, v in this {
            if (v = value)
                return k
        }
        return 0
    }

    hasValue(value) {
        return this.index(value) > 0
    }

    extend(arr) {
        arr0 := this
        for v in arr
            arr0.push(v)
        return arr0
    }

    slice(start:=1, end:=0, step:=1) {
        len := this.length
        i := start < 1 ? len + start : start
        j := end < 1 ? len + end : end
        arrRes := []
        reverse := false
        if (i < 1 || j > len)
            throw IndexError("Slice: start or end value out of bounds", -1)
        if step = 0 {
            throw error("Slice: step cannot be 0",-1)
        } else if step < 0 {
            if i < j
                throw error("Slice: if step is negative then start value must be greater than end value", -1)
            while i >= j {
                arrRes.push(this[i])
                i += step
            }
        } else {
            if (i > j)
                throw error("Slice: start value must be smaller than end value", -1)
            while (i <= j) {
                arrRes.push(this[i])
                i += step
            }
        }
        return arrRes
    }

    reverse() {
        arrRes := []
        loop(this.length)
            arrRes.push(this[-A_Index])
        return arrRes
    }

    toMap(arrKey:=unset) {
        arr := this
        obj := map()
        if (isset(arrKey)) {
            for v in arr ;TODO 是否判断长度
                obj[arrKey[A_Index]] := v
        } else {
            for v in this
                obj[A_Index] := v
        }
        return obj
    }

    ;参考 python
    ;每个元素根据fun处理
    map(fun) {
        arr := this
        for v in arr
            arr[A_Index] := fun.call(v)
        return arr
    }

    ;funDistinct 返回值当 key 用来筛选
    ;参数都是(v,k)
    ;arr.filter((v,k)=>v[1]!="", (v,k)=>v[1])
    filter(fun, funDistinct:=unset) {
        arrRes := []
        if (!isset(funDistinct)) {
            for k, v in this {
                if (fun(k, v))
                    arrRes.push(v)
            }
        } else {
            obj := map()
            for k, v in this {
                key := funDistinct(v,k)
                if (fun(v,k) && !obj.has(key)) {
                    arrRes.push(v)
                    obj[key] := ""
                }
            }
        }
        return arrRes
    }

    reduce(fun, v0:=unset) {
        arr := this
        if (!isset(v0)) {
            if (!arr.length)
                throw TypeError("错误：空数组，且未传入参数")
            idx := 1
            res := arr[1]
        } else {
            idx := 0
            res := v0
        }
        loop(arr.length-idx)
            res := fun.call(res, arr[idx+A_Index])
        return res
    }

    ;转成表格字符串(方便查看)
    ;NOTE 数据结构要统一
    /*
    arr := [
        [1,2],
        [3,4],
    ]
    或
    arr := [
        map(
            "a",1,
            "b",2,
        ),
        map(
            "a",3,
            "b",4,
        ),
    ]
    */
    toTable(charItem:="`t", arrKey:=unset) {
        arr := this
        if (!arr.length)
            return ""
        res := ""
        if (arr[1] is array) {
            for arr1 in arr {
                for v in arr1 {
                    if isobject(v)
                        res .= "{}" . charItem
                    else
                        res .= v . charItem
                }
                res := rtrim(res, charItem) . "`n"
            }
        } else if (arr[1] is map) {
            ;arrTitle
            if isset(arrKey) {
                arrTitle := arrKey
            } else {
                arrTitle := []
                for k, v in arr[1]
                    arrTitle.push(k)
            }
            res := arrTitle.join(charItem) . "`n"
            ;data
            for map1 in arr {
                for v in arrTitle
                    res .= map1[v] . charItem
                res := rtrim(res, charItem) . "`n"
            }
        }
        return rtrim(res, "`n")
    }

    sum() {
        res := 0
        for v in this
            res += v
        return res
    }

    sort(arr, tp:="") { ;默认升序，D为降序
        obj := map()
        obj.default := 0
        for v in arr
            obj[v]++
        arrRes := []
        if (tp == "") {
            for k, v in obj {
                loop(v)
                    arrRes.push(k)
            }
        } else if (tp = "D") {
            for k, v in obj
                arrRes.insertat(1, v)
        }
        return arrRes
    }

    ;提取对象的所有key对应的值到数组
    ;比如多个map("key","aaa","hotkey","B")组成数据
    ;提取所有key的值aaa到数组
    static oValueOfKey2Arr(arr, subKey, key) {
        this.arrRes := []
        tmp(arr, subKey, key)
        return this.arrRes
        tmp(arr, subKey, key) {
            for k, v in arr {
                if (v.has(subKey))
                    tmp(v[subKey], subKey, key)
                else if (v.has(key))
                    this.arrRes.push(v[key])
            }
        }
    }

    ;如果arrKeyValue为["hotkey", "H"]，则删除obj.hotkey为"H"的obj
    static oRemoveByKey(arr, arrKeyValue) {
        arrNew := arr.clone()
        for k, v in arrNew {
            if (v[arrKeyValue[1]] = arrKeyValue[2])
                arrNew.RemoveAt(k)
        }
        return arrNew
    }

    static oRemoveByValue(arr, value) { ;删除第一个对应的key
        arr.RemoveAt(arr.index(value))
    }

    ;[1,2,[3,4]]转为[1,2,3,4]
    static oArrTwo2Arr(arr) { ;2维转成1维数组
        arrRes := []
        for k, v in arr {
            if (isobject(v)) {
                for k1, v1 in v
                    arrRes.push(v1)
            } else {
                arrRes.push(v)
            }
        }
        return arrRes
    }

    ;sum {
    ;    get => this.sum()
    ;}

    ;修改行，列，参考 numpy
    ;msgbox(json.stringify([1,2,3,4,5,6].reshape(2,3)))
    reshape(rs, cs) {
        arr := this
        if (arr.length == 0)
            return []
        arrRes := [[]]
        i := 0
        r := 1
        if (arr[1] is array) { ;二维数组
            for arr1 in arr {
                for v in arr1 {
                    i++
                    addRecord(v)
                }
            }
        } else {
            for v in arr {
                i++
                addRecord(v)
            }
        }
        return arrRes
        addRecord(v) {
            if (arrRes[r].length == cs) {
                arrRes.push([v])
                r++
            } else
                arrRes[r].push(v)
        }
    }

    moveDown(arr, idx) {
        arrNew := arr.clone()
        if (idx>0 && idx<arrNew.length) {
            obj := arrNew[idx]
            arrNew.RemoveAt(idx)
            arrNew.insertat(idx, obj)
        }
        return arrNew
    }

    moveUp(arr, idx) {
        arrNew := arr.clone()
        if (idx > 1) {
            obj := arr[idx]
            arr.RemoveAt(idx)
            arr.insertat(idx-1, obj)
        }
        return arrNew
    }

    rMoveUp(arr, idx) {
        if (idx > 1) {
            obj := arr[idx]
            arr.RemoveAt(idx)
            arr.insertat(idx-1, obj)
        }
    }

    rMoveDown(arr, idx) {
        if (idx>0 && idx<arr.length) {
            obj := arr[idx]
            arr.RemoveAt(idx)
            arr.insertat(idx, obj)
        }
    }

    ;原数组也会被改
    removeByValue(value) { ;删除第一个对应的key
        for k, v in this {
            if (v = value) {
                this.RemoveAt(k)
                return this
            }
        }
        return this
    }

    /*
    removeByArrValue() {
        arrNew := arr.clone()
        arrFilter := this.sortD(arrFilter)
        for k, v in arrFilter
            arr.RemoveAt(v)
        return arr
    }
    */

    /*
    slice(start, l:="") { ;提取
        if (l = "") ;默认全部
            l := arr.length - start + 1
        else if (l > arr.length - start + 1)
            throw "l无效"
        arrRes := []
        loop(l)
            arrRes.push(arr[start+A_Index-1])
        return arrRes
    }
    */

    ;获取num的mod值
    arr2Mod(arr, num) {
        arrRes := []
        for k, v in arr
            arrRes.push(mod(v, num))
        return arrRes
    }

    ;每个项目的第1项增加序号[[1,8],[2,7]]
    addIndex(arr) {
        arrNew := []
        for k, v in arr
            arrNew.push([A_Index, v])
        return arrNew
    }

    ;arrBase为[1,2,3,4]
    ;arr为[6,7]，则返回[1,2,6,7]
    mergeRight(arrBase) {
        arr := this
        if (!arr.length)
            return arrBase
        if (arrBase.length = arr.length)
            return arr
        loop(arr.length)
            arrBase[-A_Index] := arr[-A_Index]
        return arrBase
    }
    mergeLeft(arrBase) {
        arr := this
        if (!arr.length)
            return arrBase
        if (arrBase.length = arr.length)
            return arr
        for v in arr
            arrBase[A_Index] := v
        return arrBase
    }

    ;转成字符串，带key . A_Tab
    joinWithKey(charKey:="`t", charEnd:="`n") {
        arr := this
        res := ""
        for k, v in arr
            res .= k . charKey . v . charEnd
        return RTrim(res, charEnd)
    }

    ;arr[1]为基准，数字+1，统计缺少的项
    ;如果少4,5,6,7则合并成4-7
    ;Objects有同名方法
    joinNumLost(arr) {
        if (!arr.length)
            return
        numSave := arr[1]
        res := [] ;记录缺失数字
        for v in arr {
            if (A_Index > 1 && v > numSave + 1) {
                if (v-numSave == 2)
                    res.push(numSave+1)
                else
                    res.push((numSave+1) . "-" . (v-1))
            }
            numSave := v
        }
        return res
    }

    ;----------------------arr每项都是obj--------------------------

    ;比如获取arr[n] = map("a",v1, "b",v1)里键b的值为3的序号n，则函数参数为(obj, "b", 3)
    oGetIndexByKeyValue(obj, key, value) {
        for k, v in obj
            if (v[key] = value)
                return k
    }

    ;根据key,value获取二维数组的两个索引，返回数组
    ;比如获取obj[m][n] = map("a",x1, "b",y1)里键b的值为3的序号[m,n]，则函数参数为(obj, "b", 3)
    getArrIndexByKeyValue(obj, key, value) {
        for k1, v1 in obj {
            for k2, v2 in v1 {
                if (v2[key] = value)
                    return [k1,k2]
            }
        }
    }

    ;每项包括oldKey的对象添加newKey，值为newValue(可以用%key%替换obj[key](优先)或%key%变量值)
    ;比如给obj添加icon项，值为"d:\QQ\%Value%.jpg")
    oObjAddKey(subKey, newKey, newValue) {
        arrRes := this.clone()
        return tmp(arrRes, subKey, newKey, newValue)
        tmp(arr, subKey, newKey, newValue) {
            for k, v in arr {
                if (v.has(subKey))
                    v[subKey] := tmp(v[subKey], subKey, newKey, newValue)
                else
                    v[newKey] := this.oKeyVar2Str(newValue, v) ;字符串替换
            }
            return arr
        }
    }

    ;把%var%转换成obj[var]的值
    ;比如%key%.jpg，value转成obj[key]
    oKeyVar2Str(str, obj) {
        global
        reg := "(.*?)%(\w+)%(.*)"
        startPos := 1
        loop {  ;有变量
            p := RegExMatch(str, reg, &m, startPos)
            if (p) {
                if (obj.has(m[2])) {
                    val := obj[m[2]]
                    startPos := m.pos(2)+ strlen(val) - 1
                    str := substr(str,1,p-1) . m[1] . val . m[3]
                } else {
                    startPos := m.pos(2)+ strlen(val) + 1
                    str := substr(str,1,p-1) . m[1] . "%" . val . "%" . m[3]
                }
            } else {
                return str
            }
        }
    }

    ;比如多个map("key","key1","hotkey","B")组成的1维数组
    oSort(arr, key, tp:="") { ;默认升序，D为降序
        obj := map() ;记录
        for k, v in arr {
            keySort := v[key]
            if (obj.has(keySort)) ;已有结果
                obj[keySort].push(v)
            else
                obj[keySort] := [v]
        }
        arrRes := []
        for k, v in obj {
            for k1, v1 in v
                arrRes.push(v1)
        }
        return arrRes
    }

}

;arr := [
;    map(
;        "a",1,
;        "sub", map(
;            "a",11,
;        )
;    ),
;    map(
;        "b",2,
;        "sub", map(
;            "b",22,
;        )
;    ),
;]
;arr := [
;    ["a","aa","aaa"],
;    ["b","bb","bbb"],
;]
;msgbox(["a","b"].filter((x)=>instr(x, "b")))
;msgbox(string(arr))
;msgbox([1,2])
