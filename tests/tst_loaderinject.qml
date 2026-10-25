pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Semi

// renderOption 注入机制的最小验证（Select.qml 的 Loader 就是这么做的）：
//
// 1. Loader **不会**初始化 required properties —— 组件根写 required 直接
//    创建失败（"Required property ... was not initialized"，status = Error）。
// 2. context object 自由变量解析在 `pragma ComponentBehavior: Bound` 下失效
//    —— 去掉 pragma 能过、加上就 ReferenceError。gallery 页面必须带 Bound，
//    所以这条路不可用。
// 3. 可行解：组件根声明**普通**属性，用 Binding 显式写入。
TestCase {
    id: testCase

    name: "LoaderInject"
    when: windowShown
    width: 300
    height: 300

    Component {
        id: tpl

        Row {
            id: root

            // 普通属性，由外部 Binding 注入
            property var modelData
            property bool chosen

            Text {
                id: t
                text: root.chosen ? "yes:" + String(root.modelData) : "no:" + String(root.modelData)
            }
        }
    }

    Item {
        id: holder

        property var src: "abc"
        property bool isChosen: true

        Loader {
            id: ld
            width: 80
            height: 20
            sourceComponent: tpl

            Binding {
                target: ld.item
                when: ld.item !== null
                property: "modelData"
                value: holder.src
            }
            Binding {
                target: ld.item
                when: ld.item !== null
                property: "chosen"
                value: holder.isChosen
            }
        }
    }

    function test_inject() {
        testCase.visible = true
        wait(50)
        verify(ld.item !== null)
        verify(ld.status === Loader.Ready)
        compare(ld.item.children[0].text, "yes:abc")

        // 外层值变化，Binding 跟着重算
        holder.src = "xyz"
        wait(10)
        compare(ld.item.children[0].text, "yes:xyz")

        holder.isChosen = false
        wait(10)
        compare(ld.item.children[0].text, "no:xyz")
    }
}
