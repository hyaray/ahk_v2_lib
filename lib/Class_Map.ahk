;不修改原obj
;优先使用Arrays
;连续的 key 保存在 arr里，如何用arr:=["a","b"]一次性引用=obj["a"]["b"]
;TODO CDP返回的map，key有顺序，ahk如何实现？

;v1 https://www.autohotkey.com/board/topic/83081-ahk-l-customizing-object-and-array
defprop := object.DefineProp.bind(map.prototype)
proto := _Map.prototype
for k in proto.OwnProps() {
    if (k != "__Class")
        defprop(k, proto.GetOwnPropDesc(k))
}

class _Map extends map {
    ;CaseSense := 0
    ;Default := ""

    ; i同array的序号
    _index(isValue:=0, i:=-1) {
        e := this.__enum()
        i := (i < 0) ? this.count-1+i : i-2
        numput("uint", i, objptr(e), 6*A_PtrSize+16)
        e(&k:=0)
        return isValue ? this[k] : k
    }

    ;参考python
    ;如果指定了i，则返回对应序号的k
    ;TODO 如何自定义顺序
    keys(i:=unset) {
        if (isset(i))
            return this._index(0, i)
        arr := []
        for k, v in this
            arr.push(k)
        return arr
    }
    values(i:=unset) {
        if (isset(i))
            return this._index(1, i)
        arr := []
        for k, v in this
            arr.push(v)
        return arr
    }

    ;通过数组来获取值
    getEx(arr, default:="") {
        if !(arr is array)
            arr := [arr]
        if (!arr.length)
            return this
        obj := this
        for v in arr {
            if (obj.has(v)) {
                obj := obj[v]
            } else {
                obj := default
                break
            }
        }
        return obj
    }

    ;TODO CDP返回的map，key有顺序，ahk如何实现？
    cloneEx() {
        obj := map()
        for k, v in this
            obj[k] := v
        return obj
    }

    ;转成二维数组(参考python)
    items() {
        arr := []
        for k, v in this
            arr.push([k, v])
        return arr
    }

    ;遍历 arr，看是否包含
    hasEx(arr) {
        for v in arr {
            if this.has(v)
                return v
        }
        return ""
    }
    ;obj的值覆盖this
    ;名称来源python
    update(obj) {
        for k, v in obj
            this[k] := v
        return this
    }

    ;添加 obj 中不存在的键
    extend(obj) {
        for k, v in obj {
            if (!this.has(k))
                this[k] := v
        }
        return this
    }

    toString() => super.toJson()

    ;arrKey 分别为 key [前,后,每个key之间]的符号定义
    ;arrValue 分别为 value [前,后]的符号定义
    /*
    比如 obj := map(
        "a", [a1,a2],
        "b", [b3,b4],
    )
    转成 2 级markdown，并每个 key 中间插入空行
    obj.toStringEx(["## ","`n","`n"], ["### ","`n"])
    结果:
    ## a
    ### a1
    ### a2
    
    ## b
    ### b3
    ### b4
    */
    ;NOTE 暂不支持嵌套
    toStringEx(arrKey, arrValue) {
        res := ""
        for title, arr in this {
            res .= format("{1}{2}{3}", arrKey[1],title,arrKey[2])
            if (arr is array) {
                for v in arr
                    res .= format("{1}{2}{3}", arrValue[1],v,arrValue[2])
            } else {
                res .= format("{1}{2}{3}", arrValue[1],arr,arrValue[2])
            }
            (arrKey.length > 2) && res .= arrKey[3]
        }
        return rtrim(res, arrKey[3])
    }

    ;转成表格字符串(方便查看)
    ;数据结构要统一
    /*
    obj := map(
        "a",[1,2],
        "b",[3,4],
    )
    */
    toTable(charItem:="`t") {
        obj := this
        if (!obj.count)
            return ""
        res := ""
        ;记录第1项的类型
        for k, v in obj {
            isArray := v is array
            break
        }
        if (isArray) {
            for k, arr1 in obj {
                res .= k
                for v in arr1
                    res .= charItem . v
                res := rtrim(res, charItem) .  "`n"
            }
        } else {
            for k, v in obj {
                res .= format("{1}{2}{3}`n", k,charItem,v)
            }
        }
        return rtrim(res, charItem) .  "`n"
    }

