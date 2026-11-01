import QtQuick
import QtTest
import Semi

// Icons 单例（src/Icons.qml，由 scripts/gen-icons.py 生成）：523 枚 svg 的 qrc URL。
//
// 这里钉四条：
//   ① 每个属性拼出来的 URL 与 `Icon { name: 文件名 }` 完全同值 —— 两边一旦分家，
//      静态引用（Icons.x）与动态引用（name 字符串）会指到不同的地方，而两种写法都不报错；
//   ② 7 枚改名的键（3 个连字符换下划线 + delete/export/import 三枚 ECMAScript 关键字
//      与 print 一枚 V4 全局名，Qt 都不许当标识符用）仍然对得上原文件名；
//   ③ resolve() 文件名与属性名两种拼法同值，认不出的名字回空串；
//   ④ 这些 URL 在 qrc 里真的读得到（Image.status 到 Ready）。
//
// 覆盖的是规则而不是全表：523 条属性由生成器从 src/icons/*.svg 直译，
// 表与目录是否同步由 `python3 scripts/gen-icons.py --check` 钉（QML 侧数不到那张表）。
TestCase {
    id: testCase

    name: "Icons"
    when: windowShown

    // [属性名, svg 文件名（不含 .svg）] —— 每条命名规则都有代表：
    // 单词、多段、数字段、连字符、ECMAScript 关键字、V4 全局名。
    readonly property var pairs: [
        ["plus", "plus"],
        ["absoluteStroked", "absolute_stroked"],
        ["alertTriangle", "alert_triangle"],
        ["chevronUp", "chevron_up"],
        ["aiBellLevel1", "ai_bell_level_1"],
        ["gridView1", "grid_view1"],
        ["wholeWord", "whole_word"],
        ["gridRectangle", "grid-rectangle"],
        ["gridSquare", "grid-square"],
        ["leftCircle", "left-circle"],
        ["deleteIcon", "delete"],
        ["exportIcon", "export"],
        ["importIcon", "import"],
        ["printIcon", "print"]
    ]

    function icon(props) {
        return Qt.createQmlObject(
            "import Semi; Icon { " + props + " }", testCase, "icon")
    }

    function test_keysPointToTheirOwnFiles() {
        for (const p of pairs)
            compare(String(Icons[p[0]]), "qrc:/qt/qml/Semi/icons/" + p[1] + ".svg", p[0])
    }

    // Icons 的属性值必须等于 Icon 按 name 自己拼出来的那个 source。
    // 只比字符串前缀不够：这条同时钉住「改名后的键喂给 Icon 用的还是本名」。
    function test_sameUrlAsIconComponent() {
        for (const p of pairs) {
            const i = icon('name: "' + p[1] + '"')
            compare(i.source.toString(), Icons[p[0]].toString(), p[1])
            i.destroy()
        }
    }

    function test_resolveTakesBothSpellings() {
        for (const p of pairs) {
            compare(Icons.resolve(p[1]).toString(), Icons[p[0]].toString(), "文件名档 " + p[1])
            compare(Icons.resolve(p[0]).toString(), Icons[p[0]].toString(), "属性名档 " + p[0])
        }
    }

    // 认不出来的一律回空串，不能回一个读不到的 URL：
    // 未知名、空串、大小写不对、以及 objectName / resolve 这种撞上单例自带成员的输入。
    function test_resolveRejectsNonIconNames() {
        compare(Icons.resolve("").toString(), "")
        compare(Icons.resolve("no_such_icon").toString(), "")
        compare(Icons.resolve("ChevronUp").toString(), "")
        compare(Icons.resolve("objectName").toString(), "")
        compare(Icons.resolve("resolve").toString(), "")
        compare(Icons.resolve("_key").toString(), "")
    }

    // URL 真的指向 qrc 里的资产：属性名对了但文件没打包（CMake 的 glob 变了、
    // 或 Icons.qml 没跟着 sync-icons.py 重新生成）时，Image 的 status 会是 Error。
    // 这里按样本走，一条规则一枚，七枚改名的全收。
    function test_resourcesAreReachable() {
        for (const p of pairs) {
            const probe = Qt.createQmlObject(
                'import QtQuick; Image { visible: false }', testCase, "probe")
            probe.source = Icons[p[0]]
            tryCompare(probe, "status", Image.Ready, 2000, p[0] + " 读不到")
            probe.destroy()
        }
    }
}
