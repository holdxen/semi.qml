.pragma library

// 日期格式化与解析。对应 semi-foundation/datePicker/_utils/getDefaultFormatToken.ts
// 与 date-fns(v2.9.0) 的 format / parse —— 官方「日期时间格式」一节只用到六个 token：
// y 年 / M 月 / d 日 / H 时 / m 分 / s 秒（content/input/datepicker/index.md:976-999），
// 单个不补零、两个补零（y 另有 yy 取后两位、yyyy 补到四位）。
// TimePicker 还要两个 12 小时制的 token：h（date-fns 的 1-12）与 a（上下午 / AM / PM，
// 取 locale 的 dayPeriod，zh-CN 是「上午 / 下午」，见 date-fns/locale/zh-CN/_lib/localize
// /index.js:41-50；本库按仓库口径硬编码中文）。
// 纯函数、无状态，所以和 CalendarDate.js 一样用 .pragma library 共享同一份。

const FORMAT_FULL_DATE = "yyyy-MM-dd";
const FORMAT_DATE_TIME = "yyyy-MM-dd HH:mm:ss";
const FORMAT_YEAR_MONTH = "yyyy-MM";
const FORMAT_TIME_PICKER = "HH:mm:ss";
// timePicker/constants.ts:25-26。use12Hours 时默认格式是「a h:mm:ss」（上下午在前），
// 文档写的 h:mm:ss a 与源码不一致，按源码。
const FORMAT_TIME_PICKER_12H = "a h:mm:ss";

// constants.ts:45-46
const SEPARATOR_MULTIPLE = ",";
const SEPARATOR_RANGE = " ~ ";

// locale/source/zh_CN.ts:31-32（TimePicker.AM / PM）
const MERIDIEM_AM = "上午";
const MERIDIEM_PM = "下午";

const TOKENS = "yMdHmsha";

// getDefaultFormatTokenByType：date / dateRange 是 yyyy-MM-dd，
// dateTime / dateTimeRange 带秒，month / monthRange 只到月。
function defaultFormatToken(typeKey) {
    if (typeKey === "dateTime" || typeKey === "dateTimeRange")
        return FORMAT_DATE_TIME;
    if (typeKey === "month" || typeKey === "monthRange")
        return FORMAT_YEAR_MONTH;
    return FORMAT_FULL_DATE;
}

// getValidDateFormat（monthsGridFoundation.ts:820-822）
function dateFormatOf(pattern, typeKey) {
    return pattern !== "" ? pattern : defaultFormatToken(typeKey);
}

// getValidTimeFormat（monthsGridFoundation.ts:801-818）：
// 从用户 format 里挑出用到了的时间位，拼成时间面板的列。format 没给就用 HH:mm:ss。
function timeFormatOf(pattern) {
    const source = pattern !== "" ? pattern : FORMAT_TIME_PICKER;
    const tokens = [];
    if (source.indexOf("h") >= 0 || source.indexOf("H") >= 0)
        tokens.push("HH");
    if (source.indexOf("m") >= 0)
        tokens.push("mm");
    if (source.indexOf("s") >= 0)
        tokens.push("ss");
    return tokens.join(":");
}

// index.tsx:38-46：format 里一个时间位都没有，dateTime 会退化成 date（面板不画时间部分）
function hasTimeToken(pattern) {
    return /[hHms]/.test(pattern);
}

function pad(value, width) {
    let text = String(value);
    while (text.length < width)
        text = "0" + text;
    return text;
}

function tokenize(pattern) {
    const out = [];
    let i = 0;
    while (i < pattern.length) {
        const ch = pattern[i];
        if (TOKENS.indexOf(ch) >= 0) {
            let j = i;
            while (j < pattern.length && pattern[j] === ch)
                ++j;
            out.push({ token: ch, count: j - i });
            i = j;
        } else {
            if (out.length === 0 || out[out.length - 1].token !== null)
                out.push({ token: null, text: ch });
            else
                out[out.length - 1].text += ch;
            ++i;
        }
    }
    return out;
}

function renderToken(token, count, value) {
    if (token === "a")
        return value.getHours() < 12 ? MERIDIEM_AM : MERIDIEM_PM;
    if (token === "y") {
        const year = value.getFullYear();
        if (count === 2)
            return pad(year % 100, 2);
        return count >= 4 ? pad(year, 4) : String(year);
    }
    const numbers = {
        M: value.getMonth() + 1,
        d: value.getDate(),
        H: value.getHours(),
        // date-fns 的 h 是 1-12（0 点显示成 12）
        h: value.getHours() % 12 || 12,
        m: value.getMinutes(),
        s: value.getSeconds()
    };
    const n = numbers[token];
    return count >= 2 ? pad(n, 2) : String(n);
}

function format(value, pattern) {
    const d = new Date(value);
    let out = "";
    const parts = tokenize(pattern);
    for (let i = 0; i < parts.length; ++i) {
        if (parts[i].token === null)
            out += parts[i].text;
        else
            out += renderToken(parts[i].token, parts[i].count, d);
    }
    return out;
}

