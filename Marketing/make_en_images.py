# -*- coding: utf-8 -*-
# TaoMind 英文版图文（X / Reddit 用）—— 与中文版同一套视觉（宣纸米色底 + 墨色 + 朱砂）
# 输出目录见下方 OUT 常量
import os
from PIL import Image, ImageDraw, ImageFont

CARD = r"C:\Users\Cyan\Desktop\TaoMind-iOS\Card"
OUT  = r"C:\Users\Cyan\Desktop\TaoMind-iOS\Marketing\xhs_en"
os.makedirs(OUT, exist_ok=True)

# X 的图片会自动裁成 16:9 预览，但 3:4 全图点开仍在；Reddit 也吃 3:4。
# ⚠️ X / Reddit 的时间线预览会裁掉底部约 10%，安全区必须留 ≥150px。
# 1600 高时留不出——改 1760 高（仍是 3:4：1320x1760，非整数比但平台不校验）。
W, H = 1320, 1760
SAFE = 190          # 底部安全区（平台裁切 + 视觉呼吸）

PAPER    = (250, 246, 238)
INK      = (44, 44, 46)
INK_SOFT = (120, 116, 108)
ACCENT   = (176, 96, 72)   # 朱砂

FONT_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"      # 中文用（英文版基本不用）
FONT_REG  = r"C:\Windows\Fonts\msyh.ttc"

# 英文必须用西文字体，否则字距/基线很丑
EN_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
EN_REG  = r"C:\Windows\Fonts\segoeui.ttf"


def f(size, bold=True):
    path = EN_BOLD if bold else EN_REG
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf" if bold
                                  else r"C:\Windows\Fonts\arial.ttf", size)


def center(draw, y, text, font, fill, W=W):
    """⚠️ 步进必须用 font.getmetrics() 的行高，不能用 textbbox 的墨迹高度——
    textbbox 只量字形实际占的像素，用墨迹高度步进会让上下两行重叠。"""
    box = draw.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    draw.text(((W - w) / 2 - box[0], y - box[1]), text, font=font, fill=fill)
    return y + sum(font.getmetrics())


def text_block(draw, y, lines, font, fill, gap=24, W=W):
    for ln in lines:
        y = center(draw, y, ln, font, fill, W) + gap
    return y


def footer(draw, lines, min_top=None, bottom_pad=None):
    """脚注贴底部安全区。min_top=内容结束的 y，空间不够就下移，绝不允许重叠。"""
    if bottom_pad is None:
        bottom_pad = SAFE
    heights = [sum(font.getmetrics()) for _, font, _ in lines]
    total = sum(heights) + 22 * (len(lines) - 1)
    y = H - bottom_pad - total
    if min_top is not None and y < min_top + 34:
        y = min_top + 34
    for (text, font, fill), h in zip(lines, heights):
        center(draw, y, text, font, fill)
        y += h + 22


# ---------------------------------------------------------------- 图 1 首图
def img1():
    c = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(c)

    center(d, 210, "An indie developer", f(44, False), INK_SOFT)

    y = 420
    y = center(d, y, "I turned the Tao Te Ching", f(80), INK) + 18
    y = center(d, y, "into an app", f(80), INK) + 18
    y = center(d, y, "and sold it to the West", f(80), INK) + 80

    d.line([(300, y), (W - 300, y)], fill=(206, 198, 184), width=3)
    y += 120

    y = center(d, y, "1,400 users", f(104), ACCENT) + 32
    y = center(d, y, "0 paying", f(104), ACCENT) + 32

    footer(d, [("Not a sob story.", f(44, False), INK_SOFT),
               ("Here's what I found.", f(44, False), INK_SOFT)], min_top=y)
    c.save(os.path.join(OUT, "01_cover.png"))
    print("01 ok")


