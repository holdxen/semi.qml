.pragma library

// InputNumber 的货币展示数据。

// 官方用 Intl.NumberFormat（semi-foundation/inputNumber/foundation.ts:141-161、564-582），而 QML 的

// JS 引擎里没有 Intl（实测 typeof Intl === undefined），Qt 侧只有 Qt.locale().currencySymbol()，拿不到

// 任意币种与 currencyDisplay。这张表把 Semi 支持的 27 个 localeCode（foundation.ts:879-918）逐个用

// Node 的 Intl 跑出来落盘（Node 与浏览器共用同一份 CLDR）。



// 每个 locale 存 {p} 正 / {n} 负两套模板，{C}=币种 token、{-}=负号、{v}=数字段，其余按字面量保留 ——
// 这样符号与数字之间的 NBSP（\u00A0）、法语的窄 NBSP（\u202F）、阿拉伯语两端的 RTL 标记（\u200F）
// 都不会被当成数字吃掉。primary/secondary 是分组宽度（en 3/3，hi-IN 3/2 的印度分组）。
// token 供 showCurrencySymbol=false 剥符号用（官方即 formatted.replace(_currencySymbol, "").trim()，:581）。
//
// 已知偏差：currencyDisplay="name" 用的是 CLDR 的 other 复数形式，官方 Intl 会按数值选单复数
// （如 fr-FR 的 0 → 「euro」而非「euros」、ru-RU 的 21 → 「рубля」），这类取值会与官方输出不同。
// 表外的 localeCode 退回 zh-CN；官方 localeCode 缺省取 LocaleProvider 语言，本库无 i18n 上下文，固定 zh-CN。

var LOCALES = {"zh-CN":{"cur":"CNY","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v}{C}","n":"{-}{v}{C}"},"token":{"sym":"¥","code":"CNY","name":"人民币"}},"zh-HK":{"cur":"HKD","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"HK$","code":"HKD","name":"港元"}},"zh-TW":{"cur":"TWD","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"TWD","name":"新台幣"}},"ja-JP":{"cur":"JPY","group":",","dec":".","primary":3,"secondary":3,"digits":0,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v}{C}","n":"{-}{v}{C}"},"token":{"sym":"￥","code":"JPY","name":"円"}},"ko-KR":{"cur":"KRW","group":",","dec":".","primary":3,"secondary":3,"digits":0,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"₩","code":"KRW","name":"대한민국 원"}},"th-TH":{"cur":"THB","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"฿","code":"THB","name":"บาทไทย"}},"vi-VN":{"cur":"VND","group":".","dec":".","primary":3,"secondary":3,"digits":0,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"₫","code":"VND","name":"đồng Việt Nam"}},"ms-MY":{"cur":"MYR","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C} {v}","n":"{-}{C} {v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"RM","code":"MYR","name":"Ringgit Malaysia"}},"id-ID":{"cur":"IDR","group":".","dec":".","primary":3,"secondary":3,"digits":0,"arabic":false,"sym":{"p":"{C} {v}","n":"{-}{C} {v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"Rp","code":"IDR","name":"Rupiah Indonesia"}},"hi-IN":{"cur":"INR","group":",","dec":".","primary":3,"secondary":2,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"₹","code":"INR","name":"भारतीय रुपए"}},"ar-SA":{"cur":"SAR","group":"٬","dec":"٫","primary":3,"secondary":3,"digits":2,"arabic":true,"sym":{"p":"‏{v} {C}‏","n":"؜{-}‏{v} {C}‏"},"code":{"p":"‏{v} {C}","n":"؜{-}‏{v} {C}"},"name":{"p":"{v} {C}","n":"؜{-}{v} {C}"},"token":{"sym":"ر.س.","code":"SAR","name":"ريال سعودي"}},"en-GB":{"cur":"GBP","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"£","code":"GBP","name":"British pounds"}},"de-DE":{"cur":"EUR","group":".","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"€","code":"EUR","name":"Euro"}},"fr-FR":{"cur":"EUR","group":" ","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"€","code":"EUR","name":"euros"}},"it-IT":{"cur":"EUR","group":".","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"€","code":"EUR","name":"euro"}},"es-ES":{"cur":"EUR","group":".","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"€","code":"EUR","name":"euros"}},"pt-PT":{"cur":"EUR","group":" ","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"€","code":"EUR","name":"euros"}},"ru-RU":{"cur":"RUB","group":" ","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{v} {C}","n":"{-}{v} {C}"},"code":{"p":"{v} {C}","n":"{-}{v} {C}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"₽","code":"RUB","name":"российского рубля"}},"en-US":{"cur":"USD","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"USD","name":"US dollars"}},"en-CA":{"cur":"CAD","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"CAD","name":"Canadian dollars"}},"es-MX":{"cur":"MXN","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"MXN","name":"pesos mexicanos"}},"pt-BR":{"cur":"BRL","group":".","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C} {v}","n":"{-}{C} {v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"R$","code":"BRL","name":"Reais brasileiros"}},"es-AR":{"cur":"ARS","group":".","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C} {v}","n":"{-}{C} {v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"ARS","name":"pesos argentinos"}},"en-AU":{"cur":"AUD","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"AUD","name":"Australian dollars"}},"en-NZ":{"cur":"NZD","group":",","dec":".","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C}{v}","n":"{-}{C}{v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"$","code":"NZD","name":"New Zealand dollars"}},"en-ZA":{"cur":"ZAR","group":" ","dec":",","primary":3,"secondary":3,"digits":2,"arabic":false,"sym":{"p":"{C} {v}","n":"{-}{C} {v}"},"code":{"p":"{C} {v}","n":"{-}{C} {v}"},"name":{"p":"{v} {C}","n":"{-}{v} {C}"},"token":{"sym":"R","code":"ZAR","name":"South African rand"}},"ar-EG":{"cur":"EGP","group":"٬","dec":"٫","primary":3,"secondary":3,"digits":2,"arabic":true,"sym":{"p":"‏{v} {C}‏","n":"؜{-}‏{v} {C}‏"},"code":{"p":"‏{v} {C}","n":"؜{-}‏{v} {C}"},"name":{"p":"{v} {C}","n":"؜{-}{v} {C}"},"token":{"sym":"ج.م.","code":"EGP","name":"جنيه مصري"}}};

