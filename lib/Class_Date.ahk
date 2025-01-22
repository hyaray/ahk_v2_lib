;时间格式
;   时间戳
;   YYMMDDHHmmss
class _Date {
    static MonthInfo := ""
    static LeapType := ""
    static LeapMonth := ""
    static Chuyi := ""

    ;arr := [2024,1,2]
    __new(arr) {
        if (arr is ComObject)
            arr := arr.value
        if (arr is string)
            arr := StrSplit(arr, ["-","/"])
        this.char := "-"
        this.year := arr[1]
        if (strlen(this.year) == 2)
            this.year := "20" . this.year
        this.month := arr[2]
        this.day := arr[3]
        this.value := format("{1}{2}{3}", this.year,this.month.zfill(2),this.day.zfill(2))
        ;日期和月份的长度，有一个为1，则为1
        this.len := (strlen(this.month)==1 || strlen(this.day)==1) ? 1 : 2
        ;msgbox(this.value . "`n" . this.len)
    }

    ;天数
    ;_Date("2023-03-09").add(n)
    add(n:=1, tp:="days") {
        sDate := DateAdd(this.value . "000000", n, tp).left(8)
        res := format("{1}{4}{2}{4}{3}", substr(sDate,1,4),substr(sDate,5,2),substr(sDate,7,2),this.char)
        return res
    }

    ;会议时间：整10分，时长默认1小时
    ;比如 09:20-10:20
    static meetingTime() {
        m0 := integer(A_Min)
        h0 := integer(A_Hour)
        m := round(m0, -1)
        h := m0 > 55 ? string(h0+1) : h0
        return format("{1}:{2}-{3}:{2}", format("{:02s}",h),m,format("{:02s}",h+1))
    }

    ;上1季度
    static lastQuarter(month:=0) {
        if (!month)
            month := integer(A_MM)
        ;当前季度
        res := mod(month-1, 3) + 1
        ;上一季度
        if (res > 1)
            return res - 1
        else
            return 4
    }

    ;转成 A_Now 的格式
    static toTime(t){
        t := RegExReplace(t, "\D+")
        return t.addLeft(A_Now)
    }

    static daysOfMonth(year_Month) { ;计算某年某个月的天数，格式为201501
        if (StrLen(year_month) != 6)
            msgbox("参数：" . year_Month . "`n错误：计算月份天数的参数非6个数字")
        m := LTrim(substr(year_month,5), "0")
        a := map(1,31,3,31,4,30,5,31,6,30,7,31,8,31,9,30,10,31,11,30,12,31)
        if (a.has(m)) {
            return a[m]
        } else {
            if (this.isRunnian(substr(year_month, 1, 4)))
                return 29
            else
                return 28
        }
    }

    static daysOfJidu(str) { ;计算某年第N季度的天数，格式为20151
        if !(str ~= "^\d{4}[1-4]$") ;查看参数是否为5个数字并把季度赋值给jidu
            msgbox(format("参数{1}错误：计算季度天数的参数非5个数字(或季度>4)", str))
        jidu := substr(str, strlen(str))
        if (jidu > 1)
            return 91 + (jidu > 2)
        else if (this.isRunnian(substr(str, 1, 4))) ;闰年
            return 91
        else
            return 90
    }

    static getPrevMonthLastDay(day:="") => substr(DateAdd(A_Now, -day, "day"), 1, 8) ;通过日期(20191220)获取上月最后一天(8位数)

    static isZhouri(t) => (FormatTime(t,"WDay") == 1) ;获取星期几 ;判断是否周日(20180102这样的8位数字字符串)

    static isRunnian(year) { ;判断年份是否为闰年，是则返回1，否则0
        if (RegExMatch(year, "^\d{4}$") == 0) {
            msgbox("错误：年份有误，脚本退出",, "T1")
            return
        }
        return (mod(year, 400) == 0 || (mod(year, 4) == 0 && mod(year, 100) != 0))
    }

    static weekDay() => instr("2345671", A_WDay) ;获取星期几(周一为1)

    static today(strFormat:="yyyy/MM/dd") => FormatTime(, strFormat) ;"2019/04/03"

    ;修改日期格式
    ;2013/2/3 -> 20130203
    ;分隔符：任意非数字的同个符号
    static toFormat(sDate, char:="") {
        arr := StrSplit(sDate, ["-","/","."])
        if (arr.length <= 1)
            return
        res := arr[1]
        loop(2) {
            if (strlen(arr[A_Index+1]) == 1)
                arr[A_Index+1] := "0" . arr[A_Index+1]
            res .= char . arr[A_Index+1]
        }
        return res
    }

