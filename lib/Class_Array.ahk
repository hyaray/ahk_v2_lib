;AutoHotkey原生不支持对象，都要new才能用，所以用工具类更合适
;如何判断二维数组 arr[1] is array?
;默认都是不修改原arr，方法内都会clone()并操作
;除了方法名以r开头的会修改原arr，且无返回值(rMoveDown)
;ip 1.2 转成 192.168.1.2
;NOTE map 方法已自带，参数是(v,k)，注意区分 map 的返回值和被 map 修改之后的 arr
;arr.map(xxx) 命令运行之后，arr 已经被修改了
;arr := arr.map(xxx) 加了赋值，这是 map 的函数返回值拼接的结果
;提取二维数组的第1项组成一维数组
;arr2.map((a)=>a[1])
;内置方法
;   arr.indexOf(val, start_index:=1)
;   arr.FindIndex(callback: (value [, index]) => Boolean, start_index := 1)
;   arr.join(",")
;   arr.filter((v)=>v == 2) 返回true的保留，python和js也都是此逻辑
;   arr.sort(callback?: (a, b) => Integer) => $this 修改原数组，示例: arr.sort((a,b)=>a[2]-b[2])


; https://autohotkey.com/board/topic/83081-ahk-l-customizing-object-and-array
defprop := object.DefineProp.bind(array.prototype)
proto := _Array.prototype
for k in proto.OwnProps() {
    if (k != "__Class")
        defprop(k, proto.GetOwnPropDesc(k))
}

class _Array extends Array {

    toString() => this.toJson()

    ;只处理第1级
    ;如果fitOutdebug，则前面增加换行符让调试信息更整齐
    toString1(fitOutdebug:=false) {
        if (!this.length)
            return ""
        if (this.length == 1)
            return json.stringify(this[1])
        res := json.stringify(this[1])
        if (fitOutdebug)
            res := "`n" . res
        for obj in this {
            if (A_Index > 1)
                res .= "`n" . json.stringify(obj)
        }
        return res
    }

    ;暂时只支持2维
    ;第2维长度只看第1个值
    size() {
        if (!this.length)
            return [0]
        res := [this.length]
        if (this[1] is array)
            res.push(this[1].length)
        return res
    }

    ;只支持一维数组，普通值对比
    equal(arr) {
        if (this.length != arr.length)
            return false
        for v in this {
            if (v != arr[A_Index])
                return false
        }
        return true
    }

