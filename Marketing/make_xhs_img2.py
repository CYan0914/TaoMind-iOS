# -*- coding: utf-8 -*-
# 图 2 中英对照 —— 用用户的真机截图拼小红书 3:4 图
#
# 2026-10-01：改用 layout_check.Layout —— 跑完直接打印每行真实 y 区间并报重叠。
# 截图按整块登记（L.block），保证上方标题和下方标签不会压到图上。
import os, sys
from PIL import Image, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from layout_check import Layout

OUT = r"C:\Users\Cyan\Desktop\TaoMind-iOS\Marketing\xhs"
os.makedirs(OUT, exist_ok=True)

CN = r"C:\Users\Cyan\Desktop\1.png"   # 中文：求取智慧
EN = r"C:\Users\Cyan\Desktop\2.png"   # 英文：Seek Wisdom

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
canvas, d = L.canvas, L.draw

# ---- 顶部标题
y = 90
y = L.text(y, "同一个 App", f(66), INK) + 18
y = L.text(y, "中国人看到的 / 老外看到的", f(48), ACCENT) + 40

# ---- 两张手机截图并排
SHOT_W = 430                        # 单张宽
SHOT_H = int(SHOT_W * 2868 / 1320)  # 保持原比例 ≈ 934
GAP = 56

cn = Image.open(CN).convert("RGB").resize((SHOT_W, SHOT_H), Image.LANCZOS)
en = Image.open(EN).convert("RGB").resize((SHOT_W, SHOT_H), Image.LANCZOS)

total_w = SHOT_W * 2 + GAP
x0 = (W - total_w) // 2
shot_y = y + 20

for shot, x in ((cn, x0), (en, x0 + SHOT_W + GAP)):
    bd = Image.new("RGB", (SHOT_W + 8, SHOT_H + 8), (212, 204, 190))
    bd.paste(shot, (4, 4))
    canvas.paste(bd, (x - 4, shot_y - 4))

# 两张截图整体登记成一个占位块（含边框 4px 外扩）
L.block(x0 - 4, shot_y - 4, total_w + 8, SHOT_H + 8,
        f"真机截图并排 y{shot_y}..{shot_y + SHOT_H}")

# ---- 图下标签
label_y = shot_y + SHOT_H + 34
for label, x in (("中文", x0), ("English", x0 + SHOT_W + GAP)):
    box = d.textbbox((0, 0), label, font=f(40))
    lw = box[2] - box[0]
    d.text((x + (SHOT_W - lw) / 2 - box[0], label_y - box[1]),
           label, font=f(40), fill=INK_SOFT)
    L.block(x, label_y - box[1], SHOT_W, box[3] - box[1], f"标签 {label}")

# ---- 底部说明（贴底部安全区，小红书底部约留 100px）
foot = [
    ("同一份经文，同一段建议", f(38, False), INK_SOFT),
    ("对两拨人，是两种完全不同的东西", f(38, False), INK),
]
heights = [sum(font.getmetrics()) for _, font, _ in foot]
fy = H - 110 - (sum(heights) + 16 * (len(foot) - 1))
for (text, font, fill) in foot:
    L.text(fy, text, font, fill)
    fy += sum(font.getmetrics()) + 16

print("--- 02 中英对照 geometry ---")
for label, x, yy, w, h, kind in L.items:
    print(f"  {label:<30} y {yy:7.1f} .. {yy + h:7.1f}   h={h:5.1f}  [{kind}]")
print()

L.report(out_path=os.path.join(OUT, "02_中英对照.png"))
print("02 ok ->", os.path.join(OUT, "02_中英对照.png"))
