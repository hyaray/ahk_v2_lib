; Construction and deconstruction VARIANT struct
class ComVar {
    /**
    * Construction VARIANT struct, `ptr` property points to the address, `__item` property returns var's Value
    * @param vVal Values that need to be wrapped, supports String, Integer, Double, Array, ComValue, ComObjArray
    * ### example
    * `var1 := ComVar('string'), MsgBox(var1[])`
    * 
    * `var2 := ComVar([1,2,3,4],, true)`
    * 
    * `var3 := ComVar(ComValue(0xb, -1))`
    * @param vType Variant's type, VT_VARIANT(default)
    * @param convert Convert AHK's array to ComObjArray
    */
    __new(vVal := unset, vType := 0xC, convert := false) {
        static size := 8 + 2 * A_PtrSize
        this.var := buffer(size, 0), this.owner := true
        this.ref := ComValue(0x4000 | vType, this.var.Ptr + (vType = 0xC ? 0 : 8))
        if (isset(vVal)) {
            if (type(vVal) == "ComVar") {
                this.var := vVal.var, this.ref := vVal.ref, this.obj := vVal, this.owner := false
            } else {
                if (isobject(vVal)) {
                    if (vType != 0xC)
                        this.ref := ComValue(0x400C, this.var.ptr)
                    if (convert && (vVal is array)) {
                        switch type(vVal[1]) {
                            case "Integer": vType := 3
                            case "String": vType := 8
                            case "Float": vType := 5
                            case "ComValue", "ComObject": vType := ComObjType(vVal[1])
                            default: vType := 0xC
                        }
                        ComObjFlags(obj := ComObjArray(vType, vVal.Length), -1), i := 0, this.ref[] := obj
                        for v in vVal
                            obj[i++] := v
                    } else {
                        this.ref[] := vVal
                    }
                } else {
                    this.ref[] := vVal
                }
            }
        }
    }
    __delete() => (this.owner ? dllcall("oleaut32\VariantClear", "ptr",this.var) : 0)
    __item {
        get => this.ref[]
        set => this.ref[] := value
    }
    ptr => this.var.ptr
    size => this.var.size
    type {
        get => numget(this.var, "ushort")
        set {
            if (!this.IsVariant)
                throw PropertyError("VarType is not VT_VARIANT, type is read-only.", -2)
            numput("ushort", Value, this.var)
        }
    }
    IsVariant => ComObjType(this.ref) & 0xC
}