// foundation.ts:879-918 区域 -> 币种
var LOCALE_CURRENCY = {"zh-CN":"CNY","zh-HK":"HKD","zh-TW":"TWD","ja-JP":"JPY","ko-KR":"KRW","th-TH":"THB","vi-VN":"VND","ms-MY":"MYR","id-ID":"IDR","hi-IN":"INR","ar-SA":"SAR","en-GB":"GBP","de-DE":"EUR","fr-FR":"EUR","it-IT":"EUR","es-ES":"EUR","pt-PT":"EUR","ru-RU":"RUB","en-US":"USD","en-CA":"CAD","es-MX":"MXN","pt-BR":"BRL","es-AR":"ARS","en-AU":"AUD","en-NZ":"NZD","en-ZA":"ZAR","ar-EG":"EGP"};

// foundation.ts:927-938 语言兜底，:945 最终兜底 USD
var LANG_CURRENCY = {"en":"USD","zh":"CNY","es":"EUR","fr":"EUR","de":"EUR","it":"EUR","ja":"JPY","ko":"KRW","ru":"RUB","ar":"SAR"};
var ARABIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";

function meta(localeCode) {
    return LOCALES[localeCode] || LOCALES["zh-CN"];
}

function currencyFor(localeCode, currency) {
    if (typeof currency === "string" && currency.trim() !== "")
        return currency;
    if (LOCALE_CURRENCY[localeCode] !== undefined)
        return LOCALE_CURRENCY[localeCode];
    var lang = String(localeCode).split("-")[0];
    if (LANG_CURRENCY[lang] !== undefined)
        return LANG_CURRENCY[lang];
    return "USD";
}

function toArabic(str) {
    return str.replace(/[0-9]/g, function (d) { return ARABIC_DIGITS.charAt(Number(d)); });
}

function fromArabic(str) {
    var out = "";
    for (var i = 0; i < str.length; ++i) {
        var idx = ARABIC_DIGITS.indexOf(str.charAt(i));
        out += idx >= 0 ? String(idx) : str.charAt(i);
    }
    return out;
}

// 末段 primary 位，往前每 secondary 位一组（secondary === primary 就是普通千分位）
function groupDigits(intStr, sep, primary, secondary) {
    if (sep === "" || intStr.length <= primary)
        return intStr;
    var head = intStr.substring(0, intStr.length - primary);
    var tail = intStr.substring(intStr.length - primary);
    var out = "";
    while (head.length > secondary) {
        out = sep + head.substring(head.length - secondary) + out;
        head = head.substring(0, head.length - secondary);
    }
    if (head.length > 0)
        out = head + out;
    return out + sep + tail;
}

function displayKey(display) {
    return display === "code" ? "code" : (display === "name" ? "name" : "sym");
}

// opts: { localeCode, currency, currencyDisplay, showCurrencySymbol, value, precision }
function format(opts) {
    var loc = meta(opts.localeCode);
    var num = Number(opts.value);
    if (!isFinite(num))
        return String(opts.value);
    var key = displayKey(opts.currencyDisplay);
    var digits = typeof opts.precision === "number" && opts.precision >= 0 ? opts.precision : loc.digits;
    var abs = Math.abs(num).toFixed(digits);
    var pieces = abs.split(".");
    var body = groupDigits(pieces[0], loc.group, loc.primary, loc.secondary);
    if (pieces.length > 1 && pieces[1] !== "")
        body += loc.dec + pieces[1];
    if (loc.arabic)
        body = toArabic(body);
    var tpl = num < 0 ? loc[key].n : loc[key].p;
    var token = loc.token[key];
    var out = tpl.split("{C}").join(token).split("{v}").join(body)
        .split("{-}").join(num < 0 ? "-" : "").split("{+}").join("");
    if (opts.showCurrencySymbol === false)
        return out.split(token).join("").replace(/^[\s\u00A0\u202F]+|[\s\u00A0\u202F]+$/g, "");
    return out;
}

function unformat(input, opts) {
    var loc = meta(opts.localeCode);
    var s = String(input);
    if (loc.arabic)
        s = fromArabic(s);
    s = s.split(loc.token.sym).join("").split(loc.token.code).join("").split(loc.token.name).join("");
    if (loc.group !== "")
        s = s.split(loc.group).join("");
    if (loc.dec !== ".")
        s = s.split(loc.dec).join(".");
    return s.replace(/[^0-9.\-]/g, "");
}
