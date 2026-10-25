pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 对齐 content/feedback/toast/index.md 的 11 个演示小节。
//
// 官方 Toast 是一组静态方法（Toast.info / close / destroyAll / config / useToast /
// ToastFactory.create），QML 的 type 上没有静态方法，所以本页全部走实例方法：
// 一个 Toast {} 就是官方 useToast() 返回的 [toast, contextHolder] 那一对。
//
// 与官方的两处形式差别：
// · 「消费 Context」官方用 React Context 演示；这里对应成「content 传 Component，
//   Loader 按 Component 自己的作用域实例化」，于是页面里的属性能改到已经弹出的卡片上。
// · 「创建不同配置 Toast」官方用 getPopupContainer 把 wrapper 塞进某个 div；
//   这里对应成把 wrapper 塞进下面那个自定义容器 Item。
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    Toast {
        id: toast
    }

    // 「创建不同配置 Toast」：另一份带自己 config 的 Toast（官方 ToastFactory.create）
    Toast {
        id: toastInCustomContainer

        getPopupContainer: function () { return customContainer }
        theme: "light"
        duration: 4
        // top/left/right/bottom 这四个名字被 Item 的 FINAL 锚点线占了，只能走 config()
        // —— 官方也只有 Toast.config({ top }) 这一种写法，没有元素属性形式
        Component.onCompleted: config({ top: 40 })
    }

    // ------------------------------------------------------------ 小节内的状态
    // 官方 throttle(() => Toast.info(opts), 10000, { trailing: false })
    property real throttleAt: -100000
    // 官方「手动关闭」那节的 const [toastId, setToastId] = useState()
    property string manualId: ""
    // 官方「消费 Context」那节的 ReachableContext
    property string reachableName: "Light"

    function throttledInfo() {
        if (Date.now() - page.throttleAt < 10000)
            return;
        page.throttleAt = Date.now();
        toast.info({
            content: "Hi, Bytedance dance dance",
            duration: 10,
            stack: true,
            // 官方 onClose = handleClose → throttled.cancel()
            onClose: function () { page.throttleAt = -100000 }
        });
    }

    function showManual() {
        if (page.manualId !== "")
            return;
        page.manualId = toast.info({
            content: "Not auto close",
            duration: 0,
            onClose: function () { page.manualId = "" }
        });
    }

    function hideManual() {
        toast.close(page.manualId);
        page.manualId = "";
    }

    function updateById() {
        const id = "toastid";
        toast.info({ content: "Update Content By Id", id: id });
        updateAgainTimer.restart();
    }

    // 「链接文本」两段的富文本内容（官方是 ReactNode）
    Component {
        id: linkContent

        Row {
            spacing: Theme.current.spacingBaseTight

            TextLabel {
                strong: true
                text: "Hi, Bytedance dance dance"
            }

            TextLabel {
                link: true
                text: "更多"
            }
        }
    }

    Component {
        id: multiLineContent

        Column {
            spacing: Theme.current.spacingTight

            TextLabel {
                strong: true
                text: "Hi, Bytedance dance dance"
            }

            Row {
                spacing: 20

                TextLabel {
                    link: true
                    text: "查看详情"
                }

                TextLabel {
                    link: true
                    text: "一会再看"
                }
            }
        }
    }

    // 官方 config 里有 title，但 Toast 并没有这个属性，实际只渲染 content
    Component {
        id: contextContent

        Column {
            spacing: Theme.current.spacingExtraTight

            TextLabel {
                strong: true
                text: "This is a success message"
            }

            TextLabel {
                strong: true
                text: "ReachableContext: " + page.reachableName
            }
        }
    }

    Timer {
        id: updateAgainTimer

        interval: 1000
        onTriggered: toast.success({ content: "Id By Content Update", id: "toastid" })
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "如何引入"

            Text {
                width: 460
                text: "import Semi\n\nToast { id: toast }\n\ntoast.info({ content: \"Hi, Bytedance dance dance\", duration: 3, stack: true })"
                color: Theme.current.colorText1
                font.pixelSize: Theme.current.fontSizeSmall
                font.family: "Menlo"
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }

        GallerySection {
            title: "普通提示"

            Row {
                spacing: 12

                Button {
                    text: "Display Toast"
                    onClicked: toast.info({ content: "Hi, Bytedance dance dance", duration: 3, stack: true })
                }

                Button {
                    text: "Throttled Toast"
                    onClicked: page.throttledInfo()
                }
            }

            Text {
                width: 560
                text: "Throttled Toast 十秒内只发一条（官方 throttle(fn, 10000, { trailing: false })）；"
                    + "它那条 toast 关掉时会把节流窗口清掉，于是又能立刻发一条。"
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "其他提示类型"

            Row {
                spacing: 12

                Button {
                    text: "Success"
                    onClicked: toast.success("Hi,Bytedance dance dance")
                }

                Button {
                    text: "Warning"
                    tone: Enums.Warning
                    onClicked: toast.warning({ content: "Hi, Bytedance dance dance", duration: 3 })
                }

                Button {
                    text: "Error"
                    tone: Enums.Danger
                    onClicked: toast.error({ content: "Hi, Bytedance dance dance", duration: 3 })
                }
            }
        }

        GallerySection {
            title: "多色样式"

            Row {
                spacing: 12

                Button {
                    text: "Info"
                    onClicked: toast.info({ content: "Hi, Bytedance dance dance", duration: 3, theme: "light" })
                }

                Button {
                    text: "Success"
                    onClicked: toast.success({ content: "Hi, Bytedance dance dance", duration: 3, theme: "light" })
                }

                Button {
                    text: "Warning"
                    tone: Enums.Warning
                    onClicked: toast.warning({ content: "Hi, Bytedance dance dance", duration: 3, theme: "light" })
                }

                Button {
                    text: "Error"
                    tone: Enums.Danger
                    onClicked: toast.error({ content: "Hi, Bytedance dance dance", duration: 3, theme: "light" })
                }
            }
        }

        GallerySection {
            title: "链接文本"

            Row {
                spacing: 12

                Button {
                    text: "Display Toast"
                    onClicked: toast.info({ content: linkContent, duration: 3 })
                }

                Button {
                    text: "Display Multi-line Toast"
                    onClicked: toast.info({ content: multiLineContent, duration: 3 })
                }
            }
        }

        GallerySection {
            title: "修改延时"

            Row {
                spacing: 12

                Button {
                    text: "Close After 10s"
                    onClicked: toast.info({ content: "Hi, Bytedance dance dance", duration: 10 })
                }
            }
        }

        GallerySection {
            title: "手动关闭"

            Row {
                spacing: 12

                Button {
                    text: "Show Toast"
                    onClicked: page.showManual()
                }

                Button {
                    text: "Hide Toast"
                    onClicked: page.hideManual()
                }
            }
        }

        GallerySection {
            title: "更新消息内容"

            Row {
                spacing: 12

                Button {
                    text: "Update Content By Id"
                    onClicked: page.updateById()
                }
            }
        }

        GallerySection {
            title: "销毁所有"

            Row {
                spacing: 12

                Button {
                    text: "先弹 3 条"
                    onClicked: {
                        toast.info({ content: "Hi, Bytedance dance dance", duration: 0 });
                        toast.success({ content: "Hi, Bytedance dance dance", duration: 0 });
                        toast.warning({ content: "Hi, Bytedance dance dance", duration: 0 });
                    }
                }

                Button {
                    text: "Toast.destroyAll()"
                    variant: Enums.Outline
                    onClicked: toast.destroyAll()
                }
            }
        }

        GallerySection {
            title: "消费 Context"

            Row {
                spacing: 12

                Button {
                    text: "Hook Toast"
                    onClicked: toast.success({ content: contextContent, duration: 0 })
                }

                Button {
                    text: page.reachableName === "Light" ? "换成 Heavy" : "换成 Light"
                    variant: Enums.Light
                    onClicked: page.reachableName = page.reachableName === "Light" ? "Heavy" : "Light"
                }
            }

            Text {
                width: 560
                text: "已经弹出的那条会跟着改：content 传的是页面里定义的 Component，"
                    + "Loader 用它自己那份作用域实例化，读到就是定义处的上下文 —— 对应官方的 contextHolder。"
                color: Theme.current.colorText2
                font.pixelSize: Theme.current.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        GallerySection {
            title: "创建不同配置 Toast"

            Row {
                spacing: 12

                Button {
                    text: "Default Toast"
                    onClicked: toast.info("Toast")
                }

                Button {
                    text: "Toast in custom container"
                    onClicked: toastInCustomContainer.info("Toast in some container")
                }
            }

            // 官方 <div id="custom-toast-container">custom container</div>
            Rectangle {
                id: customContainer

                width: 480
                height: 160
                radius: Theme.current.radiusMedium
                color: Theme.current.colorBg2
                border.width: 1
                border.color: Theme.current.colorBorder

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.current.spacingTight
                    text: "custom container"
                    color: Theme.current.colorText2
                    font.pixelSize: Theme.current.fontSizeSmall
                }
            }
        }
    }
}
