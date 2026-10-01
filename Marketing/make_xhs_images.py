# -*- coding: utf-8 -*-
# 生成 TaoMind 小红书首篇的 4 张图（不依赖真机截图的那些）
# 输出目录见下方 OUT 常量
#
# 2026-10-01：全部改用 layout_check.Layout —— 跑完直接打印每行真实 y 区间并报重叠。
# 不要再 Read 回 PNG 判断"挤不挤"：图像里没有几何信息，那样判永远收敛不了。
import os, sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from layout_check import Layout

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


def text_block(L, y, lines, font, fill, gap=24):
    """逐行绘制并登记。每行的步进由 Layout.text 按真实字形高度算。"""
    for ln in lines:
        y = L.text(y, ln, font, fill) + gap
    return y


def footer(L, lines, min_top=None):
    """把脚注贴到底部安全区（小红书底部约留 90px）。

    min_top: 内容实际结束的 y。若脚注起点会越过它，说明内容太长——
    此时把脚注压在 min_top 之下，宁可整体下移也不让两段重叠。
    """
    heights = [sum(font.getmetrics()) for _, font, _ in lines]
    total = sum(heights) + 22 * (len(lines) - 1)
    y = H - 90 - total
    if min_top is not None and y < min_top + 30:
        y = min_top + 30
    for (text, font, fill) in lines:
        L.text(y, text, font, fill)
        y += sum(font.getmetrics()) + 22
    return y


def dump(L, tag):
    print(f"--- {tag} geometry ---")
    for label, x, yy, w, h, kind in L.items:
        print(f"  {label:<26} y {yy:7.1f} .. {yy + h:7.1f}   h={h:5.1f}  [{kind}]")
    print()


# ---------------------------------------------------------------- 图 3 产品内核
def img3():
    L = Layout(W, H, PAPER)
    canvas, d = L.canvas, L.draw

    # 三张珍藏卡横排
    cards = [Image.open(os.path.join(CARD, f"{n}_final.jpg")).convert("RGB")
             for n in (7, 20, 46)]
    cw, ch = 340, 604                     # 3:4 裁切后的卡片尺寸
    xs = [58, 451, 844]
    for im, x in zip(cards, xs):
        im2 = im.copy()
        tw, th = im2.width, int(im2.width * ch / cw)
        top = (im2.height - th) // 2
        im2 = im2.crop((0, top, tw, top + th)).resize((cw, ch), Image.LANCZOS)
        bd = Image.new("RGB", (cw + 6, ch + 6), (214, 206, 192))
        bd.paste(im2, (3, 3))
        canvas.paste(bd, (x, 150))

    # 三张卡片整体登记成一个占位块：文字不许压到它们
    L.block(55, 147, W - 110, 610, "珍藏卡横排 y150..757")

    y = 830
    y = text_block(L, y, ["你输入今天的困境"], f(78), INK, gap=18)
    y = text_block(L, y, ["它用 2500 年前的智慧回答你"], f(58), ACCENT, gap=18)

    L.text(1500, "TaoMind · 道德经 81 章 + 金刚经 32 品 + 庄子精选",
           f(34, False), INK_SOFT)

    dump(L, "03 产品内核")
    L.report(out_path=os.path.join(OUT, "03_产品内核.png"))
    print("03 ok")


# ---------------------------------------------------------------- 图 4 数据面板
def img4():
    L = Layout(W, H, PAPER)
    d = L.draw

    L.text(170, "TaoMind 上线至今", f(48, False), INK_SOFT)
    L.rule(250, x0=W / 2 - 60, x1=W / 2 + 60)

    rows = [
        ("60",  "个用户",          INK),
        ("0",   "个人付费",        ACCENT),
        ("166", "条经文内容",      INK),
        ("60",  "张珍藏卡插画",    INK),
        ("5.0", "App Store 评分",  INK),
    ]
    y = 380
    for num, label, col in rows:
        nb = d.textbbox((0, 0), num, font=f(120))
        nw = nb[2] - nb[0]
        lb = d.textbbox((0, 0), label, font=f(40, False))
        lw = lb[2] - lb[0]
        total = nw + 30 + lw
        x = (W - total) / 2
        d.text((x - nb[0], y - nb[1]), num, font=f(120), fill=col)
        d.text((x + nw + 30 - lb[0], y + 62 - lb[1]), label,
               font=f(40, False), fill=INK_SOFT)
        # 数字和标签同属一行，整体按 y..y+168 登记（含下方分隔线）
        L.block(x, y, total, 168, f"{num} {label}")
        if num != "5.0":
            d.line([(230, y + 168), (W - 230, y + 168)], fill=(228, 220, 206), width=2)
        y += 210

    footer(L, [("数字都是真的，包括那个 0", f(38, False), ACCENT)], min_top=y)

    dump(L, "04 数据面板")
    L.report(out_path=os.path.join(OUT, "04_数据面板.png"))
    print("04 ok")


