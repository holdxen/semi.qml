pragma ComponentBehavior: Bound

import QtQuick
import Semi

// 官方示例：content/input/timepicker/index.md（11 个 demo，标题与 docs.json 一致）
Item {
    id: page

    width: parent ? parent.width : 0
    implicitHeight: column.height

    // ---- 各 demo 的受控状态 ----
    property string basicText: ""
    property var controlledTime: null
    property string controlledText: ""
    property bool headerOpen: false
    property var customTime: null
    property string customTimeText: ""

    // 0 .. n-1，disabledTime 那条 demo 要用
    function upto(n) {
        const out = [];
        for (let i = 0; i < n; ++i)
            out.push(i);
        return out;
    }

    Column {
        id: column

        width: parent.width
        spacing: 44

        GallerySection {
            title: "基础使用"

            Column {
                spacing: 12

                TimePicker {
                    width: 200
                    onChanged: (date, dateString) => page.basicText = dateString
                }

                TextLabel {
                    text: page.basicText === "" ? qsTr("还没有选择")
                        : qsTr("onChange 收到：%1").arg(page.basicText)
                }
            }
        }

        GallerySection {
            title: "无限滚动"

            TimePicker {
                width: 200
                scrollItemProps: ({ mode: "wheel", cycled: true })
            }
        }

        GallerySection {
            title: "受控组件"

            Column {
                spacing: 12

                TimePicker {
                    width: 200
                    value: page.controlledTime
                    onChanged: (date, dateString) => {
                        page.controlledTime = date;
                        page.controlledText = dateString;
                    }
                }

                Space {
                    space: 8

                    Button {
                        text: qsTr("设为 09:30:00")
                        variant: Enums.Light
                        onClicked: {
                            page.controlledTime = new Date(1970, 0, 1, 9, 30, 0);
                            page.controlledText = "09:30:00";
                        }
                    }

                    Button {
                        text: qsTr("清空")
                        variant: Enums.Light
                        onClicked: {
                            page.controlledTime = null;
                            page.controlledText = "";
                        }
                    }
                }

                TextLabel {
                    text: qsTr("外部持有的 value：%1").arg(
                        page.controlledText === "" ? qsTr("（空）") : page.controlledText)
                }
            }
        }

        GallerySection {
            title: "不同的 Format 格式"

            TimePicker {
                width: 200
                format: "HH:mm"
                defaultValue: "10:24"
            }
        }

        GallerySection {
            title: "设置面板头部，底部"

            Column {
                spacing: 16

                TimePicker {
                    id: headerPicker

                    width: 200
                    open: page.headerOpen
                    panelHeader: qsTr("Time Select")
                    panelFooter: closeFooter
                    onOpenChange: (isOpen) => page.headerOpen = isOpen
                }

                TimePicker {
                    width: 260
                    type: "timeRange"
                    panelHeader: [qsTr("start header"), qsTr("end header")]
                    panelFooter: [startFooter, endFooter]
                }
            }
        }

        GallerySection {
            title: "禁用时间选择"

            TimePicker {
                width: 200
                defaultValue: "12:08:23"
                disabled: true
            }
        }

        GallerySection {
            title: "设置步长"

            TimePicker {
                width: 200
                minuteStep: 15
                secondStep: 10
            }
        }

        GallerySection {
            title: "12 小时制"

            Column {
                spacing: 16

                TimePicker {
                    width: 200
                    use12Hours: true
                }

                TimePicker {
                    width: 200
                    use12Hours: true
                    format: "a h:mm"
                }
            }
        }

        GallerySection {
            title: "时间范围"

            Column {
                spacing: 16

                TimePicker {
                    width: 260
                    type: "timeRange"
                    defaultValue: ["10:23:15", "12:38:32"]
                }

                TimePicker {
                    width: 260
                    type: "timeRange"
                    use12Hours: true
                    format: "a h:mm"
                    defaultValue: ["上午 08:11", "下午 11:21"]
                }
            }
        }

        GallerySection {
            title: "Range 模式下分别禁用左右面板（disabledTime）"

            TimePicker {
                width: 260
                type: "timeRange"
                // 选了开始时间后，右侧面板里早于它的时分都不可选
                disabledTime: (value, panelType) => {
                    const start = Array.isArray(value) ? value[0] : value;
                    if (panelType === "right" && start instanceof Date
                        && !isNaN(start.getTime())) {
                        const h = start.getHours();
                        const m = start.getMinutes();
                        return ({
                            disabledHours: () => page.upto(h),
                            disabledMinutes: (hour) => hour === h ? page.upto(m) : [],
                        });
                    }
                    return ({});
                }
            }
        }

        GallerySection {
            title: "自定义触发器"

            TimePicker {
                id: customTriggerPicker

                width: 200
                format: "HH:mm:ss"
                value: page.customTime
                triggerRender: Component {
                    Tag {
                        id: triggerTag

                        property var placeholder: ""

                        text: page.customTimeText === ""
                            ? String(triggerTag.placeholder) : page.customTimeText
                        prefixIcon: "clock"
                    }
                }
                onChanged: (date, dateString) => {
                    page.customTime = date;
                    page.customTimeText = dateString;
                }
            }
        }
    }

    Component {
        id: closeFooter

        Button {
            text: qsTr("close")
            variant: Enums.Light
            onClicked: page.headerOpen = false
        }
    }

    Component {
        id: startFooter

        Button {
            text: qsTr("start footer")
            variant: Enums.Light
        }
    }

    Component {
        id: endFooter

        Button {
            text: qsTr("end footer")
            variant: Enums.Light
        }
    }
}
