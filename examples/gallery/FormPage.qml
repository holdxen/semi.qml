pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Form 的官方示例集。小节标题与 examples/gallery/data/docs.json 里从官网文档抓的标题一一对应，
// 说明文字由 GalleryShell 按标题取，这里只写 demo。
//
// 官网 27 节里没落的两节：Hooks 的使用、HOC 的使用（useFormState / useFormApi /
// withFormState / withFormApi 都依附 React 的组件树注入机制，QML 侧引用 id 就能拿到 Form）；
// ARIA 一节描述的是 DOM 上的 aria-* 属性，本库组件目前没有接 Accessible。
// 「声明表单的多种写法」里的 render / children render function / component 三种声明子节点的
// 方式同属 React 结构，那一节只落了基本写法。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 密码强度：Field 校验函数顺手写回，helpText / validateStatus 用它
    property string passwordHelp: ""
    property string passwordStatus: "default"
    property bool showConditional: true
    property int slotTabHint: 0
    property string silentResult: ""
    // 「Modal 弹出层中的表单」：Modal 是受控的，开合这个 bool 的就是本节自己
    property bool modalFormOpen: false
    // 「如何获取 formApi」一节：getFormApi 回调存下来的引用，按钮在 Form 外部
    property var formApi: null
    property string formApiProbe: ""

    // 外部读 formApi 的 getter 时，没值就显示占位符而不是 "undefined"
    function apiShown(v) {
        return v === undefined || v === null || v === "" ? "-" : String(v);
    }

    Component {
        id: helpExtra

        Item {
            id: helpHolder

            implicitWidth: helpIcon.implicitWidth
            implicitHeight: helpIcon.implicitHeight

            Icon {
                id: helpIcon

                name: "help_circle"
                size: 16
                color: Theme.current.colorText2
            }

            Tooltip {
                target: helpHolder
                text: qsTr("密码长度至少 6 位")
            }
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "声明表单的多种写法"

            // 官方这一节里「基本写法」以外的那三种（render / children fn / component）是 React
            // 声明子节点的方式，QML 里子节点就是子节点，没有可对应的形态。
            Text {
                text: qsTr("基本写法：给控件加 field 放进 Form，label 可以是字符串或对象")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                width: 560
                layout: "horizontal"

                FormItem {
                    field: "UserName"
                    label: qsTr("用户名")

                    Input { width: 80 }
                }

                FormItem {
                    field: "Password"
                    label: ({ text: qsTr("密码"), extra: helpExtra })

                    Input { width: 176; placeholderText: qsTr("请输入密码") }
                }

                FormItem {
                    field: "Role"
                    label: ({ text: qsTr("角色"), optional: true })

                    Select {
                        width: 176
                        placeholder: qsTr("请选择")
                        options: [
                            { label: qsTr("管理员"), value: "admin" },
                            { label: qsTr("普通用户"), value: "user" },
                            { label: qsTr("访客"), value: "guest" }
                        ]
                    }
                }
            }
        }

        GallerySection {
            title: "已支持的表单控件"

            Form {
                id: catalogForm

                width: 720
                initValues: ({ switch: true, number: 20, range: 10, rating: 2 })
                onValueChange: (values, changed) => {
                    console.log("catalog changed:", JSON.stringify(changed));
                }

                FormSection {
                    text: qsTr("基本信息")

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "name"
                                label: qsTr("名称（Input）")
                                initValue: "mikeya"
                                trigger: "blur"

                                Input { width: 280 }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "date"
                                label: qsTr("日期（DatePicker）")

                                DatePicker { width: 280; placeholder: qsTr("请选择生效日期") }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "role"
                                label: qsTr("角色（Select）")

                                Select {
                                    width: 280
                                    placeholder: qsTr("请选择你的角色")
                                    options: [
                                        { label: qsTr("运营"), value: "operate" },
                                        { label: qsTr("开发"), value: "rd" },
                                        { label: qsTr("产品"), value: "pm" },
                                        { label: qsTr("设计"), value: "ued" }
                                    ]
                                }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "business"
                                label: qsTr("业务线（多选Select）")
                                valueKey: "values"
                                extraText: qsTr("没有找到合适的业务线？")

                                Select {
                                    width: 280
                                    multiple: true
                                    placeholder: qsTr("请选择业务线")
                                    options: [
                                        { label: "Semi", value: "abc" },
                                        { label: qsTr("轻颜相机"), value: "ulikeCam" },
                                        { label: qsTr("今日头条"), value: "toutiao" }
                                    ]
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "area"
                                label: qsTr("地区（Cascader）")

                                Cascader {
                                    width: 280
                                    placeholder: qsTr("请选择所在地区")
                                    options: [{
                                        label: qsTr("亚洲"), value: "Asia", children: [{
                                            label: qsTr("中国"), value: "China", children: [{
                                                label: qsTr("北京"), value: "Beijing"
                                            }, {
                                                label: qsTr("上海"), value: "Shanghai"
                                            }]
                                        }]
                                    }, {
                                        label: qsTr("北美洲"), value: "NorthAmerica"
                                    }]
                                }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "tree"
                                label: qsTr("节点（TreeSelect）")

                                TreeSelect {
                                    width: 280
                                    placeholder: qsTr("请选择服务节点")
                                    treeData: [{
                                        label: qsTr("亚洲"), value: "Asia", children: [{
                                            label: qsTr("中国"), value: "China"
                                        }]
                                    }]
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "product"
                                label: qsTr("产品（TagInput）")
                                initValue: ["abc", "ulikeCam"]

                                // 官方受控模型：FormItem 把 Form 的值推给 value，
                                // 用户改动再由 onChange 写回 Form
                                TagInput {
                                    width: 280
                                    placeholder: qsTr("请输入产品")
                                    onChange: (v) => catalogForm.setValue("product", v)
                                }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "time"
                                label: qsTr("截止时刻（TimePicker）")

                                TimePicker { width: 280 }
                            }
                        }
                    }
                }

                FormSection {
                    text: qsTr("资源详情")

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "description"
                                label: qsTr("申请理由（TextArea）")

                                TextArea { width: 280; height: 76; placeholderText: qsTr("请填写申请资源理由") }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        // 官方这两组在同一个 <Col span={12}> 里（Col 本身竖排），
                            // 端口直接用一个 Column 摞起来（Column 得显式给宽，
                            // 否则 FormItem 按 parent.width 算出来的内容是 0 宽）
                            Column {
                                width: parent.width

                                FormItem {
                                    field: "type"
                                    label: qsTr("申请类型（CheckboxGroup）")
                                    initValue: ["user", "admin"]
                                    rules: [{ required: true }]

                                    CheckboxGroup {
                                        direction: Enums.DirectionHorizontal
                                        options: ["admin", "user", "guest", "root"]
                                    }
                                }

                                FormItem {
                                    field: "isMonopolize"
                                    label: qsTr("是否独占资源（Radio）")
                                    valueKey: "value"
                                    rules: [{ type: "boolean" },
                                        { required: true, message: qsTr("必须选择是否独占") }]

                                    // 官方的 Form.RadioGroup 由 withField 把 onChange 接进 Form；本库
                                    // FormItem 只按 <valueKey>Changed 接线，而组的信号叫 changed，
                                    // 所以回写这一行得自己接（RadioGroup 被推成受控，值仍以 Form 为准）
                                    RadioGroup {
                                        onChanged: (v) => catalogForm.setValue("isMonopolize", v)

                                        Radio { value: 1; text: qsTr("是") }
                                        Radio { value: 0; text: qsTr("否") }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "number"
                                label: qsTr("申请数量（InputNumber）")

                                InputNumber { width: 280 }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "range"
                                label: qsTr("资源使用报警阈值(%)（Slider）")

                                Slider { width: 240 }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "switch"
                                label: qsTr("开关（Switch）")

                                Switch { }
                            }
                        }

                        Column {
                            width: parent.width * 12 / 24

                                                        FormItem {
                                field: "rating"
                                label: qsTr("满意度（Rating）")
                                valueKey: "value"

                                // Rating 的提交信号叫 changed（官方 onChange），FormItem 只
                                // 认 `<valueKey>Changed`，所以回写这一行得手写 —— 与下面几处
                                // RadioGroup 同一缺口，见 docs/gallery-progress.md 已知问题 13。
                                Rating {
                                    onChanged: (v) => catalogForm.setValue("rating", v)
                                }
                            }
                        }
                    }
                }

                FormItem {
                    field: "agree"
                    noLabel: true

                    Checkbox { text: qsTr("我已阅读并清楚相关规定（Checkbox）") }
                }

                // Space 从 Row（位置器有 topPadding）换成 Item 根后非法了（坑 125）——
                // 官方 SpaceProps 没有这条，等价改成 Form 流里的一行高占位
                Item { width: parent.width; height: Theme.current.spacingTight }

                Space {

                    Button {
                        text: qsTr("提交(submit)")
                        tone: Enums.Primary
                        onClicked: catalogForm.submitForm()
                    }

                    Button {
                        text: qsTr("重置(reset)")
                        onClicked: catalogForm.reset()
                    }
                }
            }
        }

        GallerySection {
            title: "表单控件值的绑定"

            Form {
                id: pathForm

                width: 720
                allowEmpty: false

                Row {
                    width: 360

                    

                    Column {
                        width: parent.width * 24 / 24

                                                Column {
                            width: parent.width
                            spacing: 0

                            FormItem {
                                field: "username"

                                Input { width: 300; placeholderText: qsTr("请尝试输入值") }
                            }

                            FormItem {
                                field: "user[0]"

                                Input { width: 300; placeholderText: qsTr("请尝试输入值") }
                            }

                            FormItem {
                                field: "siblings.1"

                                Input { width: 300; placeholderText: qsTr("请尝试输入值") }
                            }

                            FormItem {
                                field: "siblings['2']"

                                Input { width: 300; placeholderText: qsTr("请尝试输入值") }
                            }

                            FormItem {
                                field: "parents[0].name"

                                Input { width: 300; placeholderText: qsTr("请尝试输入值") }
                            }

                            FormItem {
                                field: "parents[1]['name']"

                                Input { width: 300; placeholderText: qsTr("请尝试输入值") }
                            }
                        }
                    }
                }

                FormLabel { text: qsTr("FormState 实时映射值：") }

                TextArea {
                    width: 460
                    height: 160
                    readOnly: true
                    text: JSON.stringify(pathForm.values, null, 2)
                }
            }
        }

        GallerySection {
            title: "表单布局"

            Text {
                text: qsTr("垂直布局（默认）：Semi Design 更推荐表单采用垂直布局")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                id: loginForm

                width: 400

                FormItem {
                    field: "phone"
                    label: "PhoneNumber"

                    Input { width: 360; placeholderText: qsTr("Enter your phone number") }
                }

                FormItem {
                    field: "password"
                    label: "Password"

                    Input { width: 360; echoMode: TextInput.Password; placeholderText: qsTr("Enter your password") }
                }

                FormItem {
                    field: "agree"
                    noLabel: true

                    Checkbox { text: qsTr("I have read and agree to the terms of service") }
                }

                Item {
                    width: 360
                    height: 32

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Or")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }

                    Button {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Sign up")
                        variant: Enums.Borderless
                        color: Theme.current.colorPrimary
                    }

                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Log in")
                        variant: Enums.Tertiary
                        enabled: loginForm.values.agree === true
                        onClicked: loginForm.submitForm()
                    }
                }
            }

            Text {
                topPadding: Theme.current.spacingLoose
                text: qsTr("水平布局：layout='horizontal'")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                width: 620
                layout: "horizontal"

                FormItem {
                    field: "h_phone"
                    label: "PhoneNumber"

                    Input { width: 180; placeholderText: qsTr("Enter your phone number") }
                }

                FormItem {
                    field: "h_password"
                    label: "Password"

                    Input { width: 180; placeholderText: qsTr("Enter your password") }
                }
            }

            Text {
                topPadding: Theme.current.spacingLoose
                text: qsTr("labelPosition / labelAlign：可用下面的下拉框切换")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Row {
                width: 620
                spacing: Theme.current.spacingTight
                bottomPadding: Theme.current.spacingTight

                Select {
                    id: posSelect

                    width: 200
                    prefixIcon: ""
                    value: "left"
                    options: [{ label: "top", value: "top" }, { label: "left", value: "left" }]
                }

                Select {
                    id: alignSelect

                    width: 200
                    value: "left"
                    options: [{ label: "left", value: "left" }, { label: "right", value: "right" }]
                }
            }

            Item {
                width: 620
                height: 1 + Theme.current.spacingBase

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.current.colorBorder
                }
            }

            Form {
                id: labelPositionDemo

                width: 620
                labelPosition: posSelect.value
                labelAlign: alignSelect.value
                // 官方 demo 里 labelPosition 切到 left 时才给固定 labelWidth
                labelWidth: labelPosition === "left" ? 180 : 0

                FormItem {
                    field: "layout_input"
                    label: qsTr("手机号码")
                    trigger: "blur"
                    rules: [
                        { required: true, message: qsTr("required error") },
                        { type: "string", message: qsTr("type error") },
                        { validator: (rule, value) => value === "semi", message: qsTr("should be semi") }
                    ]

                    Input { width: 200 }
                }

                FormItem {
                    field: "layout_switch"
                    label: qsTr("是否同意")

                    Switch { }
                }

                FormItem {
                    field: "layout_price"
                    label: qsTr("价格")

                    InputNumber { width: 200 }
                }

                FormItem {
                    field: "layout_name"
                    label: qsTr("姓名")

                    Select {
                        width: 200
                        options: [{ label: "mike", value: "mike" }, { label: "jane", value: "jane" },
                            { label: "kate", value: "kate" }]
                    }
                }

                FormItem {
                    field: "layout_role"
                    label: qsTr("角色")

                    CheckboxGroup {
                        direction: Enums.DirectionHorizontal
                        options: ["admin", "user", "guest", "root"]
                    }
                }

                FormItem {
                    field: "性别"          // 官方这个 field 就是中文（index.md:603）
                    label: qsTr("性别")
                    valueKey: "value"

                    RadioGroup {
                        onChanged: (v) => labelPositionDemo.setValue("性别", v)

                        Radio { value: "1"; text: "man" }
                        Radio { value: "2"; text: "woman" }
                    }
                }
            }

            Text {
                topPadding: Theme.current.spacingLoose
                text: qsTr("更复杂的布局：多列一行（官方用 Grid 的 Row/Col，端口用 QML 的 Row + 等分 Column）")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                width: 800

                Row {
                    width: parent.width
                    
                    
                    spacing: Theme.current.spacingBase

                    Column {
                        width: parent.width * 8 / 24

                                                FormItem {
                            field: "nickName1"
                            label: qsTr("用户名")
                            trigger: "blur"

                            Input { width: 220 }
                        }
                    }

                    Column {
                        width: parent.width * 8 / 24

                                                FormItem {
                            field: "date1"
                            label: qsTr("有效日期")

                            DatePicker { width: 220 }
                        }
                    }

                    Column {
                        width: parent.width * 8 / 24

                                                FormItem {
                            field: "business1"
                            label: qsTr("业务线")

                            Select {
                                width: 220
                                options: [{ label: "Semi", value: "abc" },
                                    { label: qsTr("轻颜相机"), value: "ulikeCam" }]
                            }
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "表单分组"

            Form {
                id: groupingForm

                width: 560

                FormSection {
                    text: qsTr("基本信息")

                    FormItem {
                        field: "exam_name"
                        label: qsTr("考试名称")
                        initValue: qsTr("TCS任务平台使用")

                        Input { width: 560 }
                    }
                }

                FormSection {
                    text: qsTr("合格标准")

                    // 官方这里是一个 display:flex 的 div 包两个 InputNumber
                    Row {
                        spacing: 0

                        FormItem {
                            field: "pass"
                            label: ({ text: qsTr("及格正确率"), required: true })
                            initValue: 60
                            stretch: false

                            InputNumber { width: 80 }
                        }

                        FormItem {
                            field: "pass_number"
                            label: ({ text: qsTr("合格人数"), required: true })
                            initValue: 10
                            stretch: false

                            InputNumber { width: 80 }
                        }
                    }
                }

                FormSection {
                    text: qsTr("考试时间")

                    FormItem {
                        field: "exam_date"
                        label: ({ text: qsTr("开始时间"), required: true })

                        DatePicker { width: 272; type: Enums.TypeDateTime }
                    }

                    FormItem {
                        field: "exam_duration"
                        label: qsTr("考试时长")
                        initValue: "60"

                        Row {
                            Input { width: 176 }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: Theme.current.spacingExtraTight
                                text: qsTr("分钟")
                                color: Theme.current.colorText2
                                font.pixelSize: Theme.current.fontSizeRegular
                            }
                        }
                    }

                    FormItem {
                        field: "type"
                        label: qsTr("有效时间")
                        initValue: "always"
                        valueKey: "value"

                        RadioGroup {
                            direction: Enums.DirectionVertical
                            onChanged: (v) => groupingForm.setValue("type", v)

                            Radio { value: "always"; text: qsTr("永久有效") }
                            Radio { value: "user"; text: qsTr("自定义有效期") }
                        }
                    }

                    FormItem {
                        field: "answerTime"
                        label: qsTr("答案放出时间")
                        initValue: "always"
                        valueKey: "value"
                        rules: [{ required: true }]

                        RadioGroup {
                            direction: Enums.DirectionVertical
                            onChanged: (v) => groupingForm.setValue("answerTime", v)

                            Radio { value: "always"; text: qsTr("自动放出") }
                            Radio { value: "user"; text: qsTr("自定义放出时间") }
                        }
                    }

                    // 官方把 Form.DatePicker 直接嵌在第二个 Radio 的文案里（index.md:734-739），
                    // 本库 Radio 的文案位只收字符串，接不下任意子节点，只能摆到下一行
                    Loader {
                        active: groupingForm.values.answerTime === "user"
                        sourceComponent: customTimeItem
                    }

                    Component {
                        id: customTimeItem

                        FormItem {
                            field: "customTime"
                            noLabel: true

                            DatePicker {
                                width: 464
                                type: Enums.TypeDateTimeRange
                            }
                        }
                    }
                }

                FormSection {
                    text: qsTr("考试人员")

                    FormItem {
                        field: "exam_open"
                        label: ({ text: qsTr("对外开放"), required: true })

                        Switch { checkedText: qsTr("开"); uncheckedText: qsTr("关") }
                    }

                    FormItem {
                        field: "exam_users"
                        label: ({ text: qsTr("考生"), required: true })
                        valueKey: "values"
                        initValue: ["1", "2", "3", "4"]

                        Select {
                            width: 560
                            multiple: true
                            options: [{ label: qsTr("曲晨一"), value: "1" },
                                { label: qsTr("夏可曼"), value: "2" },
                                { label: qsTr("曲晨三"), value: "3" },
                                { label: qsTr("蔡妍"), value: "4" }]
                        }
                    }
                }

                // Space 从 Row（位置器有 topPadding）换成 Item 根后非法了（坑 125）——
                // 官方 SpaceProps 没有这条，等价改成 Form 流里的一行高占位
                Item { width: parent.width; height: Theme.current.spacingTight }

                Space {

                    Button { text: qsTr("创建考试"); tone: Enums.Primary; variant: Enums.Solid }
                    Button { text: qsTr("预览") }
                }
            }
        }

        GallerySection {
            title: "wrapperCol / labelCol"

            Form {
                width: 620
                labelPosition: "left"
                labelAlign: "right"
                labelCol: ({ span: 3 })
                wrapperCol: ({ span: 12 })

                FormItem {
                    field: "col_name"
                    label: qsTr("姓名")
                    trigger: "blur"

                    Input { width: 250; placeholderText: qsTr("请输入姓名") }
                }

                FormItem {
                    field: "col_role"
                    label: qsTr("角色")

                    Select {
                        width: 250
                        placeholder: qsTr("请选择角色")
                        options: [{ label: qsTr("运营"), value: "operate" },
                            { label: qsTr("开发"), value: "rd" },
                            { label: qsTr("产品"), value: "pm" },
                            { label: qsTr("设计"), value: "ued" }]
                    }
                }
            }
        }

        GallerySection {
            title: "隐藏Label"

            Form {
                width: 420

                FormItem {
                    field: "no_label_name"
                    label: qsTr("姓名")
                    noLabel: true
                    trigger: "blur"
                    rules: [{ required: true, message: qsTr("姓名不能为空") }]

                    Input { width: 250; placeholderText: qsTr("noLabel：不插 Label，但仍显示错误") }
                }

                FormItem {
                    field: "pure_name"
                    label: qsTr("姓名")
                    pure: true

                    Input { width: 250; placeholderText: qsTr("pure：DOM 结构与普通 Input 完全一致") }
                }
            }
        }

        GallerySection {
            title: "内嵌 Label"

            Form {
                width: 620
                layout: "horizontal"
                labelPosition: "inset"

                FormItem {
                    field: "inset_name"
                    label: qsTr("姓名")
                    trigger: "blur"
                    initValue: "semi"

                    Input { width: 250; placeholderText: qsTr("请输入姓名") }
                }

                FormItem {
                    field: "inset_role"
                    label: qsTr("角色")
                    initValue: "rd"

                    Select {
                        width: 250
                        options: [{ label: qsTr("运营"), value: "operate" },
                            { label: qsTr("开发"), value: "rd" },
                            { label: qsTr("产品"), value: "pm" },
                            { label: qsTr("设计"), value: "ued" }]
                    }
                }
            }
        }

        GallerySection {
            title: "导出 Label、ErrorMessage 使用"

            Column {
                spacing: Theme.current.spacingBase
                width: 420

                FormLabel { text: qsTr("我是导出的 Label"); required: true }

                Row {
                    spacing: Theme.current.spacingBase

                    FormLabel {
                        text: qsTr("右对齐")
                        align: "right"
                        labelWidth: 96
                    }

                    Input { width: 240 }
                }

                FormErrorMessage {
                    error: qsTr("我是导出的 ErrorMessage")
                    validateStatus: "error"
                }

                FormErrorMessage {
                    error: [qsTr("第一条错误"), qsTr("第二条错误")]
                    validateStatus: "error"
                }

                FormErrorMessage { helpText: qsTr("我是 helpText，没有错误时也常显") }
            }
        }

        GallerySection {
            title: "使用 Form.Slot 放置自定义组件"

            Form {
                width: 600
                labelPosition: "left"
                labelWidth: 100

                FormItem {
                    field: "slot_effect"
                    label: qsTr("特效名称")

                    Input { width: 250 }
                }

                FormSlot {
                    label: ({ text: "SlotA" })
                    error: qsTr("我是 SlotA 的 ErrorMessage")

                    Text {
                        text: qsTr("我是 Semi Form SlotA，我是自定义的内容")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }

                FormSlot {
                    label: ({ text: "SlotB", width: 160, align: "right" })

                    Text {
                        text: qsTr("我是 Semi Form SlotB，我的 Label Align、Width 与众不同")
                        color: Theme.current.colorText1
                        font.pixelSize: Theme.current.fontSizeRegular
                    }
                }
            }
        }

        GallerySection {
            title: "使用 helpText、extraText 放置提示信息"

            Form {
                id: helpForm

                width: 480
                showValidateIcon: true

                FormItem {
                    field: "Password"
                    // 官方在 validator 里 setState 更新 helpText / validateStatus，
                    // 这里把同样的副作用写到页面的两个属性上，FormItem 绑定它们
                    validator: (value) => {
                        if (!value) {
                            page.passwordStatus = "error";
                            page.passwordHelp = "";
                            return qsTr("密码不能为空");
                        }
                        if (value.length <= 3) {
                            page.passwordStatus = "warning";
                            page.passwordHelp = qsTr("密码强度：弱");
                        } else {
                            page.passwordStatus = "success";
                            page.passwordHelp = "";
                        }
                        return "";
                    }
                    validateStatus: page.passwordStatus
                    helpText: page.passwordHelp
                    extraText: randomExtra

                    Input { width: 300; echoMode: TextInput.Password }
                }

                Text {
                    topPadding: Theme.current.spacingTight
                    text: qsTr("validateStatus：%1 · touched：%2").arg(
                            page.passwordStatus).arg(String(helpForm.getTouched("Password")))
                        + (helpForm.errors["Password"] !== undefined ? "" : "")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }

            Component {
                id: randomExtra

                Text {
                    text: qsTr("没有想到合适的密码？点击随机生成一个")
                    color: Theme.current.colorLink
                    font.pixelSize: Theme.current.fontSizeRegular
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const pw = Math.floor(Math.random() * 100000).toString();
                            helpForm.setValue("Password", pw);
                            helpForm.setError("Password", "");
                            page.passwordHelp = "";
                            page.passwordStatus = "success";
                        }
                    }
                }
            }

            Text {
                topPadding: Theme.current.spacingLoose
                text: qsTr("extraTextPosition：'middle' 让 extraText 出现在 Label 与控件之间")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                id: randomExtraForm

                width: 560
                extraTextPosition: "middle"

                FormItem {
                    field: "notify"
                    label: qsTr("通知方式")
                    extraText: qsTr("未勾选时，默认为红点提醒，消息默认进入收件人消息列表。")

                    CheckboxGroup {
                        direction: Enums.DirectionHorizontal
                        options: [{ label: qsTr("飞书通知"), value: "lark" },
                            { label: qsTr("邮件通知"), value: "email" },
                            { label: qsTr("顶部横幅通知"), value: "notification" }]
                    }
                }

                FormItem {
                    field: "force_read"
                    label: qsTr("强制读取(可选)")
                    extraTextPosition: "bottom"
                    extraText: qsTr("对于对话框通知，可指定该消息必须在指定时长后才可置为已读。")

                    InputNumber { width: 200 }
                }
            }
        }

        GallerySection {
            title: "使用 InputGroup 组合多个 Field"

            Form {
                id: phoneForm

                width: 420

                FormInputGroup {
                    label: ({ text: qsTr("手机号码"), required: true })

                    FormItem {
                        field: "phonePrefix"
                        initValue: "+86"
                        rules: [{ required: true }]

                        Select {
                            width: 150
                            options: [{ label: qsTr("美国+1"), value: "+1" },
                                { label: qsTr("香港+852"), value: "+852" },
                                { label: qsTr("中国+86"), value: "+86" },
                                { label: qsTr("日本+81"), value: "+81" }]
                        }
                    }

                    FormItem {
                        field: "phoneNumber"
                        initValue: "18912345678"
                        rules: [{ required: true }]

                        Input { width: 250 }
                    }
                }

                FormItem {
                    field: "group_name"
                    label: qsTr("姓名")
                    trigger: "blur"
                    initValue: "Semi"

                    Input { width: 400 }
                }

                Row {
                    topPadding: Theme.current.spacingBase

                    Button {
                        text: qsTr("提交")
                        onClicked: phoneForm.submitForm()
                    }
                }
            }
        }

        GallerySection {
            title: "Modal 弹出层中的表单"

            Button {
                text: qsTr("打开弹窗")
                onClicked: page.modalFormOpen = true
            }

            Modal {
                id: modalHost

                title: qsTr("新建")
                width: 600
                visible: page.modalFormOpen

                onOk: {
                    if (modalFormInner.validate())
                        page.modalFormOpen = false;
                }
                onCancel: page.modalFormOpen = false

                Form {
                    id: modalFormInner

                    width: parent ? parent.width : 560

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 5 / 24

                                                        FormItem {
                                field: "region"
                                label: qsTr("国家/地区")
                                rules: [{ required: true, message: qsTr("该项为必填项") }]

                                Select {
                                    width: 140
                                    placeholder: qsTr("请选择")
                                    options: [{ label: qsTr("中国"), value: "China" },
                                        { label: qsTr("美国"), value: "US" },
                                        { label: qsTr("欧洲"), value: "Europe" },
                                        { label: qsTr("日本"), value: "Japan" }]
                                }
                            }
                        }

                        Column {
                            width: parent.width * 17 / 24

                                                        FormItem {
                                field: "owner"
                                label: qsTr("业务执行人")
                                trigger: "blur"
                                rules: [{ required: true, message: qsTr("该项为必填项") }]

                                Input { width: 300 }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        

                        Column {
                            width: parent.width * 5 / 24

                                                        FormItem {
                                field: "area"
                                label: qsTr("投放区域")
                                rules: [{ required: true, message: qsTr("该项为必填项") }]

                                Select {
                                    width: 140
                                    placeholder: qsTr("请选择")
                                    options: [{ label: qsTr("中国"), value: "China" },
                                        { label: qsTr("美国"), value: "US" }]
                                }
                            }
                        }

                        Column {
                            width: parent.width * 17 / 24

                                                        FormItem {
                                field: "department"
                                label: qsTr("业务执行部门")
                                trigger: "blur"
                                rules: [{ required: true, message: qsTr("该项为必填项") }]

                                Input { width: 300 }
                            }
                        }
                    }
                }
            }
        }

        GallerySection {
            title: "配置初始值与校验规则"

            Form {
                id: rulesForm

                width: 480
                initValues: ({ name: "semi", shortcut: "se" })

                FormItem {
                    field: "name"
                    trigger: "blur"
                    rules: [
                        { required: true, message: qsTr("required error") },
                        { type: "string", message: qsTr("type error") },
                        { validator: (rule, value) => value === "semi", message: qsTr("should be semi") },
                        { validator: (rule, value) => Boolean(value && value.startsWith("se")),
                            message: qsTr("should startsWith se") }
                    ]

                    Input { width: 360 }
                }

                FormItem {
                    field: "shortcut"
                    stopValidateWithError: true
                    rules: [
                        { required: true, message: qsTr("required error") },
                        { type: "string", message: qsTr("type error") },
                        { validator: (rule, value) => value === "semi", message: qsTr("should be semi") },
                        { validator: (rule, value) => Boolean(value && value.startsWith("se")),
                            message: qsTr("should startsWith se") }
                    ]

                    Input { width: 360 }
                }

                Text {
                    topPadding: Theme.current.spacingTight
                    text: qsTr("第一条继续跑完所有规则，第二条 stopValidateWithError 命中即停")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Row {
                    topPadding: Theme.current.spacingBase

                    Button {
                        text: qsTr("提交")
                        onClicked: rulesForm.submitForm()
                    }
                }
            }
        }

        GallerySection {
            title: "自定义校验(Form 级别)"

            // 官方还给了一个返回 Promise 的异步校验示例；QML 侧的校验是同步的，
            // 这里只放同步版本
            Form {
                id: formLevelForm

                width: 560
                validator: (values) => {
                    const errors = {};
                    if (values.name !== "mike")
                        errors.name = qsTr("you must name mike");
                    if (values.sex !== "female")
                        errors.sex = qsTr("must be woman");
                    errors.familyName = [
                        { before: qsTr("before error balabala"), after: qsTr("after error balabala") },
                        qsTr("familyName[1] error balabala")
                    ];
                    return errors;
                }

                FormItem {
                    field: "name"
                    label: "name"
                    trigger: "blur"

                    Input { width: 240 }
                }

                FormItem {
                    field: "familyName[0].before"
                    label: "familyName[0].before"
                    trigger: "blur"

                    Input { width: 240 }
                }

                FormItem {
                    field: "familyName[0].after"
                    label: "familyName[0].after"
                    trigger: "blur"

                    Input { width: 240 }
                }

                FormItem {
                    field: "familyName[1]"
                    label: "familyName[1]"
                    trigger: "blur"

                    Input { width: 240 }
                }

                FormItem {
                    field: "sex"
                    label: "sex"
                    trigger: "blur"

                    Input { width: 240 }
                }

                Item { width: parent.width; height: Theme.current.spacingBase }

                Space {

                    Button {
                        text: "Submit"
                        tone: Enums.Primary
                        onClicked: formLevelForm.submitForm()
                    }

                    Button { text: "reset"; onClicked: formLevelForm.reset() }
                }
            }
        }

        GallerySection {
            title: "自定义校验(Field 级别)"

            Form {
                id: fieldLevelForm

                width: 480

                FormItem {
                    field: "fl_sync"
                    label: qsTr("【familyName】syncValidate")
                    trigger: "blur"
                    validator: (value) => {
                        if (!value)
                            return qsTr("【sync】can't be empty");
                        if (value.length <= 5)
                            return qsTr("【sync】must more than 5");
                        return "";
                    }

                    Input { width: 320 }
                }

                Button {
                    text: "reset"
                    onClicked: fieldLevelForm.reset()
                }
            }
        }

        GallerySection {
            title: "手动触发指定 Field 校验"

            Form {
                id: partialForm

                width: 620

                Column {
                    spacing: 0
                    width: 420

                    FormItem {
                        field: "a[1]"
                        trigger: "blur"
                        validator: (value) => {
                            if (!value)
                                return qsTr("can't be empty");
                            if (value.length <= 5)
                                return qsTr("must more than 5");
                            return "";
                        }

                        Input { width: 200; placeholderText: "a[1]" }
                    }

                    FormItem {
                        field: "a[0]"
                        trigger: "blur"
                        validator: (value) => {
                            if (!value)
                                return qsTr("can't be empty");
                            return "";
                        }

                        Input { width: 200; placeholderText: "a[0]" }
                    }

                    FormItem {
                        field: "b.type"
                        trigger: "blur"
                        validator: (value) => {
                            if (!value)
                                return qsTr("can't be empty");
                            return "";
                        }

                        Input { width: 200; placeholderText: "b.type" }
                    }

                    FormItem {
                        field: "c"
                        trigger: "blur"
                        validator: (value) => {
                            if (!value)
                                return qsTr("can't be empty");
                            return "";
                        }

                        Input { width: 200; placeholderText: "c" }
                    }
                }

                FormItem {
                    field: "validateScope"
                    label: qsTr("当前希望校验的Field")
                    valueKey: "value"
                    initValue: ["a", "c"]

                    CheckboxGroup {
                        direction: Enums.DirectionHorizontal
                        options: [{ label: "a", value: "a" }, { label: "b", value: "b" },
                            { label: "c", value: "c" }]
                    }
                }

                FormItem {
                    field: "resetScope"
                    label: qsTr("当前需要 Reset 的 Field")
                    valueKey: "value"

                    CheckboxGroup {
                        direction: Enums.DirectionHorizontal
                        options: [{ label: "a", value: "a" }, { label: "b", value: "b" },
                            { label: "c", value: "c" }]
                    }
                }

                Item { width: parent.width; height: Theme.current.spacingBase }

                Space {

                    Button {
                        text: qsTr("全量校验")
                        onClicked: partialForm.validate()
                    }

                    Button {
                        text: qsTr("部分校验")
                        onClicked: {
                            const scope = partialForm.getValue("validateScope");
                            partialForm.validate(Array.isArray(scope) ? scope : []);
                        }
                    }

                    Button {
                        text: qsTr("部分重置")
                        onClicked: {
                            const scope = partialForm.getValue("resetScope");
                            partialForm.reset(Array.isArray(scope) ? scope : []);
                        }
                    }

                    Button { text: qsTr("reset"); onClicked: partialForm.reset() }
                }
            }
        }

        GallerySection {
            title: "静默校验"

            Form {
                id: silentForm

                width: 420

                FormItem {
                    field: "su_username"
                    label: qsTr("用户名")
                    rules: [{ required: true, message: qsTr("用户名不能为空") },
                        { min: 3, message: qsTr("用户名至少 3 个字符") }]

                    Input { width: 300 }
                }

                FormItem {
                    field: "su_email"
                    label: qsTr("邮箱")
                    rules: [{ required: true, message: qsTr("邮箱不能为空") },
                        { type: "email", message: qsTr("邮箱格式不正确") }]

                    Input { width: 300 }
                }

                Item { width: parent.width; height: Theme.current.spacingBase }

                Space {

                    Button {
                        text: qsTr("静默校验（不显示错误）")
                        tone: Enums.Primary
                        onClicked: page.silentResult = qsTr("静默校验：")
                            + (silentForm.validate({ silent: true }) ? qsTr("通过") : qsTr("未通过"))
                            + qsTr("，errors 仍为空：%1").arg(
                                Object.keys(silentForm.errors).length === 0)
                    }

                    Button {
                        text: qsTr("普通校验（显示错误）")
                        onClicked: page.silentResult = qsTr("普通校验：")
                            + (silentForm.validate() ? qsTr("通过") : qsTr("未通过"))
                    }
                }

                Text {
                    visible: page.silentResult !== ""
                    topPadding: Theme.current.spacingTight
                    text: page.silentResult
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "表单联动"

            Form {
                id: linkForm

                width: 250

                Text {
                    text: qsTr("Note will change after Sex select")
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                FormItem {
                    field: "Note"

                    Input { width: 250 }
                }

                FormItem {
                    field: "Sex"
                    // 官方在 Select 的 onChange 里调 formApi.setValue('Note', ...)
                    onChange: (value) => {
                        linkForm.setValue("Note", value === "male" ? "Hi male" : "Hi female!");
                    }

                    Select {
                        width: 250
                        options: [{ label: "female", value: "female" }, { label: "male", value: "male" }]
                    }
                }
            }
        }

        GallerySection {
            title: "动态表单"

            Text {
                text: qsTr("动态删减表单项：选择 yes 才出现「直播间名称」")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                id: dynamicForm

                width: 450

                FormItem {
                    field: "dyn_name"
                    label: qsTr("用户名称:")

                    Input { width: 300 }
                }

                FormItem {
                    field: "isAnchor"
                    label: qsTr("是否已注册主播")
                    valueKey: "value"

                    RadioGroup {
                        onChanged: (v) => dynamicForm.setValue("isAnchor", v)

                        Radio { value: "yes"; text: "yes" }
                        Radio { value: "no"; text: "no" }
                    }
                }

                Loader {
                    active: dynamicForm.values.isAnchor === "yes"
                    sourceComponent: liveRoomItem
                }

                Component {
                    id: liveRoomItem

                    FormItem {
                        field: "liveRoom"
                        label: qsTr("直播间名称")

                        Input { width: 300 }
                    }
                }

                Row {
                    topPadding: Theme.current.spacingBase

                    Button {
                        text: qsTr("提交")
                        onClicked: console.log("dynamic:", JSON.stringify(dynamicForm.values))
                    }
                }
            }

            Text {
                topPadding: Theme.current.spacingLoose
                text: qsTr("动态表单保留状态（keepState）：关掉开关再打开，看两个字段的区别")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                id: keepStateForm

                width: 450

                FormItem {
                    field: "always_show"
                    label: qsTr("始终显示的字段")

                    Switch { }
                }

                Row {
                    spacing: Theme.current.spacingExtraTight

                    Checkbox {
                        id: showToggle

                        text: qsTr("显示条件字段")
                        checked: page.showConditional
                        onCheckedChanged: page.showConditional = checked
                    }
                }

                Loader {
                    active: page.showConditional
                    sourceComponent: conditionalKeep
                }

                Loader {
                    active: page.showConditional
                    sourceComponent: conditionalNoKeep
                }

                Component {
                    id: conditionalKeep

                    FormItem {
                        field: "conditionalField"
                        label: qsTr("条件字段（keepState）")
                        keepState: true

                        Input { width: 300 }
                    }
                }

                Component {
                    id: conditionalNoKeep

                    FormItem {
                        field: "noKeepState"
                        label: qsTr("条件字段（无 keepState）")

                        Input { width: 300 }
                    }
                }

                Row {
                    topPadding: Theme.current.spacingBase

                    Button {
                        text: qsTr("提交")
                        onClicked: console.log("keepState:", JSON.stringify(keepStateForm.values))
                    }
                }
            }
        }

        GallerySection {
            title: "使用 ArrayField"

            Form {
                id: arrayForm

                width: 800
                labelPosition: "left"
                labelWidth: 100
                allowEmpty: true

                FormArrayField {
                    id: rulesArray

                    field: "rules"
                    initValue: [{ name: "Semi D2C", role: "Engineer" },
                        { name: "Semi C2D", role: "Designer" }]

                    Column {
                        spacing: Theme.current.spacingTight
                        width: parent ? parent.width : 800

                        Space {
                            Button {
                                text: qsTr("Add new line")
                                variant: Enums.Light
                                icon: "plus_circle"
                                onClicked: rulesArray.add()
                            }

                            Button {
                                text: qsTr("Add new line with init value")
                                icon: "plus_circle"
                                // form/index.md:1793 这支 addWithInitValue 是 theme="solid"
                                variant: Enums.Solid
                                onClicked: rulesArray.addWithInitValue({ name: "Semi DSM", role: "Designer" })
                            }
                        }

                        Repeater {
                            model: rulesArray.arrayFields

                            delegate: Row {
                                id: rowItem

                                required property var modelData

                                spacing: Theme.current.spacingBase

                                FormItem {
                                    field: rowItem.modelData.field + "[name]"
                                    label: rowItem.modelData.field + ".name"
                                    valueKey: "text"

                                    Input { width: 200 }
                                }

                                FormItem {
                                    field: rowItem.modelData.field + "[role]"
                                    label: rowItem.modelData.field + ".role"

                                    Select {
                                        width: 140
                                        options: [{ label: "Engineer", value: "Engineer" },
                                            { label: "Designer", value: "Designer" }]
                                    }
                                }

                                IconButton {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 12
                                    icon: "minus_circle"
                                    tone: Enums.Danger
                                    variant: Enums.Borderless
                                    onClicked: rulesArray.remove(rowItem.modelData.index)
                                }
                            }
                        }
                    }
                }

                Row {
                    topPadding: Theme.current.spacingTight

                    TextArea {
                        width: 600
                        height: 160
                        readOnly: true
                        text: JSON.stringify(arrayForm.getFormState(), null, 2)
                    }
                }
            }
        }

        GallerySection {
            title: "withField 封装自定义表单控件"

            // 官方用 withField(组件, { valueKey, onKeyChangeFnName }) 把任意组件变成表单控件。
            // QML 里等价的就是 FormItem 的 valueKey：声明「哪个属性是值」，
            // 变化信号按 <valueKey>Changed 自动接上。
            Text {
                text: qsTr("下面这个自定义控件只有一个 Text，用 valueKey: 'text' 交给 Form 接管")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                id: customForm

                width: 420

                FormItem {
                    field: "custom_name"
                    label: qsTr("名称")

                    Column {
                        id: customControl

                        // 只要有「值属性」，FormItem 就能接管（属性自带 <name>Changed 通知）
                        property string value: customValue.text

                        spacing: Theme.current.spacingExtraTight

                        Text {
                            id: customValue

                            text: "semi"
                            font.pixelSize: Theme.current.fontSizeHeader5
                            color: Theme.current.colorText0
                        }

                        Row {
                            spacing: Theme.current.spacingExtraTight

                            Button {
                                text: "a"
                                onClicked: {
                                    customValue.text += "a";
                                    customControl.value = customValue.text;
                                }
                            }

                            Button {
                                text: "b"
                                onClicked: {
                                    customValue.text += "b";
                                    customControl.value = customValue.text;
                                }
                            }
                        }
                    }
                }

                Text {
                    topPadding: Theme.current.spacingTight
                    text: qsTr("values：%1").arg(JSON.stringify(customForm.values))
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }

        GallerySection {
            title: "如何访问 formState"

            // 官方这一节的后四条（child render function / render props / useFormState /
            // withFormState）是 React 注入上下文的方式；QML 里 Form 就是可引用的对象，
            // 外部直接 stateForm.getFormState() 即可。
            Text {
                text: qsTr("FormState = values + errors + touched。下面是 Form 外部读取到的实时状态")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                id: stateForm

                width: 520

                FormItem {
                    field: "username"
                    label: qsTr("用户名")
                    rules: [{ required: true, message: qsTr("此项为必填") }]

                    Input { width: 200 }
                }

                FormItem {
                    field: "agree"
                    label: qsTr("同意条款")

                    Switch { }
                }

                Row {
                    topPadding: Theme.current.spacingBaseTight
                    spacing: Theme.current.spacingBaseTight

                    Button {
                        text: qsTr("setValue")
                        onClicked: stateForm.setValue("username", "semi")
                    }

                    Button {
                        text: qsTr("setError")
                        onClicked: stateForm.setError("username", qsTr("外部写入的错误"))
                    }

                    Button {
                        text: qsTr("setTouched")
                        onClicked: stateForm.setTouched("username", true)
                    }

                    Button {
                        text: qsTr("reset")
                        onClicked: stateForm.reset()
                    }
                }
            }

            Column {
                topPadding: Theme.current.spacingBaseTight

                TextArea {
                    width: 520
                    height: 180
                    readOnly: true
                    text: JSON.stringify(stateForm.getFormState(), null, 2)
                }
            }
        }

        GallerySection {
            title: "如何获取 formApi"

            // 官方给了七种拿 formApi 的途径，其中 useForm() + props.form、ref、
            // render props、useFormApi、withFormApi 都依附于 React 的组件实例模型。
            // QML 侧保留并对应得上的是 getFormApi 回调 —— 回调参数就是这张 Form。
            Text {
                text: qsTr("下面这组按钮在 Form 外面，只能通过 getFormApi 回调存下来的引用操作表单")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                bottomPadding: Theme.current.spacingTight
            }

            Form {
                width: 520
                getFormApi: (api) => {
                    page.formApi = api;
                }

                FormItem {
                    field: "email"
                    label: qsTr("邮箱")
                    rules: [{ type: "email", message: qsTr("邮箱格式不正确") }]

                    Input { width: 240 }
                }
            }

            Row {
                topPadding: Theme.current.spacingBaseTight
                spacing: Theme.current.spacingBaseTight

                Button {
                    text: qsTr("外部 setValues")
                    onClicked: page.formApi.setValues({ email: "semi@bytedance.com" })
                }

                Button {
                    text: qsTr("外部 validate")
                    onClicked: page.formApi.validate()
                }

                Button {
                    text: qsTr("外部 getFieldExist")
                    onClicked: page.formApiProbe = String(page.formApi.getFieldExist("email"))
                }
            }

            Text {
                topPadding: Theme.current.spacingTight
                text: qsTr("getValue：%1").arg(page.formApi ? page.apiShown(page.formApi.getValue("email")) : "-")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
            }

            Text {
                topPadding: Theme.current.spacingTight
                text: qsTr("getError：%1").arg(page.formApi ? page.apiShown(page.formApi.getError("email")) : "-")
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
            }

            Text {
                topPadding: Theme.current.spacingTight
                visible: page.formApiProbe !== ""
                text: qsTr("getFieldExist('email')：%1").arg(page.formApiProbe)
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
            }
        }
    }
}