# ---------------------------------------------------------------- 图 5 IAP bug
def img5():
    L = Layout(W, H, PAPER)
    d = L.draw

    # 顶部引号装饰（不算正文，体积很小，仍然登记避免被压）
    L.text(110, "“", f(200), (214, 205, 190))

    y = 300
    y = text_block(L, y, ["苹果拒了我一次"], f(74), INK, gap=30)
    y = text_block(L, y, ["理由是："], f(74), INK, gap=48)

    # 引用框
    box_t, box_b = 530, 730
    d.rectangle([110, box_t, W - 110, box_b], fill=(240, 234, 222))
    d.text((165, box_t + 45), "App 内购买项目", font=f(48), fill=INK)
    d.text((165, box_t + 122), "不易找到", font=f(48), fill=INK)
    L.block(110, box_t, W - 220, box_b - box_t, "引用框 y530..730")

    y = 810
    y = text_block(L, y, ["我当时觉得挺冤"], f(54), INK, gap=10)
    y = text_block(L, y, ["我明明做了付费墙"], f(54), INK, gap=52)

    y = text_block(L, y, ["查了两天才发现"], f(50), INK_SOFT, gap=16)
    y = text_block(L, y, ["有个终身买断选项"], f(58), INK, gap=8)
    y = text_block(L, y, ["挂在了 app 根本没读取的地方"], f(58), ACCENT, gap=26)

    y = text_block(L, y, ["从上线那天起"], f(54), INK, gap=8)
    y = text_block(L, y, ["没有任何一个用户能看到它"], f(54), INK, gap=8)

    footer(L, [
        ("所以我以为的「0 付费」", f(40, False), INK_SOFT),
        ("有一部分是：有个东西根本买不到", f(40, False), ACCENT),
    ], min_top=y)

    dump(L, "05 IAP bug")
    L.report(out_path=os.path.join(OUT, "05_IAP_bug.png"))
    print("05 ok")


# ---------------------------------------------------------------- 图 6 结尾
def img6():
    # 珍藏卡做底 + 半透明蒙版 + 文字
    base = Image.open(os.path.join(CARD, "46_final.jpg")).convert("RGB")
    th = int(base.width * H / W)
    top = max(0, (base.height - th) // 2)
    base = base.crop((0, top, base.width, top + th)).resize((W, H), Image.LANCZOS)

    veil = Image.new("RGB", (W, H), (250, 246, 238))
    base = Image.blend(base, veil, 0.62)

    L = Layout(W, H, PAPER)
    L.canvas = base                       # 直接在底图上画
    L.draw = ImageDraw.Draw(base)

    y = 440
    y = text_block(L, y, ["它现在国内也能下载了"], f(70), INK, gap=34)
    y = text_block(L, y, ["免费，搜 TaoMind"], f(70), ACCENT, gap=30)

    L.rule(y + 70, x0=340, x1=W - 340, color=(198, 190, 176))

    y = y + 170
    y = text_block(L, y, ["下一篇"], f(44, False), INK_SOFT, gap=30)
    y = text_block(L, y, ["我怎么发现有个付费项"], f(56), INK, gap=20)
    y = text_block(L, y, ["从来没人能买到"], f(56), INK, gap=20)

    footer(L, [("TaoMind", f(40, False), INK_SOFT)])

    dump(L, "06 结尾")
    L.report(out_path=os.path.join(OUT, "06_结尾.png"))
    print("06 ok")


if __name__ == "__main__":
    img3(); img4(); img5(); img6()
    print("\n输出目录:", OUT)
