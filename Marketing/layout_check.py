# -*- coding: utf-8 -*-
"""PIL 排版几何重叠检测 —— 给 make_xhs_*.py 提供确定性的验收手段。

Why this exists
---------------
2026-09-30：一条 XHS 会话在生成首图时陷入死循环 —— 改 y 坐标 -> 跑脚本 ->
Read 回 PNG 看图 -> "好像还是有点挤" -> 再改。40 秒里烧了 20+ 轮工具往返，
界面上一个字都不出（每轮 text=0B），用户看到的就是"自动停止"。

根因不是脚本 bug，是**验收手段错了**：模型拿"看图的视觉效果"当判据，而图像
里没有几何信息 —— 图看起来差不多就再挪一点，永远定不下"完成"。这和 2026-09-25
那次 .verdict 压 .note 的盲区是同一类坑（绝对定位压内容撑高的块，像素扫描读成
一条带 -> 假绿），只是那次在 DOM，这次在 PIL。

所以：不要让模型看图标定。让脚本**自己报出毫米级的几何冲突**，模型拿到
`OVERLAP line3-line4 by 14px` 这种确定性信息，一次就能收敛。

用法
----
    from layout_check import Layout

    L = Layout(W=1242, H=1656)
    L.text(y, "我做了一个 App", font, INK)        # 画字并记录真实 bbox
    L.rule(y)                                      # 分隔线也算占位
    L.report()                                     # 有冲突则 raise LayoutError

`text()` 返回的是下一行的推荐 y（= 本行底边 + 行距），和原来的 center() 行为
一致，所以老脚本改起来只是把 `center(d, y, ...)` 换成 `L.text(y, ...)`。

边界处理（照抄 DOM 版 overlap_check.py 的教训，否则工具会一直喊狼来了）：
  * 相邻行**留白不足**才算问题：MIN_GAP 以内视为正常紧排，不算冲突。
  * 真实重叠（bbox 相交）= FAIL，这是硬错误。
  * 超出安全区（上下 100px）= FAIL。
被排除的不是"重叠"，是"没必要报的紧排"。
"""
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("need Pillow: pip install pillow", file=sys.stderr)
    raise

# 相邻元素垂直间距小于这个值才算冲突。中文大字的行盒本身有内边距，
# 视觉上 14px 的 bbox 交叠在大字上常是正常的字面/字盒差，不是真压字。
MIN_GAP = 6.0
# 超出这个范围的内容视为侵入安全区（小红书底部 UI 会盖住）
SAFE_TOP = 0
SAFE_BOTTOM = 1656 - 80


class LayoutError(Exception):
    pass


class Layout:
    def __init__(self, W, H, bg=(250, 246, 238)):
        self.W, self.H = W, H
        self.canvas = Image.new("RGB", (W, H), bg)
        self.draw = ImageDraw.Draw(self.canvas)
        self.items = []          # (label, x, y, w, h, kind)
        self._pending = []       # 收集完再算，避免边画边报

    # ---------- 绘制 ----------
    def text(self, y, s, font, fill, label=None, gap=0.0, center=True):
        """画一行居中文本，记录真实 bbox，返回下一行推荐 y。"""
        box = self.draw.textbbox((0, 0), s, font=font)
        w = box[2] - box[0]
        x = (self.W - w) / 2 - box[0] if center else 0
        draw_y = y - box[1]
        self.draw.text((x, draw_y), s, font=font, fill=fill)
        # 记录字形实际占据的矩形（用 textbbox 的真实上下沿，不是字盒）
        top = y - box[1] + box[1]
        real_y = draw_y + box[1]
        self.items.append((label or s[:14], x + box[0], real_y, w, box[3] - box[1], "text"))
        return y + (box[3] - box[1]) + gap

    def rule(self, y, x0=None, x1=None, color=(206, 198, 184), width=3):
        """画一条分隔线，作为占位元素参与检测。"""
        x0 = 300 if x0 is None else x0
        x1 = self.W - 300 if x1 is None else x1
        self.draw.line([(x0, y), (x1, y)], fill=color, width=width)
        self.items.append((f"rule@{y}", x0, y - width / 2, x1 - x0, width, "rule"))

    def block(self, x, y, w, h, label):
        """手工登记一个占位块（比如贴图）。"""
        self.items.append((label, x, y, w, h, "block"))

    # ---------- 检测 ----------
    def check(self, verbose=True):
        from itertools import combinations
        hits = []
        for (la, xa, ya, wa, ha, ka), (lb, xb, yb, wb, hb, kb) in combinations(self.items, 2):
            # 水平方向不交 => 无关
            ox = min(xa + wa, xb + wb) - max(xa, xb)
            if ox <= 4:
                continue
            # 垂直方向：算带符号间隙，重叠为正
            gap = min(ya + ha, yb + hb) - max(ya, yb)
            if gap > MIN_GAP:
                hits.append((la, ya, ya + ha, lb, yb, yb + hb, gap))
        # 安全区
        for (l, x, y, w, h, k) in self.items:
            if y < SAFE_TOP:
                hits.append((l, y, y + h, "SAFE-TOP", SAFE_TOP, SAFE_TOP, y - SAFE_TOP))
            if y + h > SAFE_BOTTOM:
                hits.append((l, y, y + h, "SAFE-BOTTOM", SAFE_BOTTOM, SAFE_BOTTOM,
                             (y + h) - SAFE_BOTTOM))
        return hits

    def report(self, out_path=None):
        hits = self.check()
        if out_path:
            self.canvas.save(out_path)
        if hits:
            print(f"\n!! {len(hits)} LAYOUT COLLISION(S)\n")
            for la, ya, yae, lb, yb, ybe, gap in hits:
                print(f"  {la!r}  y {ya:.0f}..{yae:.0f}")
                print(f"  {lb!r}  y {yb:.0f}..{ybe:.0f}")
                print(f"      overlap {gap:.0f}px\n")
            print("=" * 58)
            print(f"RESULT: {len(hits)} FAILURE(S) -- fix before shipping")
            raise LayoutError(f"{len(hits)} layout collision(s)")
        print(f"RESULT: no layout collisions  ({len(self.items)} elements checked)")
        if out_path:
            print(f"saved -> {out_path}")
        return True
