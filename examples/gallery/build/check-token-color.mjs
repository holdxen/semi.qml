// 端口 TokenColor.js 的数值对账：拿官网真正用的那两个库（chroma-js / wcag-color）
// 出参考值，再跑我们那份 JS 实现比一遍。
//
//   node --experimental-vm-modules examples/gallery/build/check-token-color.mjs
//
// 需要能解析到 chroma-js 与 wcag-color —— 在 semi-design 的 node_modules 里，
// 用 SEMI_ROOT 指过去（默认 ~/Documents/Code/Html/semi-design）。
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';

const semiRoot = process.env.SEMI_ROOT ?? path.join(os.homedir(), 'Documents/Code/Html/semi-design');
const require = createRequire(path.join(semiRoot, 'package.json'));
const chroma = require('chroma-js');
const { scoreFromRatio } = require('wcag-color');

const here = path.dirname(new URL(import.meta.url).pathname);
const src = readFileSync(path.join(here, '..', 'TokenColor.js'), 'utf8').replace(/^\.pragma library/, '')
    + '\nreturn { parseColor, contrast, scoreFromRatio, contrastScore, labOf, labDistance, closestTokens };\n';
const mod = { exports: {} };
// eslint-disable-next-line no-new-func
const tc = new Function('module', 'exports', src)(mod, mod.exports);

const colors = ['#0064FA', '#54A9FF', '#FFFFFF', '#000000', '#F9F9F9', '#1C1F23',
    '#E6160D', '#7E0023', '#007589', '#A744FF', '#25B26B', '#EF8B4C', '#1264A3',
    '#FB80EA', '#ED7D2F', '#FC1E2C', '#9E0909', '#0064FA'];

let bad = 0;
const near = (a, b, eps) => Math.abs(a - b) <= eps;

for (const c of colors) {
    const mine = tc.parseColor(c);
    const cw = Number(chroma.contrast(c, '#ffffff').toFixed(2));
    const cb = Number(chroma.contrast(c, '#000000').toFixed(2));
    const myW = Number(tc.contrast(mine, { r: 255, g: 255, b: 255, a: 1 }).toFixed(2));
    const myB = Number(tc.contrast(mine, { r: 0, g: 0, b: 0, a: 1 }).toFixed(2));
    const okW = near(myW, cw, 0.005);
    const okB = near(myB, cb, 0.005);
    const okSw = tc.scoreFromRatio(myW) === scoreFromRatio(cw);
    const okSb = tc.scoreFromRatio(myB) === scoreFromRatio(cb);
    if (!(okW && okB && okSw && okSb)) {
        bad++;
        console.log(`FAIL ${c} 白 ${myW}/${cw} 黑 ${myB}/${cb} 档 ${tc.contrastScore(mine, {r:255,g:255,b:255,a:1})}/${scoreFromRatio(cw)}`);
    }
}
console.log(`对比度：${colors.length - bad}/${colors.length} 与 chroma + wcag-color 一致`);

// Lab 距离：拿色板里前 40 个两两组合对账
const pairs = [];
for (let i = 0; i < colors.length; ++i) {
    for (let j = i + 1; j < colors.length; ++j) pairs.push([colors[i], colors[j]]);
}
let dbad = 0;
for (const [a, b] of pairs) {
    const want = chroma.distance(a, b);
    const got = tc.labDistance(tc.parseColor(a), tc.parseColor(b));
    if (!near(want, got, 1e-9)) {
        dbad++;
        console.log(`FAIL distance ${a} ${b} ${got} != ${want}`);
    }
}
console.log(`Lab 距离：${pairs.length - dbad}/${pairs.length} 与 chroma.distance 一致`);

// 解析：hex 缩写 / rgb() / 三元组
const parseChecks = [
    ['#abc', { r: 170, g: 187, b: 204 }],
    ['rgb(10, 20, 30)', { r: 10, g: 20, b: 30 }],
    ['rgba(10, 20, 30, 0.5)', { r: 10, g: 20, b: 30 }],
    ['254,251,235', { r: 254, g: 251, b: 235 }],
];
let pbad = 0;
for (const [text, want] of parseChecks) {
    const got = tc.parseColor(text);
    if (!got || got.r !== want.r || got.g !== want.g || got.b !== want.b) {
        pbad++;
        console.log(`FAIL parse ${text} -> ${JSON.stringify(got)}`);
    }
}
console.log(`解析：${parseChecks.length - pbad}/${parseChecks.length} 通过`);

// closestTokens：并列最小距离要一起出来（官网那个 break 只收等于 min 的那些）
const entries = [
    { value: '#0064FA', gradient: false },     // blue-5
    { value: '#0064FA', gradient: false },     // color-primary 与它同值 ⇒ 并列
    { value: '#54A9FF', gradient: false },
    { value: 'linear-gradient(278deg, red)', gradient: true },
];
const hits = tc.closestTokens(tc.parseColor('#0064FA'), entries);
const okTie = hits.length === 2 && hits[0] === 0 && hits[1] === 1;
console.log(`最近色并列：${hits.length} 命中 ${JSON.stringify(hits)} ${okTie ? 'OK' : 'FAIL（官网口径应同时给出 0 与 1）'}`);
const hits2 = tc.closestTokens(tc.parseColor('#54A9FF'), entries);
const okOne = hits2.length === 1 && hits2[0] === 2;
console.log(`唯一最近色：${JSON.stringify(hits2)} ${okOne ? 'OK' : 'FAIL'}`);
// 渐变条目官网是跳过的（getClosestColors 里 continue）
const hits3 = tc.closestTokens(tc.parseColor('#ff0000'), [{ value: 'red', gradient: true }]);
const okSkip = hits3.length === 0;
console.log(`跳过渐变：${okSkip ? 'OK' : 'FAIL'}`);

process.exit(bad + dbad + pbad === 0 && okTie && okOne && okSkip ? 0 : 1);
