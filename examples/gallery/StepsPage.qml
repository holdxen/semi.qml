pragma ComponentBehavior: Bound

import QtQuick
import Semi

// Steps 步骤条。小节顺序与标题逐条对齐 content/navigation/steps/index.md 的那 9 条 demo
// （加「如何引入」共 10 节，页面右侧的页内锚点就是这些标题）。
//
// 端口与官方的口径差（完整清单在 src/Steps.qml 与 src/Step.qml 文件头）：
//   · 官方三档 demo 里 `style={{ width: 300 }}` 那一档宽度，端口写在 Steps 的 width 上；
//     容器**没有 implicitWidth**（官方是块级 div 撑满父节点），所以调用方必须给宽。
//   · `Steps.Step` 的 JSX 写法 = 声明式子项 `Step { }`；官方那一份数组档端口反过来才有
//     （`items`），本页面一律走子项档。
//   · 「处理进度」与「onChange 回调」两节官方都用 useState，端口把状态放在页面根属性上。
//   · 官方 icon 收 ReactNode（IconHome / IconLock），端口收图标名或 Component。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // 「处理进度」/「onChange 回调」两节的状态（官方用 useState，端口放在页面根上）
    property int progressCurrent: 0
    property int callbackCurrent: 1
    readonly property var progressContent: ["第一步的内容", "第二步的内容", "最后一步的内容"]

    component Frame: Rectangle {
        border.width: 1
        border.color: Theme.current.colorBorder

        default property alias content: holder.data

        Item {
            id: holder

            anchors.fill: parent
            anchors.margins: 1
        }
    }

    component Note: Text {
        width: 640
        text: ""
        wrapMode: Text.WordWrap
        color: Theme.current.colorText2
        font.pixelSize: Theme.current.fontSizeSmall
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        // ================================================================ 如何引入
        GallerySection {
            title: "如何引入"

            Column {
                width: 760
                spacing: 10

                Text {
                    text: "import { Steps } from '@douyinfe/semi-ui'"
                    color: Theme.current.colorText1
                    font.family: "Menlo"
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Note {
                    text: qsTr("Steps 官方 9 条 prop（className / current / direction / hasLine / initial /"
                        + " status / size / style / type）+ onChange，Step 8 条（aria-label / className /"
                        + " description / icon / role / status / style / title）+ onClick / onKeyDown。"
                        + "端口撤掉 className / style / prefixCls 三条 DOM 通道，把 onChange 收进信号 change、"
                        + "onClick / onKeyDown 收进 Step 的 clicked / enterPressed，"
                        + "另加两枚端口开关 clickable（容器与格子各一枚，替代「有没有人连回调」这件事）"
                        + "和容器上的 items 数组档（官方只有子元素）。")
                }
            }
        }

        // ================================================================ 官方 demo 顺序
        GallerySection {
            title: "默认步骤条（旧版）"

            Column {
                width: 640
                spacing: 12

                Steps {
                    width: 640
                    current: 1

                    Step { title: "已完成"; description: "这是一段描述" }
                    Step { title: "进行中"; description: "这是一段描述" }
                    Step { title: "等待中"; description: "这是一段描述" }
                }

                Note {
                    text: qsTr("缺省 type 就是 fill（文档表里写的 fill 是真的，`index.tsx:40` 的 "
                        + "defaultProps）。这一档没有连接线：fillSteps.scss:14-30 那条 ::after "
                        + "上游自己注释掉了。卡片是顶对齐（容器没写 align-items），"
                        + "已完成那格的标题是 success 绿 —— 官方 CSS:20508 只有 fill 档这么染。")
                }
            }
        }

        GallerySection {
            title: "简单步骤条（新版）"

            Column {
                width: 640
                spacing: 12

                Steps {
                    width: 640
                    type: "basic"
                    current: 1

                    Step { title: "已完成"; description: "这是一段描述" }
                    Step { title: "进行中"; description: "这是一段描述" }
                    Step { title: "等待中"; description: "这是一段描述" }
                }

                Note {
                    text: qsTr("basic 档的连接线是标题的 ::after，从标题右边界起、被格子的 "
                        + "overflow:hidden 裁到格子边上 ⇒ 两头都不接下一个标记。"
                        + "最后一格 `flex:none` 吃内容宽，其余均分。")
                }
            }
        }

        GallerySection {
            title: "导航步骤条"

            Column {
                width: 640
                spacing: 12

                Steps {
                    width: 640
                    type: "nav"
                    current: 1
                    clickable: false

                    Step { title: "注册账号" }
                    Step { title: "这个项目的文字比较多多多多" }
                    Step { title: "产品用途" }
                    Step { title: "期待尝试功能" }
                }

                Note {
                    text: qsTr("nav 档整条按内容撑开、零背景零悬浮态，唯一的状态视觉是标题的字重与颜色；"
                        + "分隔符是 12px 的 chevron_right 节点（不是 CSS 画的箭头），最后一格不给。"
                        + "官方这一档静默丢掉 status / direction / hasLine（navSteps.tsx 一个都不解构），"
                        + "`clickable: false` 是端口开关 —— 官方「容器有没有 onChange」在 QML 里看不出来。")
                }
            }
        }

        GallerySection {
            title: "迷你尺寸步骤条"

            Column {
                width: 640
                spacing: 24

                Steps {
                    width: 640
                    type: "basic"
                    size: "small"
                    current: 1

                    Step { title: "已完成"; description: "这是一段描述" }
                    Step { title: "进行中"; description: "这是一段描述" }
                    Step { title: "等待中"; description: "这是一段描述" }
                }

                Steps {
                    width: 640
                    type: "nav"
                    size: "small"
                    current: 1
                    clickable: false

                    Step { title: "注册账号" }
                    Step { title: "这个项目的文字比较多多多多" }
                    Step { title: "产品用途" }
                    Step { title: "期待尝试功能" }
                }

                Note {
                    text: qsTr("官方这一节就是两条 demo（basic small + nav small）。"
                        + "`size` 只对 basic/nav 有效：fill 档收得到但从不读，"
                        + "状态 glyph 恒 24px（fillStep.tsx:36,46,49 写死 extra-large）。")
                }
            }
        }

        GallerySection {
            title: "处理进度"

            Column {
                width: 640
                spacing: 12

                Steps {
                    width: 640
                    type: "basic"
                    current: page.progressCurrent
                    clickable: false

                    Step { title: "第一步" }
                    Step { title: "第二步" }
                    Step { title: "最后一步" }
                }

                Text {
                    text: page.progressContent[Math.min(page.progressCurrent,
                        page.progressContent.length - 1)]
                    color: Theme.current.colorText0
                    font.pixelSize: Theme.current.fontSizeRegular
                }

                Row {
                    spacing: 8

                    Button {
                        text: "下一步"
                        visible: page.progressCurrent < 2
                        onClicked: page.progressCurrent = page.progressCurrent + 1
                    }

                    Button {
                        text: "完成"
                        visible: page.progressCurrent === 2
                    }

                    Button {
                        text: "上一步"
                        visible: page.progressCurrent > 0
                        onClicked: page.progressCurrent = page.progressCurrent - 1
                    }
                }

                Note {
                    text: qsTr("官方这节的步骤条自己也可点（onChange 收得到），端口把这一档关成 "
                        + "`clickable: false`，让「按钮推进」与下一节的「点格子推进」分开演示。")
                }
            }
        }

        GallerySection {
            title: "竖直方向的步骤条"

            Column {
                width: 640
                spacing: 24

                Steps {
                    width: 300
                    direction: "vertical"
                    current: 1

                    Step { title: "已完成"; description: "这是一段描述" }
                    Step { title: "进行中"; description: "这是一段描述" }
                    Step { title: "等待中"; description: "这是一段描述" }
                }

                Steps {
                    width: 300
                    type: "basic"
                    direction: "vertical"
                    current: 1

                    Step { title: "已完成"; description: "这是一段描述" }
                    Step { title: "进行中"; description: "这是一段描述" }
                    Step { title: "等待中"; description: "这是一段描述" }
                }

                Note {
                    text: qsTr("官方这一节也是两条 demo：第一条不写 type（缺省 fill，`style={{width:300}}`），"
                        + "第二条 basic。竖排那一档没有左内边距（那 16 写在 &-horizontal 里），"
                        + "每格靠 padding-top:9 让出上一格伸下来的连接线，连接线停在格子底边。")
                }
            }
        }

        GallerySection {
            title: "指定步骤状态"

            Column {
                width: 640
                spacing: 12

                Steps {
                    width: 640
                    type: "basic"
                    current: 1
                    status: "error"

                    Step { title: "已完成"; description: "这是一段描述" }
                    Step { title: "进行中"; description: "这是一段描述" }
                    Step { title: "等待中"; description: "这是一段描述" }
                }

                Note {
                    text: qsTr("容器的 `status` 只染当前那一格（basicSteps.tsx:57-65），"
                        + "前面已完成那格照旧是 finish。端口不复现上游的 semi-steps-next-error "
                        + "类名：semi.css 里 0 条规则，而且它是赋值不是追加，会把用户自己的类名丢掉。")
                }
            }
        }

        GallerySection {
            title: "自定义图标/状态"

            Column {
                width: 640
                spacing: 12

                Steps {
                    width: 640
                    type: "basic"
                    clickable: false

                    Step { status: "finish"; title: "已完成" }
                    Step { status: "error"; title: "错误" }
                    Step { status: "warning"; title: "警告" }
                    Step { status: "process"; title: "正在进行"; icon: "home" }
                    Step { status: "wait"; title: "等待"; icon: "lock" }
                }

                Note {
                    text: qsTr("格子自己写了 `status` 就不受容器 current 推（`if (!child.props.status)` 判的是真值，"
                        + "写空串等于没写）。官方 icon 收 ReactNode（IconHome / IconLock 24px），"
                        + "端口这一档收图标名；显式给 `icon: null`（等价于官方 `icon={null}`）会把整个标记位抹掉 —— "
                        + "上游判据是 `'icon' in props` 而不是真值，端口照抄：空串算没给，null 算给了。")
                }
            }
        }

        GallerySection {
            title: "onChange 回调"

            Column {
                width: 640
                spacing: 12

                Steps {
                    id: callbackSteps

                    width: 640
                    type: "basic"
                    current: page.callbackCurrent
                    clickable: true
                    // 信号入参在 handler 里是隐式注入的，qmllint 认不出来源 ⇒ 只圈这一行
                    // qmllint disable unqualified
                    onChange: page.callbackCurrent = index
                    // qmllint enable unqualified

                    Step { title: "第一步" }
                    Step { title: "第二步" }
                    Step { title: "最后一步" }
                }

                Text {
                    text: "当前 current = " + page.callbackCurrent
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }

                Steps {
                    width: 640
                    type: "basic"
                    initial: 1
                    current: 1
                    clickable: true
                    // 信号入参在 handler 里是隐式注入的，qmllint 认不出来源 ⇒ 只圈这一行
                    // qmllint disable unqualified
                    onChange: page.callbackCurrent = index
                    // qmllint enable unqualified

                    Step { title: "第一步" }
                    Step { title: "第二步" }
                    Step { title: "最后一步" }
                }

                Note {
                    text: qsTr("上面那条是普通档；下面那条 `initial: 1` 用来钉上游那条门禁：onChange 的"
                        + "门禁比的是裸 index 而不是 stepNumber（basicSteps.tsx:69），"
                        + "所以 initial=1 current=1 时点中间那格（index 1）不发信号、"
                        + "点第一格（index 0）反而发 `change(0 + 1)`。上游自己的测试 "
                        + "steps.test.js:240-256 把这个行为钉死了，端口照抄。")
                }
            }
        }
    }
}