    toArr2() {
        if (!this.length)
            return this
        if (this[1] is array)
            return this
        arr := this
        arr2 := []
        if (!isobject(arr[1])) {
            for v in arr
                arr2.push([v])
        } else if (arr[1] is map) { ;NOTE map
            for obj in arr {
                i := A_Index
                arr[i] := []
                for k,v in obj ;TODO k 是否要获取
                    arr2[i].push(v)
            }
        }
        return arr2
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

    ;删除重复
    unique() {
        arr := []
        obj := map()
        for v in this {
            if (obj.has(v))
                continue
            arr.push(v)
            obj[v] := 1
        }
        return arr
    }

    deleteEmpty() {
        arr := []
        for v in this {
            if (v != "")
                arr.push(v)
        }
        return arr
    }

    ;二维数组，删除第n列
    delete(c) {
        arr2 := this
        for arr in arr2
            arr.RemoveAt(c)
        return arr2
    }

    extend(arr) {
        arr0 := this
        for v in arr
            arr0.push(v)
        return arr0
    }

    ;不要最后一个 end=-1
    ;切片功能
    slice(start:=1, end:=0, step:=1) {
        len := this.length
        i := start < 1 ? len + start : start
        if (i < 1 || i > len)
            return []
        j := end < 1 ? len + end : end
        if (j < i || j > len)
            return []
        arrRes := []
        reverse := false
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

    toMapAsKey(val:="") {
        obj := map()
        for v in this
            obj[v] := val
        return obj
    }

    ;arr2 转成字典数组
    ;[ [A1,B1], [A2,B2] ] [title1, title2]
    ;返回[
    ;    map("title1",A1, "title2",B1),
    ;    map("title1",A2, "title2",B2),
    ;]
    ;
    ;[A1,B1], [title1, title2]
    ;返回    map("title1",A1, "title2",B1)
    toMapEx(arrTitle) {
        arrRes := []
        if (this[1] is array) {
            for arr in this {
                obj := map()
                for v in arr {
                    if isset(v) ;过滤null
                        obj[arrTitle[A_Index]] := v
                }
                arrRes.push(obj)
            }
            return arrRes
        } else {
            obj := map()
            for v in this {
                if isset(v) ;过滤null
                    obj[arrTitle[A_Index]] := v
            }
            return obj
        }
    }

    ;目前只在 _Pwd 里使用(用于给每行做索引)
    ;[ [A1,B1], [A2,B2] ] [title1, title2]
    ;{
    ;    title1 : [A1,B1],
    ;    title2 : [A2,B2],
    ;}
    toMapByArray(arrTitle:=unset) {
        arr := this
        obj := map()
        if (isset(arrTitle)) {
            if (arrTitle is array) {
                for v in arr ;TODO 是否判断长度
                    obj[arrTitle[A_Index]] := v
            } else if (arrTitle == 0) { ;当 key
                for v in this
                    obj[v] := A_Index
            } else if (arrTitle == 1) { ;当 value
                for v in this
                    obj[A_Index] := v
            }
        } else {
            for v in this
                obj[A_Index] := v
        }
        return obj
    }

    ;funDistinct 返回值当 key 用来筛选
    ;参数都是(v,k)
    ;arr.filter2((v,k)=>v[1]!="", (v,k)=>v[1])
    filter2(fun, funDistinct:=unset) {
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
            res := fun(res, arr[idx+A_Index])
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
                for v in arrTitle {
                    if (isobject(map1[v])) {
                        switch type(map1[v]) {
                            case "Array":
                                vThis := map1[v].toJson()
                            case "Map":
                                vThis := "{}"
                            default:
                                vThis := format("{{1}}", type(map1[v]))
                        }
                    } else {
                        vThis := map1[v]
                    }
                    res .= vThis . charItem
                }
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

    ;参考python的 sorted
    ;用map的key来排序，没有过滤功能
    ;NOTE reverse还要考虑相同值的情况，是否也要倒序，如下示例的，2的两项顺序
    ;arr2 := [
    ;    [2, 3], 
    ;    [2, 4], 
    ;    [3, "b"],
    ;    [1, "c"],
    ;]
    sorted(fun, reverse:=0) {
        oa := map()
        for o in this {
            k := fun(o)
            if (oa.has(k))
                oa[k].push(o)
            else
                oa[k] := [o]
        }
        arrRes := []
        for k, ao in oa {
            switch reverse {
                case 0:
                    arrRes.extend(ao)
                case 1: ;内部 o 正序
                    arrRes := ao.extend(arrRes)
                case 2: ;内部 o 倒序
                    loop (ao.length)
                        arrRes.push(ao[-A_Index])
            }
        }
        return arrRes
    }

    ;递归平铺所有内容(删除文件夹)
    ;每项是 map，如果含 keySub 则递归读取其下的内容(比如hyobj)
    ;每项是 array，如果为 map 则递归读取其下的内容(比如yaml)
    static noBranch(arr, keySub:="") {
        if (!arr.length)
            return []
        arrRes := []
        if (arr[1] is map) {
            if (keySub == "")
                throw ValueError("keySub 未定义")
            for obj in arr {
                if (obj.has(keySub)) ;为目录
                    arrRes.extend(this.noBranch(obj[keySub],keySub)) ;NOTE 递归
                else {
                    arrRes.push(obj)
                }
            }
        } else if (arr[1] is array) {
            for arr1 in arr {
                if (arr1 is map) { ;为目录
                    for k1, v1 in arr1 {
                        if (v1 is array) {
                            arrRes.extend(this.noBranch(v1))
                        } else if (v1 is string) {
                            msgbox(v1) ;TODO
                        } else {
                            msgbox(type(v1))
                        }
                    }
                } else {
                    arrRes.push(arr1)
                }
            }
        }
        return arrRes
    }

    ;参考 noBranch 的场景
    ;对每个 item 进行处理
    ;map 只是无脑对 item 进行处理，这个增加了对子目录 item 的处理
    mapEx(funDeal) {
        return f(this)
        f(arr) {
            arrRes := []
            for item in arr {
                if (item is map) { ;NOTE 判断为目录
                    for k1, v1 in item
                        arrRes.push(this.mapEx(v1, funDeal)) ;NOTE 递归
                } else if (item is array) {
                    arrRes.push(funDeal(item)) ;NOTE 是函数返回值，而不是修改后的 item
                } else if (item is string) {
                    msgbox(item)
                }
            }
            return arrRes
        }
    }

    ;提取对象的所有key对应的值到数组
    ;比如多个map("key","aaa","hotkey","B")组成数据
    ;提取所有key的值aaa到数组
    static oValueOfKey2Arr(arr, subKey, key) {
        arrRes := []
        tmp(arr, subKey, key)
        return arrRes
        tmp(arr, subKey, key) {
            for v in arr {
                if (v.has(subKey))
                    tmp(v[subKey], subKey, key)
                else if (v.has(key))
                    arrRes.push(v[key])
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
        arr.RemoveAt(arr.indexOf(value))
    }

    ;[[1,2],[3,4]]转为[1,2,3,4]
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

    ;v1移到v0后
    moveAfterValue(v1, v0) {
        arr := this
        i1 := arr.indexOf(v1)
        if (!i1)
            throw ValueError(format("{1}不在数组内", v1))
        i0 := arr.indexOf(v0)
        if (!i0)
            throw ValueError(format("{1}不在数组内", v0))
        arr.RemoveAt(i1)
        arr.InsertAt(i0+1, v1)
        return arr
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

    ;遍历所有元素的排列组合，返回二维数组
    ;比如[1,2,3] 生成6种
    traverseGroups() {
        arr := this
        switch arr.length {
            case 1:
                return [arr]
            case 2:
                return [arr, [arr[2],arr[1]]]
            default:
                item := arr.pop()
                arr1 := this.traverseGroups()
                arr2 := []
                for a in arr1 {
                    loop (a.length) { ;item 插入a的n个位置
                        i := A_Index
                        aTmp := []
                        for v in a {
                            if (A_Index == i)
                                aTmp.push(item)
                            aTmp.push(v)
                        }
                        arr2.push(aTmp)
                    }
                    ;msgbox(json.stringify(arr2, 4))
                    ;最后再加一种情况
                    a.push(item)
                    arr2.push(a)
                }
                return arr2
        }
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