# ---------------------------------------------------------------- 图 2 中英对照
def img2():
    c = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(c)

    y = 120
    y = center(d, y, "Same app.", f(72), INK) + 20
    y = center(d, y, "Two completely different products.", f(46), ACCENT) + 70

    SHOT_W = 440
    SHOT_H = int(SHOT_W * 2868 / 1320)
    GAP = 56
    cn = Image.open(r"C:\Users\Cyan\Desktop\1.png").convert("RGB").resize((SHOT_W, SHOT_H), Image.LANCZOS)
    en = Image.open(r"C:\Users\Cyan\Desktop\2.png").convert("RGB").resize((SHOT_W, SHOT_H), Image.LANCZOS)

    total_w = SHOT_W * 2 + GAP
    x0 = (W - total_w) // 2
    shot_y = y

    for shot, x in ((cn, x0), (en, x0 + SHOT_W + GAP)):
        bd = Image.new("RGB", (SHOT_W + 8, SHOT_H + 8), (212, 204, 190))
        bd.paste(shot, (4, 4))
        c.paste(bd, (x - 4, shot_y - 4))

    label_y = shot_y + SHOT_H + 40
    for label, x in (("Chinese", x0), ("English", x0 + SHOT_W + GAP)):
        box = d.textbbox((0, 0), label, font=f(40))
        lw = box[2] - box[0]
        d.text((x + (SHOT_W - lw) / 2 - box[0], label_y - box[1]),
               label, font=f(40), fill=INK_SOFT)

    footer(d, [("Same verses. Same advice.", f(38, False), INK_SOFT),
               ("Read completely differently by each audience.", f(38, False), INK)],
           min_top=label_y + 70)
    c.save(os.path.join(OUT, "02_side_by_side.png"))
    print("02 ok")


