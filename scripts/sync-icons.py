#!/usr/bin/env python3
"""从 semi-icons 同步 SVG 图标到 src/icons/。

用法:
    python3 scripts/sync-icons.py [--semi-root <path>] [--check]

产物:
    src/icons/*.svg        523 个线性图标（MIT，来自 @douyinfe/semi-icons）
    src/icons/icons.txt    文件名清单，供文档与校验使用

为什么整包同步而不是挑常用的：单个 SVG 只有 1–2KB，全量约 800KB，
放在 qrc 里代价可接受；挑拣反而要长期维护一份清单。
"""
import argparse
import pathlib
import shutil
import sys

DEFAULT_SEMI_ROOT = pathlib.Path.home() / "Documents/Code/Html/semi-design"
# 只有「填充本身是渐变」的图标才不做单色化（ai_*_level_3 那 8 枚）。
# 判据必须是 fill="url( —— 裁剪路径 clip-path="url(#…) 也含 url( 子串，
# 用裸 url( 会把 spin/loading 等 8 枚带 clipPath 的图标误判成保留原色，
# 黑填充原样落盘后被 colorization 染成恒黑（gray×color，灰度 0 乘什么色都是黑）。
SKIP_FILLS = ('fill="url(',)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--semi-root", default=str(DEFAULT_SEMI_ROOT))
    ap.add_argument("--out", default="src/icons")
    ap.add_argument("--check", action="store_true", help="只检查是否同步，不写入")
    args = ap.parse_args()

    src = pathlib.Path(args.semi_root).expanduser() / "packages/semi-icons/src/svgs"
    if not src.is_dir():
        sys.exit(f"找不到 semi-icons: {src}")

    out = pathlib.Path(args.out)
    files = sorted(src.glob("*.svg"))
    if not files:
        sys.exit(f"{src} 下没有 svg")

    names = [f.name for f in files]

    if args.check:
        missing = [n for n in names if not (out / n).exists()]
        extra = sorted(p.name for p in out.glob("*.svg") if p.name not in set(names))
        print(f"源 {len(names)} 个 / 本地 {len(list(out.glob('*.svg')))} 个")
        if missing:
            print(f"  缺失 {len(missing)}: {missing[:5]}")
        if extra:
            print(f"  多余 {len(extra)}: {extra[:5]}")
        return 0 if not missing and not extra else 1

    out.mkdir(parents=True, exist_ok=True)

    # 图标同步时把黑色转成白色：QML 侧用 MultiEffect 的 colorization 上色，
    # 而它是「保留亮度 + 替换色相」—— 黑色（亮度 0）染色后还是黑，必须先转白。
    # 自带品牌色/渐变的图标保持原样，由 Icon 的 tinted 属性决定是否绕过着色。
    plain, colored = 0, []
    for f in files:
        text = f.read_text()
        if any(s in text for s in SKIP_FILLS) or "#A647FF" in text:
            colored.append(f.name)
            target = text
        else:
            plain += 1
            target = text.replace('fill="black"', 'fill="#FFFFFF"') \
                         .replace('fill="#1C1F23"', 'fill="#FFFFFF"') \
                         .replace('fill="white"', 'fill="#FFFFFF"')
        (out / f.name).write_text(target)

    (out / "icons.txt").write_text("\n".join(names) + "\n")

    print(f"已同步 {len(files)} 个图标 -> {out}/")
    print(f"  已转白可着色 {plain} 个")
    print(f"  保留原色 {len(colored)} 个" + (f"（如 {colored[:3]}）" if colored else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