    static toNongli(t) { ;公历t(格式为20180101)转农历
        year := substr(t, 1, 4) ;获取年份
        if (year > 2100 || year < 1900)
            return false
        this.nongliAnalyze(year)
        newyear := year . this.Chuyi
        if (t < newyear) { ;NOTE 时间在上一年春节前，则读取上一年的农历
            year--
            this.nongliAnalyze(year)
        }
        newyear := year . this.Chuyi
        month := substr(t, 5, 2)
        day := substr(t, 7, 2)
        ;获取时间和春节的距离
        d := t
        d := DateDiff(d, newyear, "days")
        d++ ;因为和春节(不是除夕)相减，所以要+1
        ;计算农历日期
        if (this.LeapMonth) ;有闰月则闰月插入到该月之后
            this.MonthInfo := substr(this.MonthInfo, 1, this.LeapMonth) . this.LeapType . substr(this.MonthInfo, this.LeapMonth + 1)
        loop(13) {
            thisDays := 29 + substr(this.MonthInfo, A_Index, 1)
            if (d > thisDays) {
                tmp := d
                d -= thisDays
            } else {
                LMonth := (this.LeapMonth && (A_Index > this.LeapMonth)) ? (A_Index - 1) : A_Index ;有闰月且循环次数大于闰月的月份
                break
            }
        }
        LMonth := format("{:02s}", LMonth)
        LDay := format("{:02s}", LDate)
        LDate := year . LMonth . LDay ;完成
        ;转换成习惯性叫法
        ;Tiangan=甲,乙,丙,丁,戊,已,庚,辛,壬,癸
        ;Dizhi=子,丑,寅,卯,辰,巳,午,未,申,酉,戌,亥
        ;Shengxiao=鼠,牛,虎,兔,龙,蛇,马,羊,猴,鸡,狗,猪
        ;loop,parse,Tiangan,`,
        ;Tiangan%A_Index%:=A_LoopField
        ;Dizhi%A_Index%:=A_LoopField
        ;loop,parse,Dizhi,`,
        ;loop,parse,Shengxiao,`,
        ;Shengxiao%A_Index%:=A_LoopField
        ;Order1:=mod((year-4),10)+1
        ;Order2:=mod((year-4),12)+1
        ;year:=Tiangan%Order1% . Dizhi%Order2% . "(" . Shengxiao%Order2% . ")"
        ;yuefen=正,二,三,四,五,六,七,八,九,十,十一,腊
        ;loop,parse,yuefen,`,
        ;yuefen%A_Index%:=A_LoopField
        ;LMonth:=yuefen%LMonth%
        ;rizi = 初一,初二,初三,初四,初五,初六,初七,初八,初九,初十,十一,十二,十三,十四,十五,十六,十七,十八,十九,二十,廿一,廿二,廿三,廿四,廿五,廿六,廿七,廿八,廿九,三十
        ;loop,parse,rizi,`,
        ;rizi%A_Index%:=A_LoopField
        ;LDay:=rizi%LDay%
        ;LDate=%year%年%LMonth%月%LDay%
        return LDate
    }

    ;bLeap 比如闰四月，bLeap 则表示第2个四月
    static toGongli(t, bLeap:=false) {
        ;分解农历年月日(不包含前面的0)
        year := substr(t, 1, 4)
        month := integer(substr(t, 5, 2))
        day := integer(substr(t, StrLen(t)-1))
        ;各种错误日期格式
        if (year>2100 || year<1900 || month>12 || month<1 || day>30 || day<1)
            return false
        ;获取农历详情日期
        this.nongliAnalyze(year)
        ;计算到当天到当年农历新年的天数
        Sum := 0
        if (this.LeapMonth) { ;有闰月
            ;生成新的月份信息，闰4月则插入this.LeapType到第4个数字后面
            thisMonthInfo := substr(this.MonthInfo, 1, this.LeapMonth)
                . this.LeapType
                . substr(this.MonthInfo, this.LeapMonth+1)
            if (this.LeapMonth!=month && bLeap)
                msgbox("该月不是闰月")
            ;month < this.LeapMonth ;不考勤闰月
            ;month > this.LeapMonth ;考勤闰月
            ;month = this.LeapMonth && bLeap ;考勤闰月
            if (month>this.LeapMonth || (month==this.LeapMonth && bLeap)) {
                loop(month) {
                    thisMonth := substr(thisMonthInfo, A_Index, 1)
                    Sum := Sum + 29 + thisMonth
                }
            } else { ;无视闰月
                loop(month-1) {
                    thisMonth := substr(thisMonthInfo, A_Index, 1)
                    Sum := Sum + 29 + thisMonth
                }
            }
        } else {
            loop(month-1) {
                thisMonthInfo := this.MonthInfo
                thisMonth := substr(thisMonthInfo, A_Index, 1)
                Sum := Sum + 29 + thisMonth
            }
        }
        GDate := DateAdd(year . this.Chuyi, Sum+day-1, "days")
        return substr(Gdate, 1, 8)
    }

    static nongliAnalyze(year) { ;获取t(格式为20160212)的农历所在年份数据
        this.MonthInfo := ""
        this.LeapType := ""
        this.LeapMonth := ""
        this.Chuyi := ""

        ;前三位，Hex，转Bin，表示当年每月的类型，1为大月(30天)，0为小月(29天)
        ;第四位，Dec，表示闰月天数，1为大月(30天)，0为小月(29天)
        ;第五位，Hex，转Dec，表示是否闰月，0为不闰，否则为闰月月份
        ;后两位，Hex，转Dec，表示当年正月初一公历日期，格式MMDD
        if (year > 2100 || year < 1900)
            return false
        a := map(
            "1899","AB500D2","1900","4BD0883","1901","4AE00DB","1902","A5700D0","1903","54D0581","1904","D2600D8","1905","D9500CC","1906","655147D","1907","56A00D5","1908","9AD00CA","1909","55D027A","1910","4AE00D2","1911","A5B0682","1912","A4D00DA","1913","D2500CE","1914","D25157E","1915","B5500D6","1916","56A00CC","1917","ADA027B","1918","95B00D3","1919","49717C9","1920","49B00DC","1921","A4B00D0","1922","B4B0580","1923","6A500D8","1924","6D400CD","1925","AB5147C","1926","2B600D5","1927","95700CA","1928","52F027B","1929","49700D2","1930","6560682","1931","D4A00D9","1932","EA500CE","1933","6A9157E","1934","5AD00D6","1935","2B600CC","1936","86E137C","1937","92E00D3","1938","C8D1783","1939","C9500DB","1940","D4A00D0","1941","D8A167F","1942","B5500D7","1943","56A00CD","1944","A5B147D","1945","25D00D5","1946","92D00CA","1947","D2B027A","1948","A9500D2","1949","B550781","1950","6CA00D9","1951","B5500CE","1952","535157F","1953","4DA00D6","1954","A5B00CB","1955","457037C","1956","52B00D4","1957","A9A0883","1958","E9500DA","1959","6AA00D0","1960","AEA0680","1961","AB500D7","1962","4B600CD","1963","AAE047D","1964","A5700D5","1965","52600CA","1966","F260379","1967","D9500D1","1968","5B50782","1969","56A00D9","1970","96D00CE","1971","4DD057F","1972","4AD00D7","1973","A4D00CB","1974","D4D047B","1975","D2500D3","1976","D550883","1977","B5400DA","1978","B6A00CF","1979","95A1680","1980","95B00D8","1981","49B00CD","1982","A97047D","1983","A4B00D5","1984","B270ACA","1985","6A500DC","1986","6D400D1","1987","AF40681","1988","AB600D9","1989","93700CE","1990","4AF057F","1991","49700D7","1992","64B00CC","1993","74A037B","1994","EA500D2","1995","6B50883","1996","5AC00DB","1997","AB600CF","1998","96D0580","1999","92E00D8","2000","C9600CD","2001","D95047C","2002","D4A00D4","2003","DA500C9","2004","755027A","2005","56A00D1","2006","ABB0781","2007","25D00DA","2008","92D00CF","2009","CAB057E","2010","A9500D6","2011","B4A00CB","2012","BAA047B","2013","AD500D2","2014","55D0983","2015","4BA00DB","2016","A5B00D0","2017","5171680","2018","52B00D8","2019","A9300CD","2020","795047D","2021","6AA00D4","2022","AD500C9","2023","5B5027A","2024","4B600D2","2025","96E0681","2026","A4E00D9","2027","D2600CE","2028","EA6057E","2029","D5300D5","2030","5AA00CB","2031","76A037B","2032","96D00D3","2033","4AB0B83","2034","4AD00DB","2035","A4D00D0","2036","D0B1680","2037","D2500D7","2038","D5200CC","2039","DD4057C","2040","B5A00D4","2041","56D00C9","2042","55B027A","2043","49B00D2","2044","A570782","2045","A4B00D9","2046","AA500CE","2047","B25157E","2048","6D200D6","2049","ADA00CA","2050","4B6137B","2051","93700D3","2052","49F08C9","2053","49700DB","2054","64B00D0","2055","68A1680","2056","EA500D7","2057","6AA00CC","2058","A6C147C","2059","AAE00D4","2060","92E00CA","2061","D2E0379","2062","C9600D1","2063","D550781","2064","D4A00D9","2065","DA400CD","2066","5D5057E","2067","56A00D6","2068","A6C00CB","2069","55D047B","2070","52D00D3","2071","A9B0883","2072","A9500DB","2073","B4A00CF","2074","B6A067F","2075","AD500D7","2076","55A00CD","2077","ABA047C","2078","A5A00D4","2079","52B00CA","2080","B27037A","2081","69300D1","2082","7330781","2083","6AA00D9","2084","AD500CE","2085","4B5157E","2086","4B600D6","2087","A5700CB","2088","54E047C","2089","D1600D2","2090","E960882","2091","D5200DA","2092","DAA00CF","2093","6AA167F","2094","56D00D7","2095","4AE00CD","2096","A9D047D","2097","A2D00D4","2098","D1500C9","2099","F250279","2100","D5200D1",
        )
        this.Chuyi := format("{:04s}" ,(substr(a[year],-2).h2d()))
        ;通过前3位，获取当年月份，1为大月，0为小月
        this.MonthInfo := format("{:012s}", ("0x" . substr(a[year],1,3)).h2b())
        ;获取闰月类型，1为大月30天，0为小月29天
        this.LeapType := substr(a[year], 4, 1)
        ;闰月的月份
        this.LeapMonth := format("0x{1}", substr(a[year],5,1)).h2d()
    }

    ;返回标准14位数的时间格式
    static timeAdd(tm0, n, tp:="seconds") {
        ;补全时间为14位数
        tm0 := this.toTime(tm0)
        return DateAdd(tm0, n, tp)
    }

    ;时间-时间计算
    static diff(t1, t2, tp:="minutes") => DateDiff(this.toTime(t1), this.toTime(t2), tp)

    ;-----------------------------------time-----------------------------------

    ;NOTE 时间点格式：
    ;1666353432		格式	unix
    ;19700101000000	格式	tt
    ;08:59:59.222		格式	time
    ;0.99956		格式	float
    static tt2unix(tt:=""){
        if (tt == "")
            tt := A_Now
        return DateDiff(tt, "19700101000000", "seconds")
    }

    ;时间戳转 tt
    static unix2tt(ms)=> DateAdd("19700101000000", ms, "seconds")

    ;小数点时间转成xx:xx:xx.xxx
    ;0.99956 -> 23:59:22
    static timeFromFloat(tm) {
        if (tm == 0)
            return 0
        ms := 24*60*60*1000 * tm
        return this.timeFromMs(ms)
    }

    ;3610590 →01:00:10.590
    ;tp 1=显示毫秒 0=直接删除毫秒 NOTE -1=根据毫秒四舍五入
    static timeFromMs(ms:=0, tp:=0) {
        if !(ms is integer)
            throw TypeError(format("type(ms) = {1}", type(ms)))
        OutputDebug(format("i#{1} {2}:ms={3}", A_LineFile,A_LineNumber,ms))
        if (tp==-1 && mod(ms,1000)>=500)
            ms += 500
        arr := []
        loop 3
            arr.push(floor(mod((ms / (1000 * 60**(3-A_Index))),60)))
        ;OutputDebug(format("i#{1} {2}:arr={3}", A_LineFile,A_LineNumber,json.stringify(arr,4)))
        if (tp == 1) {
            arr.push(mod(ms, 1000))
            return format("{:02}:{:02}:{:02}.{:03}",arr*)
        } else {
            return format("{:02}:{:02}:{:02}",arr*)
        }
    }

    ;xx:xx:xx.xxx 时间转成秒数(小数点)
    ;this.time2second("01:10:01")
    static time2second(t) {
        if (t == "")
            return 0
        if !instr(t, ":")
            return t
        tp := instr(t, "-") ;负数
        t := ltrim(t, "-")
        ;t := RegExReplace(t, ":|：")
        arr := StrSplit(t, ".") ;判断有没有毫秒
        b := StrSplit(arr[1], ":")
        res := 0
        loop(b.length) {
            ;OutputDebug(format("i#{1} {2}:thisSecond={3}", A_LineFile,A_LineNumber,b[-A_Index] * (60**(A_Index-1))))
            res += b[-A_Index] * (60**(A_Index-1))
        }
        ;OutputDebug(format("i#{1} {2}:res={3}", A_LineFile,A_LineNumber,res))
        res := (arr.length > 1) ? round(res+arr[2]/1000, 3) : res
        ;OutputDebug(format("i#{1} {2}:res={3}", A_LineFile,A_LineNumber,res))
        if (tp)
            res := 0 - res
        return res
    }

    static getRebootTime() => DateAdd(A_Now, -A_TickCount//1000, "seconds") ;获取重启时间

    ;A_TickCount 格式的时间差
    static tc2time(tc) => FormatTime(DateAdd(A_Now, -(A_TickCount-tc)//1000, "s"), "yyyy-MM-dd HH:mm:ss")

}
;msgbox(_Date.timeFromFloat(0.99956))
;msgbox(_Date.timeFromFloat(9))
;msgbox(_Date.time2second("01:10"))
;msgbox(_Date.timeFromMs(3610590, 1))
