pragma ComponentBehavior: Bound

import QtQuick

// 列声明（官方 Table.Column 的 JSX 写法）。挂在 Table 的子项上：
//
//     Table {
//         dataSource: page.rows
//         TableColumn { title: "标题"; dataIndex: "name"; width: 400 }
//         TableColumn { title: "大小"; dataIndex: "size"; sorter: (a, b) => a.size - b.size }
//     }
//
// 合并表头把子列写在自己的子项里（官方是 column.children）：
//
//     TableColumn {
//         title: "基本信息"
//         TableColumn { title: "标题"; dataIndex: "name" }
//     }
//
// 与 columns 配置写法同时给时只认 columns，不做聚合 —— 官方那条注意事项
// （index.md「使用 JSX 写法时，请不要与配置写法同时使用」）照抄。
//
// 属性名与官方 ColumnProps 一致，只有两处不同：key 要写成 columnKey（QtObject 上
// key 与 QML 的键属性语义容易混），子列写成 subColumns（children 在 QML 里是保留的）。
QtObject {
    id: control

    property var title: undefined
    property string dataIndex: ""
    property var columnKey: undefined
    property var width: undefined
    property string align: "left"
    property var fixed: false
    property var ellipsis: false
    property var render: undefined

    property var sorter: undefined
    property var sortOrder: undefined
    property var defaultSortOrder: undefined
    property var sortIcon: undefined
    property bool showSortTip: false
    property bool sortChildrenRecord: false

    property var filters: undefined
    property var onFilter: undefined
    property var filteredValue: undefined
    property var defaultFilteredValue: undefined
    property bool filterMultiple: true
    property string filterConfirmMode: "immediate"
    property var filterIcon: undefined
    property var filterDropdown: undefined
    property var filterDropdownProps: undefined
    property var filterDropdownVisible: undefined
    property var renderFilterDropdown: undefined
    property var renderFilterDropdownItem: undefined
    property bool filterChildrenRecord: false

    property var onCell: undefined
    property var onHeaderCell: undefined
    property var colSpan: undefined
    property var rowSpan: undefined
    property string className: ""
    property bool resize: true
    property bool useFullRender: false

    default property list<TableColumn> subColumns
}
