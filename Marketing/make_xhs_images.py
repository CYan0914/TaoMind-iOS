# -*- coding: utf-8 -*-
# 生成 TaoMind 小红书首篇的 4 张图（不依赖真机截图的那些）
# 输出目录见下方 OUT 常量
import os
from PIL import Image, ImageDraw, ImageFont

CARD = r"C:\Users\Cyan\Desktop\TaoMind-iOS\Card"
OUT  = r"C:\Users\Cyan\Desktop\TaoMind-iOS\Marketing\xhs"
os.makedirs(OUT, exist_ok=True)

W, H = 1242, 1656          # 小红书 3:4
PAPER    = (250, 246, 238)
INK      = (44, 44, 46)
INK_SOFT = (120, 116, 108)
ACCENT   = (176, 96, 72)   # 朱砂

FONT_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"
FONT_REG  = r"C:\Windows\Fonts\msyh.ttc"


def f(size, bold=True):
    path = FONT_BOLD if bold else FONT_REG
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.truetype(r"C:\Windows\Fonts\simhei.ttf", size)


def center(draw, y, text, font, fill, W=W):
    """按文字实际宽度居中绘制，返回下一行顶部 y。

    ⚠️ 必须用 font.getmetrics() 的行高做步进，不能用 textbbox 的墨迹高度——
    textbbox 只量字形实际占的像素（size 58 只有 58px），而字体行盒是 78px，
    用墨迹高度步进会让上下两行字形重叠。
    """
    box = draw.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    draw.text(((W - w) / 2 - box[0], y - box[1]), text, font=font, fill=fill)
    return y + sum(font.getmetrics())


def text_block(draw, y, lines, font, fill, gap=24, W=W):
    for ln in lines:
        y = center(draw, y, ln, font, fill, W) + gap
    return y


def footer(draw, lines):
    """把脚注贴到底部安全区（小红书底部约留 90px），倒推算起点，避免重叠"""
    y = H - 90
    heights = []
    for text, font, fill in lines:
        heights.append(sum(font.getmetrics()))
    total = sum(heights) + 22 * (len(lines) - 1)
    y -= total
    for (text, font, fill), h in zip(lines, heights):
        center(draw, y, text, font, fill)
        y += h + 22


# ---------------------------------------------------------------- 图 3 产品内核
def img3():
    canvas = Image.new("RGB", (W, H), PAPER)
    # 三张珍藏卡横排
    cards = [Image.open(os.path.join(CARD, f"{n}_final.jpg")).convert("RGB")
             for n in (7, 20, 46)]
    cw, ch = 340, 604                     # 3:4 裁切后的卡片尺寸
    xs = [58, 451, 844]
    for im, x in zip(cards, xs):
        # 居中裁成 3:4
        im2 = im.copy()
        tw, th = im2.width, int(im2.width * ch / cw)
        top = (im2.height - th) // 2
        im2 = im2.crop((0, top, tw, top + th)).resize((cw, ch), Image.LANCZOS)
        # 细边框
        bd = Image.new("RGB", (cw + 6, ch + 6), (214, 206, 192))
        bd.paste(im2, (3, 3))
        canvas.paste(bd, (x, 150))

    d = ImageDraw.Draw(canvas)
    y = 830
    y = text_block(d, y, ["你输入今天的困境"], f(78), INK, gap=18)
    y = text_block(d, y, ["它用 2500 年前的智慧回答你"], f(58), ACCENT, gap=18)

    # 底部小字
    center(d, 1500, "TaoMind · 道德经 81 章 + 金刚经 32 品 + 庄子精选",
           f(34, False), INK_SOFT)
    canvas.save(os.path.join(OUT, "03_产品内核.png"))
    print("03 ok")


