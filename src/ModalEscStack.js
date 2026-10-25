.pragma library

// Modal 的 Esc 监听栈 —— 半移植 semi-foundation/modal/modalContentFoundation.ts:26-34
// 那份模块级 `escListenerStack`。
//
// 官方背景：每个打开的 ModalContent 都往 document 上挂一个 keydown 监听，
// `stopPropagation()` 挡不住挂在同一节点上的兄弟监听，于是一次 Esc 会把所有层一起关掉。
// 修法是只让**最后挂载**那一个响应（`stack[stack.length - 1] !== this.handleKeyDown` 就 return），
// 一次 Esc 关一层。
//
// QML 侧对应的坑是 `Shortcut`：同一 context 里两条 sequence 相同的 Shortcut 同时 enabled
// 会互相判为歧义、两条都不触发。所以这里同样要有一个「谁在最上面」的栈，只 enable 栈顶那条。
//
// 官方压栈的时机是 componentDidMount（挂载即压），弹层靠 Portal 只在 visible 时挂载，
// 所以这里的 push / remove 挂在 Popup 的 onOpened / onClosed 上。keepDOM 那一档官方会让
// 隐藏中的对话框继续占着栈顶、把 Esc 吞掉（上游 bug，只记录不抄），本端口不挂这个账。
//
// 栈里存的是自增整数 id 而不是组件引用：跨 `.pragma library` 边界比较 QObject 包装对象
// 的恒等并不可靠，整数没有这个问题。
//
// 「谁是栈顶」必须回灌成 QML 属性（setTop 回调）：`.js` 里的数组变化不是 notify，
// 写在绑定里的 `isTop(id)` 不会重算，Shortcut 会永远停在第一次求出的 disabled。

var stack = []
var idSeq = 0

function nextId() {
    idSeq += 1
    return idSeq
}

// 官方是 push（重复挂载会再压一层）。这里按「同一个 id 重新打开就挪到栈顶」实现，
// 不会把同一条堆两次。
function push(id, setTop) {
    var i = indexOf(id)
    if (i !== -1)
        stack.splice(i, 1)
    stack.push({ id: id, setTop: setTop })
    refresh()
}

function remove(id) {
    var i = indexOf(id)
    if (i !== -1) {
        stack[i].setTop(false)
        stack.splice(i, 1)
    }
    refresh()
}

function indexOf(id) {
    for (var i = 0; i < stack.length; ++i) {
        if (stack[i].id === id)
            return i
    }
    return -1
}

// 只有最后压进来的那一个听 Esc
function refresh() {
    for (var i = 0; i < stack.length; ++i)
        stack[i].setTop(i === stack.length - 1)
}
