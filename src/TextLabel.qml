import QtQuick

// 行内文本。对应 Semi 的 Text —— 这里叫 TextLabel 是因为
// 本模块若导出名为 Text 的类型，会把同模块所有组件里的 Text { } 都遮蔽掉。
//
//     TextLabel { text: "普通文字" }
//     TextLabel { text: "强调"; strong: true }
//     TextLabel { text: "代码"; code: true }
//     TextLabel { text: "链接"; link: true; underline: true }
//     TextLabel { text: "可复制"; copyable: true }
//
// 色调、mark / code / delete、尺寸继承、copyable、ellipsis 全在 TypographyBase 里，
// 与官方 base.tsx 的分层一致；本类型只是换个名字的 Text。
TypographyBase {
}
