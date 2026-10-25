import QtQuick

// 表单项。对应官方 Semi 的 Field（即 Form.Input / Form.Select 那一层 HOC）：
// 负责 Label、控件、helpText/extraText、ErrorMessage 的排布，并把控件接到 Form 的 values 上。
//
//     FormItem {
//         field: "name"
//         label: "姓名"
//         rules: [{ required: true, message: "必填" }]
//
//         Input { width: 240 }
//     }
//
// 官方靠 Form.Input 这层 HOC 劫持控件的 value/onChange；QML 没有 HOC，这里按 valueKey
// 探测内层控件已有的属性（对应 withField 的 valueKey / onKeyChangeFnName），
// 探测不到时仍可自己写 onTextChanged: form.setValue(...)。
Item {
    id: control

    objectName: "formField"

    default property alias content: mainArea.data

    // 不写则沿 parent 链自动找所属 Form
    property var form: null

    // --- 官方 FieldProps ---
    property string field: ""
    // string，或 { text, required, optional, extra, align, width }
    property var label: undefined
    property bool required: false
    property string labelPosition: ""
    property string labelAlign: ""
    property real labelWidth: 0
    property bool noLabel: false
    property bool noErrorMessage: false
    property var initValue: undefined
    property var rules: []
    property var validator: null
    // default / error / warning / success，传入时优先于内部校验状态（仅影响样式）
    property string validateStatus: ""
    // change / blur / mount / custom 或其数组；空串表示继承 Form
    property var trigger: ""
    // 官方 FieldProps.transform；Item 已占用 FINAL 的 transform，这里只能换名
    property var valueTransform: null
    property var convert: null
    property bool allowEmptyString: false
    property bool keepState: false
    property bool stopValidateWithError: false
    property var helpText: ""
    property var extraText: ""
    property string extraTextPosition: ""
    property bool pure: false
    // 官方 withField 的 valueKey：内层控件表示「值」的属性名，留空则自动探测
    property string valueKey: ""
    // 块级铺满父容器（官方 field 是 block）。放进 Row 这类横向容器时要自己关掉。
    property bool stretch: control.formLayout !== "horizontal" && !control.isInInputGroup

    // Field 的值变化（官方 FieldProps.onChange）
    signal change(var value)

    readonly property var target: control.form !== null && control.form !== undefined
        ? control.form : control.searchForm()

    // 官方 merge 顺序：Field props 覆盖 Form props
    readonly property string formLayout: control.target ? control.target.layout : "vertical"
    readonly property string labelPos: control.labelPosition !== "" ? control.labelPosition
        : (control.target ? control.target.labelPosition : "top")
    readonly property string labelJustify: control.labelAlign !== "" ? control.labelAlign
        : (control.target ? control.target.labelAlign : "left")
    // 官方 <Label width={mergeLabelWidth} {...label} />：label 对象里的 width 最优先
    readonly property real labelBoxWidth: control.isObjectLabel() && control.label.width !== undefined
        ? Number(control.label.width)
        : (control.labelWidth > 0 ? control.labelWidth
            : (control.target && control.target.labelWidth > 0 ? control.target.labelWidth : 0))
    readonly property string extraPos: control.extraTextPosition !== "" ? control.extraTextPosition
        : (control.target ? control.target.extraTextPosition : "bottom")
    readonly property bool withCol: control.target !== null && control.target !== undefined
        && control.target.labelCol !== undefined && Object.keys(control.target.labelCol).length > 0
        && control.target.wrapperCol !== undefined && Object.keys(control.target.wrapperCol).length > 0

    // 官方在 InputGroup 内不再给子 Field 插 Label/ErrorMessage，Label 归组自己
    readonly property bool isInInputGroup: control.searchInputGroup() !== null
    // 组内位置，由 FormInputGroup 排布时写入，用来还原 .semi-input-group 的首尾圆角
    property int groupIndex: -1
    property int groupCount: -1

    readonly property var labelText: control.isObjectLabel()
        ? (control.label.text !== undefined ? control.label.text : control.field)
        : (control.label !== undefined ? control.label : control.field)
    readonly property bool labelRequired: control.required
        || (control.isObjectLabel() && control.label.required === true)
        || control.rulesRequire()
    readonly property bool labelOptional: control.isObjectLabel() && control.label.optional === true
    readonly property Component labelExtra: control.isObjectLabel()
        && control.label.extra !== undefined ? control.label.extra : null
    readonly property real labelObjWidth: control.isObjectLabel() && control.label.width !== undefined
        ? Number(control.label.width) : 0

    readonly property bool hasExtraText: control.extraText !== undefined && control.extraText !== null
        && control.extraText !== ""
    readonly property var currentValue: control.target ? control.target.getValue(control.field) : undefined
    readonly property string error: control.target ? control.target.errorOf(control.field) : ""
    readonly property bool hasError: control.error !== ""
    // 官方把 validateStatus 直接透传给控件（仅样式），这里换算成 Enums.Status
    readonly property int statusEnum: {
        if (control.validateStatus !== "")
            return control.validateStatus === "warning" ? Enums.StatusWarning
                : (control.validateStatus === "error" ? Enums.StatusDanger : Enums.StatusDefault);
        return control.hasError ? Enums.StatusDanger : Enums.StatusDefault;
    }

    // vertical 时铺满表单宽度（官方 field 是块级元素），横向容器里按内容排、右侧留 16
    width: control.stretch && control.parent ? control.parent.width
        : control.implicitWidth + control.paddingRight
    implicitWidth: Math.max(
        (control.labelPos === "left" && labelBlock.visible ? labelBlock.implicitWidth : 0)
            + mainColumn.implicitWidth,
        control.labelPos !== "left" && labelBlock.visible ? labelBlock.implicitWidth : 0)
    implicitHeight: control.paddingTop
        + (labelBlock.visible && control.labelPos !== "left" ? labelBlock.implicitHeight : 0)
        + Math.max(mainColumn.implicitHeight,
            labelBlock.visible && control.labelPos === "left" ? labelBlock.implicitHeight : 0)
        + control.paddingBottom

    // 官方 .semi-form-vertical .semi-form-field { padding: 12px 0 }
    readonly property real paddingTop: control.formLayout === "vertical" ? Theme.current.spacingBaseTight : 0
    readonly property real paddingBottom: control.formLayout === "vertical" ? Theme.current.spacingBaseTight : 0
    // 官方 .semi-form-horizontal .semi-form-field { padding-right: 16px }
    readonly property real paddingRight: control.formLayout === "horizontal" ? Theme.current.spacingBase : 0

    // 官方：(控件高 32 - 标签行高 20) / 2，让左标签首行与控件文字对齐
    readonly property real leftLabelPad: (Theme.current.heightControlDefault - 20) / 2

    function searchForm() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.registerField !== undefined && node.getFormState !== undefined)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    function searchInputGroup() {
        let node = control.parent;
        while (node !== null && node !== undefined) {
            // qmllint disable missing-property
            if (node.isFormInputGroup === true)
                return node;
            // qmllint enable missing-property
            node = node.parent;
        }
        return null;
    }

    function isObjectLabel() {
        return control.label !== undefined && control.label !== null && typeof control.label === "object";
    }

    function rulesRequire() {
        for (let i = 0; i < control.rules.length; ++i)
            if (control.rules[i] && control.rules[i].required === true)
                return true;
        return false;
    }

    // --- 与内层控件的接线 ---

    property var innerControl: null

    // 哪个属性是「值」。顺序照官方 withField（value 优先），再补上本模块各控件实际用的名字。
    // checked 排在 value 前：Checkbox / Switch / Radio 的值就是 checked，
    // 而 Checkbox 同时还有 value（那是它在组里的标识，不是状态）。
    readonly property var valueKeyCandidates: ["checked", "value", "values", "text", "color"]

    // 判「这个属性是值」不能只看当前值。InputNumber / PinCode / Rating 的 value 初始就是
    // undefined（undefined 正是「非受控」的哨兵），只看值就会判定它们没有 value，
    // 于是探测钻进控件内部、把它自己用的那只 Input 当成控件接上 —— 表现是
    // FormItem 往 InputNumber 里层写 text，官方那侧根本不该发生。
    // 所以：先按当前值挑（Select 的 value=null、values=[]，靠顺序分单 / 多选），
    // 一个都没值时再按「属性存不存在」挑 —— 存在性用 <name>Changed 信号判，与当前值无关。
    function valueKeyOf(node) {
        if (node === null || node === undefined)
            return "";
        const keys = control.valueKeyCandidates;
        for (let i = 0; i < keys.length; ++i) {
            // qmllint disable missing-property
            if (node[keys[i]] !== undefined)
                return keys[i];
            // qmllint enable missing-property
        }
        for (let i = 0; i < keys.length; ++i) {
            // qmllint disable missing-property
            if (node[keys[i] + "Changed"] !== undefined)
                return keys[i];
            // qmllint enable missing-property
        }
        return "";
    }

    readonly property string resolvedKey: {
        if (control.valueKey !== "")
            return control.valueKey;
        return control.valueKeyOf(control.innerControl);
    }

    property bool writingToControl: false

    function pushValueToControl() {
        const c = control.innerControl;
        if (c === null || c === undefined || control.resolvedKey === "")
            return;
        const stored = control.currentValue;
        if (stored === undefined)
            return;
        // qmllint disable missing-property
        if (String(c[control.resolvedKey]) === String(stored))
            return;
        control.writingToControl = true;
        c[control.resolvedKey] = stored;
        control.writingToControl = false;
        // qmllint enable missing-property
    }

    function pullValueFromControl() {
        const c = control.innerControl;
        if (c === null || c === undefined || control.resolvedKey === "" || control.writingToControl)
            return;
        // qmllint disable missing-property
        if (control.target) {
            control.target.setValue(control.field, c[control.resolvedKey]);
            control.change(c[control.resolvedKey]);
        }
        // qmllint enable missing-property
    }

    // 内层控件的值变化要写回 Form，但每种控件的信号名不同（textChanged / valueChanged / …），
    // Connections 只能静态声明。这里用 createQmlObject 把已探测到的名字拼成连接代码。
    property var wiring: null

    function reconnectWiring() {
        if (control.wiring !== null && control.wiring !== undefined) {
            control.wiring.destroy();
            control.wiring = null;
        }
        const key = control.resolvedKey;
        if (key === "" || control.innerControl === null || control.innerControl === undefined)
            return;
        const signal = "on" + key[0].toUpperCase() + key.substring(1) + "Changed";
        control.wiring = Qt.createQmlObject(
            "import QtQuick; Connections { target: control.innerControl; function "
            + signal + "() { control.pullValueFromControl() } }",
            control, "FormItemWiring");
    }

    // 失焦：置 touched，trigger 含 blur 时补一次校验（activeFocus 每个 Item 都有，可静态连）
    Connections {
        target: control.innerControl
        enabled: control.innerControl !== null && control.innerControl !== undefined

        function onActiveFocusChanged() {
            const c = control.innerControl;
            if (c === null || c === undefined || c.activeFocus || !control.target)
                return;
            control.target.setTouched(control.field, true);
            const trig = control.trigger !== "" ? control.trigger
                : (control.target ? control.target.trigger : "change");
            if (String(trig).indexOf("blur") >= 0)
                control.target.revalidateField(control.field);
        }
    }

    function spec() {
        return {
            rules: control.rules,
            label: control.labelText,
            // 只把显式的 required 传给 Form：官方 label.required / rules[{required}]
            // 都只影响星号与规则文案，不再额外套一层默认文案
            required: control.required,
            validator: control.validator,
            trigger: control.trigger,
            valueTransform: control.valueTransform,
            convert: control.convert,
            stopValidateWithError: control.stopValidateWithError,
            allowEmptyString: control.allowEmptyString,
            keepState: control.keepState,
            initValue: control.initValue
        };
    }

    function attach() {
        if (!control.target || control.field === "")
            return;
        const previous = control.target.fieldSpec(control.field);
        const next = control.spec();
        // valueAtMount 记录挂载时的初值，reset() 靠它复原；重新注册不能丢
        if (previous && previous.valueAtMount !== undefined)
            next.valueAtMount = previous.valueAtMount;
        control.target.registerField(control.field, next);

        const c = control.innerControl;
        if (c !== null && c !== undefined && control.labelPos === "inset" && !control.noLabel) {
            // 官方 inset 是把 label 交给控件的 insetLabel 渲染
            // qmllint disable missing-property
            if (c.insetLabel !== undefined)
                c.insetLabel = String(control.labelText);
            // qmllint enable missing-property
        }
        control.pushStateToControl();
        control.pushValueToControl();
    }

    // 官方 withField.tsx:597-608 把 validateStatus / disabled 一并铺到内层控件上，
    // 且写在 ...rest 之后（Field 上的同名 prop 会被覆盖）。这里等价：
    // validateStatus 用绑定持续跟随，disabled 只在 Form 说「禁用」时单向压下去，
    // 不把使用者写在自己控件上的 enabled: false 抬回来。
    readonly property bool formDisabled: control.target ? control.target.disabled === true : false

    function pushStateToControl() {
        const c = control.innerControl;
        if (c === null || c === undefined)
            return;
        // qmllint disable missing-property
        try {
            if (c.validateStatus !== undefined && typeof c.validateStatus === "number")
                c.validateStatus = Qt.binding(function () { return control.statusEnum });
            if (control.formDisabled && c.enabled !== undefined && typeof c.enabled === "boolean")
                c.enabled = false;
        } catch (e) { }
        // qmllint enable missing-property
    }

    onFormDisabledChanged: control.pushStateToControl()

    function locateControl() {
        // 显式给了 valueKey 就直接用第一层子项（那是使用者指认的控件），
        // 只有自动探测时才往下找一层
        control.innerControl = control.valueKey !== ""
            ? (mainArea.children.length > 0 ? mainArea.children[0] : null)
            : control.probeControl(mainArea, 0);
        control.reconnectWiring();
        control.attach();
        control.applyGroupCorners();
    }

    function hasValueProperty(node) {
        return control.valueKeyOf(node) !== "";
    }

    // 官方 Field 直接就是控件；我们的控件偶尔包在一层 Row/Column 里（例如 Input 加个单位文字），
    // 所以直接子项没有可接管的属性时再往下找一层。
    function probeControl(node, depth) {
        if (node === null || node === undefined || depth > 2)
            return null;
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            if (kids[i] !== undefined && hasValueProperty(kids[i]))
                return kids[i];
        }
        for (let i = 0; i < kids.length; ++i) {
            const found = control.probeControl(kids[i], depth + 1);
            if (found !== null)
                return found;
        }
        return null;
    }

    // .semi-input-group 里中间的控件切平四角，首尾各留一侧圆角
    function applyGroupCorners() {
        const c = control.innerControl;
        if (c === null || c === undefined || !control.isInInputGroup)
            return;
        // qmllint disable missing-property
        try {
            if (c.topLeftRadius === undefined) {
                c.radius = 0;
                return;
            }
            // 四个角都显式赋值：只改该圆的那两侧的话，上一次排布留下的圆角不会被清掉
            const r = Theme.current.radiusSmall;
            const first = control.groupIndex === 0;
            const last = control.groupIndex === control.groupCount - 1;
            c.radius = 0;
            c.topLeftRadius = first ? r : 0;
            c.bottomLeftRadius = first ? r : 0;
            c.topRightRadius = last ? r : 0;
            c.bottomRightRadius = last ? r : 0;
        } catch (e) {
            // 内层控件不接受圆角赋值时保持原样
        }
        // qmllint enable missing-property
    }

    Component.onCompleted: control.locateControl()
    Component.onDestruction: {
        if (control.target)
            control.target.unregisterField(control.field, control.keepState);
    }

    onRulesChanged: control.attach()
    onValidatorChanged: control.attach()
    onRequiredChanged: control.attach()
    onTriggerChanged: control.attach()
    onInnerControlChanged: control.locateControl()

    // 外部（formApi.setValue、字段联动、reset）改动 values 后同步回控件
    Connections {
        target: control.target
        enabled: control.target !== null && control.target !== undefined

        // reset / setValues 不带 field，所以一律尝试回推（值相同会自己早退）
        function onValueChange() {
            control.pushValueToControl();
        }
    }

    // --- 布局 ---

    FormLabel {
        id: labelBlock

        visible: !control.noLabel && !control.pure && !control.isInInputGroup
            && control.labelPos !== "inset"
        x: 0
        y: control.paddingTop
        // 官方 withCol 时标签宽取 labelCol.span / 24
        width: control.withCol
            ? Math.round(control.width * (control.target.labelCol.span || 0) / 24)
            : (control.labelBoxWidth > 0 ? control.labelBoxWidth : labelBlock.implicitWidth)
        height: implicitHeight
        text: control.labelText
        required: control.labelRequired
        optional: control.labelOptional
        extra: control.labelExtra
        align: control.labelJustify
        labelWidth: control.labelObjWidth > 0 ? control.labelObjWidth : control.labelBoxWidth
        padTop: control.labelPos === "left" ? control.leftLabelPad : 0
        blockLevel: control.labelPos !== "left"
        disabled: control.target ? control.target.disabled : false
    }

    Column {
        id: mainColumn

        objectName: "fieldMain"

        x: control.labelPos === "left" ? labelBlock.width : 0
        // top 位置的标签占一行，主体要往下让出标签高度
        y: control.paddingTop + (labelBlock.visible && control.labelPos !== "left"
            ? labelBlock.implicitHeight : 0)
        // 官方 .semi-form-field-main { width: 100% }；left 时是 flex 剩下的宽度
        width: control.withCol
            ? Math.round(control.width * (control.target.wrapperCol.span || 0) / 24)
            : (control.labelPos === "left"
                ? Math.max(0, control.width - labelBlock.width - control.paddingRight)
                : Math.max(0, control.width - control.paddingRight))
        spacing: 0

        Item {
            // extraText position=middle：Label 与控件之间
            visible: control.hasExtraText && control.extraPos === "middle" && !control.pure
                && !control.isInInputGroup
            width: mainColumn.width
            implicitHeight: extraMiddle.implicitHeight

            FormErrorMessage {
                id: extraMiddle

                error: ""
                helpText: control.extraText
                showValidateIcon: false
                isExtraText: true
            }
        }

        Item {
            id: mainArea

            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height

            // 内层控件是在 FormItem 自己的 Component.onCompleted 之后才挂进来的，
            // 只靠 onCompleted 会探测不到，initValue 也就推不进控件
            onChildrenChanged: control.locateControl()
        }

        FormErrorMessage {
            id: messageBlock

            visible: !control.noErrorMessage && !control.pure && !control.isInInputGroup
            error: control.error
            helpText: control.helpText
            validateStatus: control.hasError ? "error"
                : (control.validateStatus !== "" ? control.validateStatus : "default")
            showValidateIcon: control.target ? control.target.showValidateIcon : true
        }

        Item {
            // extraText position=bottom：ErrorMessage 之后，常显
            visible: control.hasExtraText && control.extraPos === "bottom" && !control.pure
                && !control.isInInputGroup
            width: mainColumn.width
            implicitHeight: extraBottom.implicitHeight

            FormErrorMessage {
                id: extraBottom

                error: ""
                helpText: control.extraText
                showValidateIcon: false
                isExtraText: true
            }
        }
    }
}