    filter(fun) {
        objRes := map()
        for k, v in this {
            if (fun(k, v))
                objRes[k] := v
        }
        return objRes
    }

    ;简单键值对的比较
    ;tp 1=值不同，返回 key, [v0, v1]
    ;tp 0=键不同，返回 arrKey
    ;obj0放前面
    ;另见 IUIAutomationElement.compareUIE()
    compare(obj0, tp:=1) {
        obj0.default := ""
        obj1 := this
        obj1.default := ""
        objRes := map()
        switch tp {
            case 0:
                for k, v in obj1 {
                    if (!obj0.has(k))
                        objRes[k] := 1
                }
                for k, v in obj0 { ;记录 obj0 中独有的内容
                    if (v != obj1[k] && !objRes.has(k))
                        objRes[k] := [v, "null"]
                }
            case 1:
                for k, v in obj1 {
                    if (v != obj0[k])
                        objRes[k] := [obj0[k], v]
                }
                for k, v in obj0 { ;记录 obj0 中独有的内容
                    if (v != obj1[k] && !objRes.has(k))
                        objRes[k] := [v, "null"]
                }
        }
        return (objRes.count) ? objRes : map()
        objToTable(obj, charItem:="`t") {
            if (!obj.count)
                return ""
            res := ""
            ;记录第1项的类型
            for k, v in obj {
                tp := type(v)
                break
            }
            if (tp == "Array") {
                for k, arr1 in obj {
                    res .= k
                    for v in arr1
                        res .= charItem . v
                    res := rtrim(res, charItem) .  "`n"
                }
            }
            return res
        }
    }

    toSqlWhere(tp:="=") {
        sWhere := ""
        for k, v in this {
            if (type(v) == "String")
                v := format("'{1}'", v)
            sWhere .= format("{1} {2} {3} and", k,v)
        }
        return substr(sWhere, 1, strlen(sWhere)-4) ;删除末尾 and
    }

    deleteEmpty() {
        objRes := this.clone()
        arr := []
        for k, v in objRes {
            if (v == "")
                arr.push(k) ;直接objRes.delete会使得遍历出错
        }
        for k, v in arr
            objRes.delete(v)
        return objRes
    }

    deleteFalse(obj) { ;删除对象中的false内容(包括0)
        arr := []
        for k, v in obj {
            if (!v)
                arr.push(k) ;直接obj.delete会使得遍历出错
        }
        objRes := obj.clone()
        for k, v in arr
            objRes.delete(v)
        return obj
    }

    path2obj(obj, path) { ;返回对象的字符串路径对应的对象
        path := RegExReplace(path, "(\[|\]|\.)+", "|")
        ps := StrSplit(trim(path,"|"), "|")
        ;ps := StrSplit(trim(path,"[]."), ["[", "].", "][", "]", "."])
        for k, v in ps
            obj := obj[v]
        return obj
    }

    ;第一个k为基准，数字+1，统计缺少的项
    ;如果少4,5,6,7则合并成4-7
    ;Arrays有同名方法
    joinNumLost(joinNum:=true) {
        numSave := ""
        for k, _ in this {
            numSave := k
            break
        }
        if (numSave == "")
            return
        arrRes := [] ;记录缺失数字
        for k, _ in this {
            if (A_Index == 1){
                numSave := k
                continue
            } else if (k > numSave + 1) {
                cha := k-numSave
                if (cha == 2)
                    arrRes.push(numSave+1)
                else {
                    if (joinNum) {
                        arrRes.push((numSave+1) . "-" . (k-1))
                    } else {
                        loop(cha-1)
                            arrRes.push(numSave+A_Index)
                    }
                }
                numSave := k
            }
        }
        ;msgbox(json.stringify(arrRes, 4))
        return arrRes
    }

}

