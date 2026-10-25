import QtQuick

// 表单容器。对应官方 Semi 的 Form：集中持有 FormState（values / errors / touched），
// 提供 formApi 的同名方法，并把布局与校验配置下发给内部的每个 Field。
//
//     Form {
//         id: form
//         labelPosition: "left"
//         onSubmit: (values) => save(values)
//
//         FormItem {
//             field: "name"
//             label: "姓名"
//             rules: [{ required: true, message: "必填" }]
//
//             Input { onTextChanged: form.setValue("name", text) }
//         }
//     }
//
// QML 里没有 React 的 context，所以 formApi 不是单独的对象 —— Form 自己就是 api，
// 内部的 FormItem 沿 parent 链找到自己。官方的 getFormApi(formApi) 回调保留，
// 参数就是这张 Form。
Item {
    id: control

    default property alias content: body.data

    // --- 布局（官方 FormProps 同名）---
    property string layout: "vertical"          // vertical / horizontal
    property string labelPosition: "top"        // top / left / inset
    property string labelAlign: "left"          // left / right
    property real labelWidth: 0                 // 0 = 跟随内容
    property var labelCol: ({})                 // { span, offset }，设置即启用栅格布局
    property var wrapperCol: ({})
    property string extraTextPosition: "bottom" // bottom / middle

    // --- FormState ---
    property var values: ({})
    property var errors: ({})
    property var touched: ({})

    // --- 数据与校验（官方 FormProps 同名）---
    property var initValues: ({})               // 仅挂载时消费一次
    property var validator: null                // Form 级校验 (values) => errors
    property var validateFields: null           // 官方已废弃的旧名，仍兼容
    property var trigger: "change"              // change / blur / mount / custom 或其数组
    property bool stopValidateWithError: false
    property bool showValidateIcon: true
    property bool disabled: false               // 下发给每个 Field
    property bool allowEmpty: false             // false 时值为空的 field 不留在 values 里
    property bool autoScrollToError: false
    property var getFormApi: null               // (formApi) => void

    // 官方 onChange(formState)
    signal change(var formState)
    signal valueChange(var values, var changedValue)
    signal errorChange(var errors, var changedError)
    // 官方叫 onReset，但 QML 里 reset 这个名字已被 formApi 的 reset() 方法占了
    signal resetTriggered
    signal submit(var values)
    signal submitFail(var errors, var values)

    implicitWidth: 400
    implicitHeight: body.implicitHeight

    // 官方 .semi-form 是 flex 容器，vertical 与 horizontal 只差在字段是否换行；
    // vertical 时把每个 field 撑满整宽（FormItem 自己按 formLayout 判断），
    // 一行一个，效果与 Column 相同，却能复用同一份代码处理 horizontal 的换行。
    Flow {
        id: body

        width: parent.width
        flow: Flow.LeftToRight
        spacing: 0
    }

    // ---- 字段路径：a[0] / siblings.1 / siblings['2'] / parents[0].name ----

    // 把路径串拆成 [{ key, index }]。官方用 lodash 的 get/set，这里自己解析：
    // QML 的 JS 引擎没有 lodash，而路径语法正是 Form 的公开 API。
    function parsePath(field) {
        const segs = [];
        let buf = "";
        let i = 0;
        while (i < field.length) {
            const c = field[i];
            if (c === ".") {
                if (buf !== "")
                    segs.push({ key: buf, index: false });
                buf = "";
                ++i;
            } else if (c === "[") {
                if (buf !== "")
                    segs.push({ key: buf, index: false });
                buf = "";
                ++i;
                let inner = "";
                while (i < field.length && field[i] !== "]") {
                    inner += field[i];
                    ++i;
                }
                ++i; // 跳过 ]
                const quoted = inner.length >= 2
                    && ((inner[0] === "'" && inner[inner.length - 1] === "'")
                        || (inner[0] === "\"" && inner[inner.length - 1] === "\""));
                if (quoted)
                    inner = inner.substring(1, inner.length - 1);
                segs.push({ key: inner, index: !quoted && /^-?\d+$/.test(inner) });
            } else {
                buf += c;
                ++i;
            }
        }
        if (buf !== "")
            segs.push({ key: buf, index: false });
        return segs;
    }

    function getPath(obj, segs) {
        let cur = obj;
        for (let i = 0; i < segs.length; ++i) {
            if (cur === undefined || cur === null)
                return undefined;
            cur = cur[segs[i].key];
        }
        return cur;
    }

    // 沿路径重建对象后再赋值 —— 直接改原对象不会触发 var 属性的变化通知，
    // 绑定 formState 的地方就看不到更新。
    function setPath(obj, segs, value) {
        if (segs.length === 0)
            return value;
        const head = segs[0];
        const next = (obj !== undefined && obj !== null) ? obj : (head.index ? [] : {});
        const copy = Array.isArray(next) ? next.slice() : Object.assign({}, next);
        copy[head.key] = control.setPath(copy[head.key], segs.slice(1), value);
        return copy;
    }

    function deletePath(obj, segs) {
        if (obj === undefined || obj === null || segs.length === 0)
            return obj;
        const copy = Array.isArray(obj) ? obj.slice() : Object.assign({}, obj);
        if (segs.length === 1) {
            delete copy[segs[0].key];
            return copy;
        }
        copy[segs[0].key] = control.deletePath(copy[segs[0].key], segs.slice(1));
        return copy;
    }

    // 空值判定与官方一致：'' / null / undefined 算空，数组不算（[] 是有值的）
    function isEmptyValue(value) {
        return value === undefined || value === null || value === "";
    }

    // ---- 字段注册 ----

    // { 路径: spec } + 注册顺序表（validate 要按 DOM 顺序遍历，对象不保证顺序）
    property var fields: ({})
    property var fieldOrder: []

    function registerField(field, spec) {
        const existed = control.fields[field] !== undefined;
        const next = Object.assign({}, control.fields);
        next[field] = spec;
        control.fields = next;

        const order = control.fieldOrder.slice();
        if (!existed)
            order.push(field);
        control.fieldOrder = order;

        // initValue 优先于 Form 的 initValues；两者都只在字段挂载时消费一次
        if (!existed && spec.valueAtMount === undefined) {
            const fromForm = control.initValues[field];
            const initial = spec.initValue !== undefined ? spec.initValue : fromForm;
            if (initial !== undefined) {
                spec.valueAtMount = initial;
                control.writeFieldValue(field, initial, isEmptyValue(initial)
                    && !(spec.allowEmptyString || control.allowEmpty));
            }
            if ((spec.trigger || control.trigger).indexOf("mount") >= 0)
                control.revalidateField(field);
        }
    }

    function unregisterField(field, keepState) {
        if (control.fields[field] === undefined)
            return;
        const spec = control.fields[field];
        const next = Object.assign({}, control.fields);
        delete next[field];
        control.fields = next;
        control.fieldOrder = control.fieldOrder.filter(function (f) { return f !== field; });

        // 官方：Field 卸载即清状态，keepState 时保留 value / error / touched
        const keep = keepState || spec.keepState;
        if (keep)
            return;
        control.values = control.deletePath(control.values, control.parsePath(field));
        control.errors = control.deletePath(control.errors, control.parsePath(field));
        control.touched = control.deletePath(control.touched, control.parsePath(field));
    }

    function getFieldExist(field) {
        return control.fields[field] !== undefined;
    }

    function fieldSpec(field) {
        return control.fields[field];
    }

    // 数组字段的行数，供 FormArrayField 使用
    function arrayLength(field) {
        const value = control.getValue(field);
        return Array.isArray(value) ? value.length : 0;
    }

    // ---- FormApi 同名方法 ----

    function getFormState() {
        return { values: control.values, errors: control.errors, touched: control.touched };
    }

    function getValue(field) {
        return control.getPath(control.values, control.parsePath(field));
    }

    function getValues() {
        return control.values;
    }

    function writeFieldValue(field, value, removeKey) {
        const segs = control.parsePath(field);
        control.values = removeKey
            ? control.deletePath(control.values, segs)
            : control.setPath(control.values, segs, value);
    }

    function setValue(field, value) {
        const spec = control.fields[field];
        let stored = value;
        if (spec && typeof spec.convert === "function")
            stored = spec.convert(stored);

        const keepEmpty = spec ? (spec.allowEmptyString || control.allowEmpty) : control.allowEmpty;
        const remove = isEmptyValue(stored) && !keepEmpty;
        control.writeFieldValue(field, stored, remove);

        control.valueChange(control.values, { field: field, value: stored });
        control.change(control.getFormState());

        // 官方 trigger 含 change 的字段，值一变就重校验
        const trig = spec ? (spec.trigger || control.trigger) : control.trigger;
        if (String(trig).indexOf("change") >= 0)
            control.revalidateField(field);
    }

    // isOverride=false（官方默认）：只更新表单里已注册的字段，newValues 没有的置 undefined
    // isOverride=true：整体替换，newValues 里多出来的 key 也保留
    function setValues(newValues, options) {
        if (options && options.isOverride) {
            control.values = newValues;
        } else {
            let next = control.values;
            control.fieldOrder.forEach(function (field) {
                const segs = control.parsePath(field);
                const value = newValues[field];
                const keepEmpty = control.fields[field].allowEmptyString || control.allowEmpty;
                next = isEmptyValue(value) && !keepEmpty
                    ? control.deletePath(next, segs)
                    : control.setPath(next, segs, value);
            });
            control.values = next;
        }
        control.valueChange(control.values, { fields: Object.keys(newValues) });
        control.change(control.getFormState());
    }

    function getError(field) {
        return control.getPath(control.errors, control.parsePath(field));
    }

    function setError(field, message) {
        const segs = control.parsePath(field);
        control.errors = isEmptyValue(message)
            ? control.deletePath(control.errors, segs)
            : control.setPath(control.errors, segs, message);
        control.errorChange(control.errors, { field: field, error: message });
        control.change(control.getFormState());
    }

    function getTouched(field) {
        return control.getPath(control.touched, control.parsePath(field)) === true;
    }

    function setTouched(field, isTouched) {
        const segs = control.parsePath(field);
        control.touched = isEmptyValue(isTouched)
            ? control.deletePath(control.touched, segs)
            : control.setPath(control.touched, segs, isTouched);
        control.change(control.getFormState());
    }

    // 官方 errorOf 的等价物，供 FormItem 直接读
    function errorOf(field) {
        const e = control.getError(field);
        if (e === undefined || e === null)
            return "";
        if (Array.isArray(e))
            return e.filter(function (x) { return x; }).join(", ");
        return String(e);
    }

    // ---- 校验 ----

    // 单条规则的判定，覆盖官方 async-validator 的常用 type
    function checkRule(rule, rawValue, values, field) {
        const text = rawValue === undefined || rawValue === null ? "" : String(rawValue);
        const empty = rawValue === undefined || rawValue === null || rawValue === ""
            || (Array.isArray(rawValue) && rawValue.length === 0);

        if (rule.required && empty)
            return rule.message !== undefined ? rule.message : qsTr("此项为必填");
        // 非必填且值为空时，async-validator 会跳过后续规则
        if (empty)
            return "";

        if (rule.type !== undefined) {
            const ok = rule.type === "string" ? typeof rawValue === "string"
                : rule.type === "number" ? (typeof rawValue === "number" && !isNaN(rawValue))
                : rule.type === "boolean" ? typeof rawValue === "boolean"
                : rule.type === "array" ? Array.isArray(rawValue)
                : rule.type === "integer" ? Number.isInteger(Number(rawValue))
                : rule.type === "email" ? /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(text)
                : rule.type === "url" ? /^https?:\/\/\S+$/.test(text)
                : true;
            if (!ok)
                return rule.message !== undefined ? rule.message : qsTr("类型不正确");
        }

        // 官方 min/max 对字符串与数组取长度，对数字取大小
        const sized = typeof rawValue === "number" ? rawValue : (Array.isArray(rawValue) ? rawValue.length : text.length);
        if (rule.min !== undefined && sized < rule.min)
            return rule.message !== undefined ? rule.message : qsTr("长度或数值不足");
        if (rule.max !== undefined && sized > rule.max)
            return rule.message !== undefined ? rule.message : qsTr("长度或数值超出");
        if (rule.len !== undefined && sized !== rule.len)
            return rule.message !== undefined ? rule.message : qsTr("长度不正确");
        // 本模块早期用的小写别名，官方没有这两个键
        if (rule.minLength !== undefined && text !== "" && text.length < rule.minLength)
            return rule.message !== undefined ? rule.message : qsTr("长度不足");
        if (rule.maxLength !== undefined && text.length > rule.maxLength)
            return rule.message !== undefined ? rule.message : qsTr("长度超出");

        if (rule.pattern !== undefined && text !== "") {
            const re = rule.pattern instanceof RegExp ? rule.pattern : new RegExp(rule.pattern);
            if (!re.test(text))
                return rule.message !== undefined ? rule.message : qsTr("格式不正确");
        }

        if (typeof rule.validator === "function") {
            // 官方 async-validator 的签名是 (rule, value, callback)，不是 (value)
            const result = rule.validator(rule, rawValue, function (err) { return err; }, values);
            if (result !== true && result !== "" && result !== undefined && result !== null) {
                if (typeof result === "string")
                    return result;
                return rule.message !== undefined ? rule.message : qsTr("校验未通过");
            }
        }
        return "";
    }

    // 单字段校验，返回错误信息（空串表示通过）
    function checkField(field) {
        const spec = control.fields[field];
        if (spec === undefined)
            return "";

        const rawValue = spec.valueTransform
            ? spec.valueTransform(control.getValue(field)) : control.getValue(field);

        // 官方：Field 上设了 validator 就不再走 rules
        if (typeof spec.validator === "function") {
            const result = spec.validator(rawValue, control.values);
            if (result !== true && result !== "" && result !== undefined && result !== null)
                return result;
        } else if (spec.required && isEmptyValue(rawValue)) {
            // label.required / props.required 与 rules[{required}] 一样都会标必填
            return qsTr("此项为必填");
        } else {
            const rules = spec.rules || [];
            const found = [];
            for (let i = 0; i < rules.length; ++i) {
                const rule = rules[i];
                if (rule === undefined)
                    continue;
                const message = control.checkRule(rule, rawValue, control.values, field);
                if (message === "")
                    continue;
                found.push(message);
                // 官方 stopValidateWithError：命中第一条就不跑后续规则；不设时全部跑完，
                // 多条错误由 errorOf 按 ErrorMessage 的规则 join 成一条
                if (spec.stopValidateWithError || control.stopValidateWithError)
                    break;
            }
            if (found.length === 0)
                return "";
            return found.length === 1 ? found[0] : found;
        }
        return "";
    }

    function revalidateField(field) {
        control.setError(field, control.checkField(field));
    }

    // scope：不传 = 全量；字符串数组 = 只校验这些（含前缀，'a' 会命中 'a[0]'）；
    // 对象 = { fields, silent }，silent 时只算不写回。
    function validate(scope) {
        let fields = null;
        let silent = false;
        if (scope !== undefined) {
            if (Array.isArray(scope))
                fields = scope;
            else if (scope && typeof scope === "object") {
                fields = scope.fields !== undefined ? scope.fields : null;
                silent = scope.silent === true;
            }
        }

        const targets = control.fieldOrder.filter(function (f) {
            if (fields === null)
                return true;
            return fields.some(function (entry) {
                return f === entry || f.indexOf(entry + ".") === 0 || f.indexOf(entry + "[") === 0;
            });
        });

        const found = {};
        const formValidator = typeof control.validator === "function" ? control.validator : control.validateFields;
        if (typeof formValidator === "function") {
            // 官方：配置了 Form 级校验器后，Field 级校验器不再触发
            const result = formValidator(control.values) || {};
            targets.forEach(function (f) {
                const e = control.getPath(result, control.parsePath(f));
                if (e !== undefined && e !== null && e !== "")
                    found[f] = e;
            });
        } else {
            targets.forEach(function (f) {
                const message = control.checkField(f);
                if (message !== "")
                    found[f] = message;
            });
        }

        if (silent)
            return Object.keys(found).length === 0;

        if (fields === null)
            control.errors = ({});
        Object.keys(found).forEach(function (f) {
            control.errors = control.setPath(control.errors, control.parsePath(f), found[f]);
        });
        targets.forEach(function (f) {
            if (found[f] === undefined)
                control.errors = control.deletePath(control.errors, control.parsePath(f));
            control.setTouched(f, true);
        });
        control.errorChange(control.errors, found);
        control.change(control.getFormState());
        return Object.keys(found).length === 0;
    }

    // fields 不传 = 整表重置；传数组 = 只重置这些字段
    function reset(fields) {
        const targets = fields === undefined
            ? control.fieldOrder.slice()
            : control.fieldOrder.filter(function (f) {
                return fields.some(function (entry) {
                    return f === entry || f.indexOf(entry + ".") === 0 || f.indexOf(entry + "[") === 0;
                });
            });

        targets.forEach(function (f) {
            const spec = control.fields[f];
            const initial = spec && spec.valueAtMount !== undefined
                ? spec.valueAtMount
                : control.initValues[f];
            const keepEmpty = spec ? (spec.allowEmptyString || control.allowEmpty) : control.allowEmpty;
            control.writeFieldValue(f, initial, isEmptyValue(initial) && !keepEmpty);
            control.errors = control.deletePath(control.errors, control.parsePath(f));
            control.touched = control.deletePath(control.touched, control.parsePath(f));
        });

        control.valueChange(control.values, { fields: targets });
        control.change(control.getFormState());
        control.resetTriggered();
    }

    function submitForm() {
        if (control.validate())
            control.submit(control.values);
        else
            control.submitFail(control.errors, control.values);
    }

    Component.onCompleted: {
        if (typeof control.getFormApi === "function")
            control.getFormApi(control);
    }
}
