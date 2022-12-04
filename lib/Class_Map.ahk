;不修改原obj
;优先使用Arrays
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

    index(isValue:=0, i:=1) {
        e := this.__enum()
        numput("uint", this.count-1-i, objptr(e), 6*A_PtrSize+16)
        e(&k)
        return isValue ? this[k] : k
    }

    toString() => super.toJson()

    ;参考python
    ;如果指定了i，则返回对应序号的k
    keys(i:=0) {
        if (i) {
            if (i > 0) ;1=-1 2=0
                idx := i-2
            else ;-1=count-2 -2=count-3
                idx := this.count - (abs(i) + 1)
            e := this.__enum()
            numput("uint", idx, objptr(e), 6*A_PtrSize+16)
            e(&k)
            return k
        }
        arr := []
        for k, v in this
            arr.push(k)
        return arr
    }

    values(i:=0) {
        if (i) {
            if (i > 0)
                idx := i-2
            else
                idx := this.count - (abs(i) + 1)
            e := this.__enum()
            numput("uint", idx, objptr(e), 6*A_PtrSize+16)
            e(&k)
            return this[k]
        }
        arr := []
        for k, v in this
            arr.push(v)
        return arr
    }

    items() {
        arr := []
        for k, v in this
            arr.push([k, v])
        return arr
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
    ;返回 key, [v0, v1]
    ;obj0放前面
    ;另见 IUIAutomationElement.compareUIE()
    compare(obj0) {
        obj0.default := ""
        obj1 := this
        obj1.default := ""
        objRes := map()
        for k, v in obj1 {
            if (v != obj0[k])
                objRes[k] := [obj0[k], v]
        }
        for k, v in obj0 { ;记录 obj0 中独有的内容
            if (v != obj1[k] && !objRes.has(k))
                objRes[k] := [v, "null"]
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

    deleteEmpty(obj) {
        arr := []
        for k, v in obj {
            if (v == "")
                arr.push(k) ;直接obj.delete会使得遍历出错
        }
        objRes := obj.clone()
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

