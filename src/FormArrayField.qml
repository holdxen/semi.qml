import QtQuick

// 数组字段。对应官方 ArrayField：动态增删行，行内字段路径为 父字段[行号]。
//
//     FormArrayField {
//         id: rulesField
//         field: "rules"
//         initValue: [{ name: "Semi D2C", role: "Engineer" }]
//
//         Column {
//             Button { text: "Add new line"; onClicked: rulesField.add() }
//             Repeater {
//                 model: rulesField.arrayFields
//                 delegate: Row {
//                     required property var modelData
//
//                     FormItem { field: modelData.field + "[name]"; Input { width: 200 } }
//                     IconButton { icon: "minus_circle"; onClicked: rulesField.remove(modelData.index) }
//                 }
//             }
//         }
//     }
//
// 官方用 children 函数把 add / addWithInitValue / arrayFields 注进 JSX；QML 里这些
// 就是本组件的属性与方法，Repeater 直接用 modelData.field 拼路径。
Item {
    id: control

    objectName: "formArrayField"

    default property alias content: body.data

    property var form: null
    // 必填：本数组在 formState.values 里的路径
    property string field: ""
    // 官方要求必须是数组，且优先级高于 Form 的 initValues
    property var initValue: []

    property var keys: []
    readonly property var arrayFields: control.buildRows()

    readonly property var target: control.form !== null && control.form !== undefined
        ? control.form : control.searchForm()

    Column {
        id: body

        width: parent ? parent.width : control.implicitWidth
        spacing: 0
    }

    implicitWidth: 320
    implicitHeight: body.implicitHeight

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

    function buildRows() {
        const rows = [];
        for (let i = 0; i < control.keys.length; ++i)
            rows.push({ key: control.keys[i], field: control.field + "[" + i + "]", index: i });
        return rows;
    }

    function currentArray() {
        const value = control.target ? control.target.getValue(control.field) : undefined;
        return Array.isArray(value) ? value.slice() : [];
    }

    function writeArray(arr) {
        if (!control.target)
            return;
        // 直接写 values，不走 setValue 的 change 校验（官方这里也是 notNotify）
        control.target.values = control.target.setPath(
            control.target.values, control.target.parsePath(control.field), arr);
        control.target.valueChange(control.target.values, { field: control.field, value: arr });
        control.target.change(control.target.getFormState());
    }

    function add(index) {
        const next = control.keys.slice();
        const newKey = "af-" + Date.now() + "-" + Math.round(Math.random() * 100000);
        if (typeof index === "number") {
            const safe = Math.max(0, Math.min(index, next.length));
            next.splice(safe, 0, newKey);
            const arr = control.currentArray();
            arr.splice(safe, 0, undefined);
            control.writeArray(arr);
        } else {
            next.push(newKey);
        }
        control.keys = next;
        return newKey;
    }

    function addWithInitValue(rowValue, index) {
        const arr = control.currentArray();
        const cloned = JSON.parse(JSON.stringify(rowValue === undefined ? {} : rowValue));
        if (typeof index === "number") {
            const safe = Math.max(0, Math.min(index, arr.length));
            arr.splice(safe, 0, cloned);
        } else {
            arr.push(cloned);
        }
        control.writeArray(arr);
        control.add(typeof index === "number" ? index : arr.length - 1);
    }

    function remove(index) {
        const next = control.keys.slice();
        next.splice(index, 1);
        control.keys = next;

        const arr = control.currentArray();
        if (arr.length > index)
            arr.splice(index, 1);
        control.writeArray(arr);

        // 官方同样把这一行的错误整体移除，否则后一行的错误会顶到前一行上
        if (control.target) {
            const segs = control.target.parsePath(control.field);
            control.target.errors = control.target.deletePath(control.target.errors, segs);
        }
    }

    property bool arrayReady: false

    function initArray() {
        if (control.arrayReady)
            return;
        if (!control.target || control.field === "")
            return;
        control.arrayReady = true;
        // ArrayField 自身在 values 里占一个数组位：initValue 优先于 Form.initValues
        const existing = control.target.getValue(control.field);
        const source = Array.isArray(control.initValue) ? control.initValue
            : (Array.isArray(existing) ? existing : []);
        if (!Array.isArray(existing) || existing.length === 0)
            control.writeArray(source);
        const keys = [];
        for (let i = 0; i < source.length; ++i)
            keys.push("af-" + control.field + "-" + i);
        control.keys = keys;
    }

    Component.onCompleted: control.initArray()
}
