import QtQuick
import QtTest
import Semi

// 这个文件已经空了。
//
// 2026-10-24（Anchor 这一轮）：这里原先剩的是 5 条旧 Anchor 用例（`selectedAnchor` /
// `target` / `anchorId` 那一套自造面），Anchor 按官方 `AnchorProps` / `LinkProps` 整份重写后
// 一条都不成立 ⇒ 整批搬进 `tests/tst_anchor.qml`（36 个用例函数 / 152 处断言）。
// 再往前，2026-10-19 的 UserGuide 那一轮已经把本文件里那 5 条 UserGuide 用例搬进
// `tests/tst_userguide.qml` 并扩写。
//
// 文件按「不删只留说明」的口径留着（同 `tst_p5b.qml`），并已从 `SEMI_TEST_FILES` 取消登记。
TestCase {
    id: testCase

    name: "Guide"
    when: windowShown
    width: 400
    height: 300
}