function escapeLiteral(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// 按 format 反解。解不出（形状不符、月份日子越界）返回 null ——
// 官方那边是 date-fns 的 parse + isValid，非法值由调用方决定回不回退。
function parse(text, pattern) {
    if (text === undefined || text === null)
        return null;
    const source = String(text).trim();
    if (source === "")
        return null;

    let re = "^";
    const groups = [];
    const parts = tokenize(pattern);
    for (let i = 0; i < parts.length; ++i) {
        if (parts[i].token === null) {
            re += escapeLiteral(parts[i].text);
            continue;
        }
        if (parts[i].token === "a") {
            // date-fns zh-CN 的 match（locale/zh-CN/_lib/match/index.js:46-58）收 上午/下午
            // 及其单字形式；英文 AM/PM 一并收，大小写都认
            re += "(上午|下午|AM|PM|am|pm)";
            groups.push("a");
            continue;
        }
        re += parts[i].token === "y" ? "(\\d{1,4})" : "(\\d{1,2})";
        groups.push(parts[i].token);
    }
    re += "$";

    const m = new RegExp(re).exec(source);
    if (!m)
        return null;

    let year = 1970, month = 0, day = 1, hour = 0, minute = 0, second = 0;
    let hour12 = -1, pm = false;
    for (let i = 0; i < groups.length; ++i) {
        if (groups[i] === "a") {
            const t = m[i + 1];
            pm = t === "下午" || t === "PM";
            continue;
        }
        const n = Number(m[i + 1]);
        if (groups[i] === "y")
            year = n;
        else if (groups[i] === "M")
            month = n - 1;
        else if (groups[i] === "d")
            day = n;
        else if (groups[i] === "H")
            hour = n;
        else if (groups[i] === "h")
            hour12 = n;
        else if (groups[i] === "m")
            minute = n;
        else
            second = n;
    }

    if (hour12 >= 0) {
        // 12 小时制要配 a 才能定回 24 小时。没给 a 时按「上午」处理（date-fns parse 的
        // dayPeriod 缺省不修正，12 点落回 0 点）
        if (hour12 < 1 || hour12 > 12)
            return null;
        hour = pm ? (hour12 === 12 ? 12 : hour12 + 12) : (hour12 === 12 ? 0 : hour12);
    }

    if (month < 0 || month > 11 || day < 1 || day > 31
        || hour > 23 || minute > 59 || second > 59)
        return null;
    const d = new Date(year, month, day, hour, minute, second);
    // 2 月 30 日会被 Date 自己卷到 3 月，卷了就算非法
    if (d.getMonth() !== month || d.getDate() !== day)
        return null;
    return d;
}

// index.tsx:49-51：用户传的 rangeSeparator 两侧各补一个空格再用于展示
function rangeSeparatorOf(separator) {
    return " " + separator + " ";
}

// isTimeFormatLike（timePicker/utils/index.ts:126-156）：位数还没敲够就先别拿去 parse。
// 'HH:mm' 配 '10:2' 在 date-fns 里是能解成 10:02 的，不拦一下就会在用户敲到一半时
// 提交一个错的值、还把光标弹走（foundation.ts:326-329 的 handleInputChange 就是这么做的）。
function isFormatLike(time, pattern) {
    const supportCh = "BDEGHKLMOPQRSTXYabcehimopqstuwxyz";   // date-fns 认的格式字符
    const formatSplitted = String(pattern).split(new RegExp("[^" + supportCh + "]", "g"));
    const separator = String(pattern).replace(new RegExp("[" + supportCh + "]", "g"), "");
    const escaped = separator.replace(/[-[\]{}()*+?.,\\^$|]/g, "\\$&");
    const timeSplitted = String(time).split(new RegExp("[" + escaped + "]", "g"));
    if (formatSplitted.length !== timeSplitted.length)
        return false;
    for (let i = 0; i < timeSplitted.length; ++i) {
        // 只有时 / 分 / 秒要卡位数，年 / 月和上下午都按变长处理
        if (/[H|m|s]{1,2}/.test(formatSplitted[i])
            && timeSplitted[i].length < formatSplitted[i].length)
            return false;
    }
    return true;
}

// getDefaultFormatIfNeed（ComboxFoundation.ts:88-96）：给了 format 就用它，
// 否则 use12Hours → 'a h:mm:ss'，再否则 'HH:mm:ss'。
// （.pragma library 里的 const 不会暴露给 QML，所以默认格式从这里拿。）
function defaultTimeFormat(use12Hours) {
    return use12Hours ? FORMAT_TIME_PICKER_12H : FORMAT_TIME_PICKER;
}

// 上下午两项，顺序就是列里的顺序（Combobox.tsx:283-298 的 AM 在前）
function meridiemItems() {
    return [MERIDIEM_AM, MERIDIEM_PM];
}

function isPM(date) {
    return date.getHours() >= 12;
}

// 24 小时 → 列上显示的 1-12（Combobox.tsx:195-196 的 hour % 12 || 12）
function hour12Of(hour) {
    return hour % 12 || 12;
}

function formatRange(startValue, endValue, pattern, separator) {
    if (!startValue || !endValue)
        return "";
    return format(startValue, pattern) + separator + format(endValue, pattern);
}

// foundation.ts:913-936 + constants.ts:46：多个日期用英文逗号连
function formatMultiple(values, pattern) {
    const out = [];
    for (let i = 0; i < values.length; ++i)
        out.push(format(values[i], pattern));
    return out.join(SEPARATOR_MULTIPLE);
}