# ---------------------------------------------------------------- 图 3 产品内核
def img3():
    c = Image.new("RGB", (W, H), PAPER)
    cards = [Image.open(os.path.join(CARD, f"{n}_final.jpg")).convert("RGB") for n in (7, 20, 46)]
    cw, ch = 350, 622
    gap_x = 45
    total_w = cw * 3 + gap_x * 2
    xs = [(W - total_w) // 2 + i * (cw + gap_x) for i in range(3)]
    for im, x in zip(cards, xs):
        im2 = im.copy()
        tw, th = im2.width, int(im2.width * ch / cw)
        top = (im2.height - th) // 2
        im2 = im2.crop((0, top, tw, top + th)).resize((cw, ch), Image.LANCZOS)
        bd = Image.new("RGB", (cw + 6, ch + 6), (214, 206, 192))
        bd.paste(im2, (3, 3))
        c.paste(bd, (x, 180))

    d = ImageDraw.Draw(c)
    y = 880
    y = text_block(d, y, ["Describe your problem."], f(70), INK, gap=20)
    y = text_block(d, y, ["It answers with 2,500-year-old texts."], f(52), ACCENT, gap=20)

    footer(d, [("Tao Te Ching 81 chapters  ·  Diamond Sutra 32  ·  Zhuangzi", f(32, False), INK_SOFT)],
           min_top=y + 60)
    c.save(os.path.join(OUT, "03_what_it_does.png"))
    print("03 ok")


# ---------------------------------------------------------------- 图 4 数据
def img4():
    c = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(c)

    center(d, 190, "TaoMind so far", f(50, False), INK_SOFT)
    d.line([(W / 2 - 60, 275), (W / 2 + 60, 275)], fill=(206, 198, 184), width=3)

    rows = [
        ("1,400", "users",              INK),
        ("0",     "paying",             ACCENT),
        ("166",   "passages",           INK),
        ("60",    "illustrated cards",  INK),
        ("5.0",   "App Store rating",   INK),
    ]
    y = 420
    step = 215
    for i, (num, label, col) in enumerate(rows):
        nb = d.textbbox((0, 0), num, font=f(116))
        nw = nb[2] - nb[0]
        lb = d.textbbox((0, 0), label, font=f(40, False))
        lw = lb[2] - lb[0]
        total = nw + 28 + lw
        x = (W - total) / 2
        d.text((x - nb[0], y - nb[1]), num, font=f(116), fill=col)
        d.text((x + nw + 28 - lb[0], y + 62 - lb[1]), label, font=f(40, False), fill=INK_SOFT)
        # 分隔细线画在「两行之间」——即 y+step 的一半，不能落在下一个数字上
        if i < len(rows) - 1:
            d.line([(240, y + step - 46), (W - 240, y + step - 46)], fill=(228, 220, 206), width=2)
        y += step

    footer(d, [("Every number is real. Including the zero.", f(38, False), ACCENT)],
           min_top=y - step + 150)
    c.save(os.path.join(OUT, "04_numbers.png"))
    print("04 ok")


# ---------------------------------------------------------------- 图 5 失败
def img5():
    c = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(c)

    center(d, 120, "\u201c", f(190), (214, 205, 190))

    y = 300
    y = text_block(d, y, ["Apple rejected my app once."], f(58), INK, gap=28)
    y = text_block(d, y, ["The reason:"], f(58), INK, gap=48)

    box_t, box_b = 530, 720
    d.rectangle([110, box_t, W - 110, box_b], fill=(240, 234, 222))
    d.text((165, box_t + 46), "\u201cIn-app purchases are not", font=f(42), fill=INK)
    d.text((165, box_t + 110), "easily discoverable.\u201d", font=f(42), fill=INK)

    y = 800
    y = text_block(d, y, ["I thought that was unfair."], f(44), INK, gap=4)
    y = text_block(d, y, ["I built a paywall."], f(44), INK, gap=30)

    y = text_block(d, y, ["Two days of digging later:"], f(40), INK_SOFT, gap=10)
    y = text_block(d, y, ["the lifetime purchase was"], f(46), INK, gap=4)
    y = text_block(d, y, ["wired to a place the app never read."], f(46), ACCENT, gap=16)

    y = text_block(d, y, ["No user could ever see it."], f(44), INK, gap=4)
    y = text_block(d, y, ["Let alone buy it."], f(44), INK, gap=4)

    footer(d, [("So my \u201c0 paying users\u201d", f(38, False), INK_SOFT),
               ("partly means: one thing was unbuyable.", f(38, False), ACCENT)],
           min_top=y)
    c.save(os.path.join(OUT, "05_the_bug.png"))
    print("05 ok")


# ---------------------------------------------------------------- 图 6 结尾
def img6():
    base = Image.open(os.path.join(CARD, "46_final.jpg")).convert("RGB")
    th = int(base.width * H / W)
    top = max(0, (base.height - th) // 2)
    base = base.crop((0, top, base.width, top + th)).resize((W, H), Image.LANCZOS)
    veil = Image.new("RGB", (W, H), (250, 246, 238))
    base = Image.blend(base, veil, 0.62)

    d = ImageDraw.Draw(base)

    y = 400
    y = text_block(d, y, ["It's free on the App Store now."], f(58), INK, gap=30)
    y = text_block(d, y, ["Search TaoMind."], f(58), ACCENT, gap=30)

    d.line([(340, y + 80), (W - 340, y + 80)], fill=(198, 190, 176), width=3)

    y = y + 190
    y = text_block(d, y, ["NEXT"], f(42, False), INK_SOFT, gap=30)
    y = text_block(d, y, ["The paywall bug"], f(52), INK, gap=18)
    y = text_block(d, y, ["nobody could pay through"], f(52), INK, gap=18)

    footer(d, [("TaoMind", f(40, False), INK_SOFT)], min_top=y + 40)
    base.save(os.path.join(OUT, "06_outro.png"))
    print("06 ok")


if __name__ == "__main__":
    img1(); img2(); img3(); img4(); img5(); img6()
    print("\nOut:", OUT)