# ---------------------------------------------------------------- 图 4 数据面板
def img4():
    canvas = Image.new("RGB", (W, H), (28, 28, 32))
    d = ImageDraw.Draw(canvas)

    center(d, 170, "TaoMind 上线至今", f(48, False), (150, 148, 144))
    d.line([(W / 2 - 60, 250), (W / 2 + 60, 250)], fill=(72, 72, 78), width=3)

    rows = [
        ("60",    "个用户",        (245, 243, 238)),
        ("0",     "个人付费",      (232, 128, 100)),
        ("166",   "条经文内容",    (245, 243, 238)),
        ("60",    "张珍藏卡插画",  (245, 243, 238)),
        ("5.0",   "App Store 评分", (245, 243, 238)),
    ]
    y = 370
    for num, label, col in rows:
        nb = d.textbbox((0, 0), num, font=f(120))
        nw = nb[2] - nb[0]
        lb = d.textbbox((0, 0), label, font=f(40, False))
        lw = lb[2] - lb[0]
        total = nw + 30 + lw
        x = (W - total) / 2
        d.text((x - nb[0], y - nb[1]), num, font=f(120), fill=col)
        d.text((x + nw + 30 - lb[0], y + 62 - lb[1]), label,
               font=f(40, False), fill=(160, 158, 154))
        y += 210

    footer(d, [("数字都是真的，包括那个 0", f(38, False), (140, 138, 134))])
    canvas.save(os.path.join(OUT, "04_数据面板.png"))
    print("04 ok")


# ---------------------------------------------------------------- 图 5 IAP bug
def img5():
    canvas = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(canvas)

    # 顶部引号装饰
    center(d, 110, "“", f(200), (214, 205, 190))

    y = 300
    y = text_block(d, y, ["苹果拒了我一次"], f(74), INK, gap=30)
    y = text_block(d, y, ["理由是："], f(74), INK, gap=48)

    # 引用框
    box_t, box_b = 530, 730
    d.rectangle([110, box_t, W - 110, box_b], fill=(240, 234, 222))
    d.text((165, box_t + 45), "App 内购买项目", font=f(48), fill=INK)
    d.text((165, box_t + 122), "不易找到", font=f(48), fill=INK)

    y = 830
    y = text_block(d, y, ["我当时觉得挺冤"], f(58), INK, gap=44)
    y = text_block(d, y, ["我明明做了付费墙"], f(58), INK, gap=64)

    y = text_block(d, y, ["查了两天才发现"], f(54), INK_SOFT, gap=34)
    y = text_block(d, y, ["有个终身买断选项"], f(64), INK, gap=26)
    y = text_block(d, y, ["挂在了 app 根本没读取的地方"], f(64), ACCENT, gap=54)

    y = text_block(d, y, ["从上线那天起"], f(56), INK, gap=26)
    y = text_block(d, y, ["没有任何一个用户能看到它"], f(56), INK, gap=26)

    footer(d, [
        ("所以我以为的「0 付费」", f(40, False), INK_SOFT),
        ("有一部分是：有个东西根本买不到", f(40, False), ACCENT),
    ])
    canvas.save(os.path.join(OUT, "05_IAP_bug.png"))
    print("05 ok")


# ---------------------------------------------------------------- 图 6 结尾
def img6():
    # 珍藏卡做底 + 半透明蒙版 + 文字
    base = Image.open(os.path.join(CARD, "46_final.jpg")).convert("RGB")
    # 裁成 3:4 并放大到画布
    th = int(base.width * H / W)
    top = max(0, (base.height - th) // 2)
    base = base.crop((0, top, base.width, top + th)).resize((W, H), Image.LANCZOS)

    veil = Image.new("RGB", (W, H), (250, 246, 238))
    base = Image.blend(base, veil, 0.62)

    d = ImageDraw.Draw(base)

    # 上部：核心信息
    y = 440
    y = text_block(d, y, ["它现在国内也能下载了"], f(70), INK, gap=34)
    y = text_block(d, y, ["免费，搜 TaoMind"], f(70), ACCENT, gap=30)

    # 分隔线
    d.line([(340, y + 70), (W - 340, y + 70)], fill=(198, 190, 176), width=3)

    # 下部：下一篇预告
    y = y + 170
    y = text_block(d, y, ["下一篇"], f(44, False), INK_SOFT, gap=30)
    y = text_block(d, y, ["我怎么发现有个付费项"], f(56), INK, gap=20)
    y = text_block(d, y, ["从来没人能买到"], f(56), INK, gap=20)

    footer(d, [("TaoMind", f(40, False), INK_SOFT)])
    base.save(os.path.join(OUT, "06_结尾.png"))
    print("06 ok")


if __name__ == "__main__":
    img3(); img4(); img5(); img6()
    print("\n输出目录:", OUT)
