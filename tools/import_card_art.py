# -*- coding: utf-8 -*-
"""
修行纪念卡美术导入脚本

用法：
  1. 把生成的卡面图放进  tools/card_art_src/  目录，按章号命名：
       1.jpg / 1.png,  2.jpg ... 81.jpg
     （jpg/png 均可；建议竖版 3:4，如 900x1200 以上）
  2. 在仓库根目录运行：
       python tools/import_card_art.py
  3. 脚本会把每张图生成 Resources/Assets.xcassets/CardArt-N.imageset/，
     App 端 CardFaceView 检测到图后自动替换程序化 fallback。
  4. 提交并推送，让 GitHub Actions 构建出新版本。

重复运行安全：同名 imageset 会被覆盖更新（先删后建）。
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = Path(__file__).resolve().parent / "card_art_src"
ASSETS = ROOT / "Resources" / "Assets.xcassets"

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}

CONTENTS_JSON = """{
  "images" : [
    {
      "filename" : "%(filename)s",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""


def main() -> int:
    if not SRC_DIR.is_dir():
        print(f"[!] 源目录不存在：{SRC_DIR}")
        print("    请先创建它并把卡面图按 1.jpg ... 81.jpg 命名放入。")
        return 1

    # 收集 源文件 → 章号
    found: dict[int, Path] = {}
    for f in sorted(SRC_DIR.iterdir()):
        if not f.is_file() or f.suffix.lower() not in IMAGE_EXT:
            continue
        m = re.fullmatch(r"(\d{1,3})", f.stem)
        if not m:
            print(f"[跳过] 文件名不是纯章号：{f.name}")
            continue
        n = int(m.group(1))
        if not (1 <= n <= 81):
            print(f"[跳过] 章号超出 1-81：{f.name}")
            continue
        found[n] = f

    if not found:
        print("[!] card_art_src/ 里没有找到 1.jpg ... 81.jpg 命名的图。")
        return 1

    ASSETS.mkdir(parents=True, exist_ok=True)
    ok = []
    for n, src in sorted(found.items()):
        name = f"CardArt-{n}"
        imageset = ASSETS / f"{name}.imageset"
        if imageset.exists():
            shutil.rmtree(imageset)  # 覆盖更新
        imageset.mkdir(parents=True)
        target_name = f"{name}{src.suffix.lower()}"
        shutil.copy2(src, imageset / target_name)
        (imageset / "Contents.json").write_text(
            CONTENTS_JSON % {"filename": target_name}, encoding="utf-8"
        )
        ok.append(n)
        print(f"[✓] 第 {n:>2} 章 → {name}.imageset")

    done = len(ok)
    missing = sorted(set(range(1, 82)) - set(ok))
    print(f"\n完成：导入 {done} 张，还差 {len(missing)} 张。")
    if missing:
        preview = ", ".join(str(m) for m in missing[:20])
        print(f"    缺章号：{preview}{' ...' if len(missing) > 20 else ''}")
    print("下一步：git 提交推送，GitHub Actions 构建验证。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
