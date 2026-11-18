# -*- coding: utf-8 -*-
# 图 1 首图 —— 与 02-05 同一套视觉（宣纸米色底 + 墨色 + 朱砂）
#
# 2026-10-01：加装 layout_check —— 跑完直接打印每行真实 y 区间并报重叠。
# 不要再靠 Read 看 PNG 判断"挤不挤"：图里没有几何信息，那样判永远收敛不了
# （2026-09-30 死循环 20+ 轮就是这么来的）。改完 y 直接看这里的数字输出。
from PIL import ImageFont
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from layout_check import Layout

OUT = r"C:\Users\Cyan\Desktop\TaoMind-iOS\Marketing\xhs"
os.makedirs(OUT, exist_ok=True)

W, H = 1242, 1656
PAPER    = (250, 246, 238)
INK      = (44, 44, 46)
INK_SOFT = (120, 116, 108)
ACCENT   = (176, 96, 72)

FONT_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"
FONT_REG  = r"C:\Windows\Fonts\msyh.ttc"


def f(size, bold=True):
    try:
        return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)
    except Exception:
        return ImageFont.truetype(r"C:\Windows\Fonts\simhei.ttf", size)


L = Layout(W, H, PAPER)

# ---------- 顶部：极小的引子 ----------
L.text(210, "一个独立开发者", f(46, False), INK_SOFT)

# ---------- 主句（三行，字要大） ----------
y = 400
y = L.text(y, "我做了一个 App", f(112), INK) + 26
y = L.text(y, "把《道德经》", f(112), INK) + 4
y = L.text(y, "卖给了老外", f(112), INK) + 80

# ---------- 分隔线 ----------
L.rule(y)
y += 110

# ---------- 最强的一句（朱砂，最大，行距拉开） ----------
y = L.text(y, "60 个用户", f(126), ACCENT) + 34
y = L.text(y, "0 个人付费", f(126), ACCENT) + 34

# ---------- 底部：与内容留出呼吸，贴安全区 ----------
L.text(H - 200, "不是卖惨，往下看", f(46, False), INK_SOFT)

print("--- layout geometry ---")
for label, x, yy, w, h, kind in L.items:
    print(f"  {label:<20} y {yy:7.1f} .. {yy + h:7.1f}   h={h:5.1f}  [{kind}]")
print()

L.report(out_path=os.path.join(OUT, "01_首图.png"))
print("01 ok ->", os.path.join(OUT, "01_首图.png"))
