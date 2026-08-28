import SwiftUI

// MARK: - Design System · 数字宣纸 (Digital Xuan Paper)
//
// 全局唯一的设计 token 来源：颜色、字体、圆角、阴影、纹理。
// 规则：任何界面不得内联 Color(red:green:blue:) —— 一律引用 DS.*。

enum DS {

    // MARK: 墨分五色 —— Palette

    /// 宣纸底（全局背景）
    static let paper = Color(red: 0.957, green: 0.937, blue: 0.890)      // #F4EFE3
    /// 卡纸（卡片表面，略亮）
    static let paperHi = Color(red: 0.992, green: 0.984, blue: 0.961)    // #FDFBF5
    /// 浓墨（正文、深底）
    static let ink = Color(red: 0.149, green: 0.129, blue: 0.102)        // #26211A
    /// 淡墨（次要文字）
    static let inkSoft = Color(red: 0.361, green: 0.325, blue: 0.275)    // #5C5346
    /// 宿墨（辅助/弱化文字）
    static let inkFaint = Color(red: 0.545, green: 0.506, blue: 0.447)   // #8B8172
    /// 朱砂（印章 · 主 CTA · 点睛）
    static let cinnabar = Color(red: 0.651, green: 0.227, blue: 0.169)   // #A63A2B
    /// 朱砂深（按压态）
    static let cinnabarDeep = Color(red: 0.549, green: 0.184, blue: 0.133) // #8C2F22
    /// 铜金（眉标 · 描边 · 点缀）
    static let bronze = Color(red: 0.541, green: 0.427, blue: 0.231)     // #8A6D3B
    /// 黛青（信息 · 链接 · 冷色平衡）
    static let indigo = Color(red: 0.184, green: 0.290, blue: 0.306)     // #2F4A4E
    /// 夜（付费墙等仪式性深底）
    static let night = Color(red: 0.133, green: 0.114, blue: 0.086)      // #221D16
    /// 夜之纸（深底上的文字）
    static let nightText = Color(red: 0.929, green: 0.902, blue: 0.839)  // #EDE6D6
    /// 夜之淡墨（深底上的次要文字）
    static let nightSoft = Color(red: 0.725, green: 0.682, blue: 0.592)  // #B9AE97
    /// 夜之金（深底上的金色点缀/描边）
    static let nightGold = Color(red: 0.788, green: 0.663, blue: 0.416)  // #C9A96A

    // MARK: 形制 —— Shape

    enum Radius {
        /// 卡片（纸的直感，弃用 iOS 默认大圆角）
        static let card: CGFloat = 6
        /// 按钮
        static let button: CGFloat = 4
        /// 印章
        static let seal: CGFloat = 5
        /// 小元素（chip、输入框）
        static let small: CGFloat = 4
    }

    // MARK: 字体 —— Typography
    //
    // 标题/经文用宋体（系统自带 Songti SC，中文）与 Georgia（西文引文），
    // 正文用系统黑体；眉标小字全大写 + 宽字距。

    /// 大标题 / 经文展示（宋体）
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold, relativeTo style: Font.TextStyle = .title) -> Font {
        Font.custom("Songti SC", size: size, relativeTo: style).weight(weight)
    }

    /// 章节题 / 卡片题（宋体）
    static func title(_ size: CGFloat = 19, weight: Font.Weight = .bold) -> Font {
        Font.custom("Songti SC", size: size, relativeTo: .title3).weight(weight)
    }

    /// 西文经文（Georgia，沿用既有资产）
    static func verse(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom("Georgia", size: size, relativeTo: style)
    }

    /// 眉标（全大写小字 + 宽字距）
    static let eyebrowFont: Font = .system(size: 11, weight: .semibold)
    /// 眉标字距
    static let eyebrowTracking: CGFloat = 3

    // MARK: 纹理 —— Paper Texture

    /// 宣纸纤维：极淡横纹，似有若无
    struct PaperTexture: View {
        var body: some View {
            Canvas { ctx, size in
                var y: CGFloat = 0
                var i = 0
                while y < size.height {
                    var path = Path()
                    path.addRect(CGRect(x: 0, y: y, width: size.width, height: 0.5))
                    ctx.fill(path, with: .color(Color.black.opacity(i % 7 == 0 ? 0.022 : 0.012)))
                    y += 3
                    i += 1
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - View Extensions

extension View {

    /// 三层柔和阴影（纸的厚度）
    func dsShadow() -> some View {
        self.shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.07), radius: 7, y: 5)
            .shadow(color: .black.opacity(0.05), radius: 18, y: 14)
    }

    /// 宣纸卡：卡纸底 + 铜金细描边 + 三层阴影
    func paperCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.paperHi)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(DS.bronze.opacity(0.30), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .dsShadow()
    }

    /// 深墨卡（付费墙套餐等，夜底描金）
    func nightCard(strokeOpacity: Double = 0.22, padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.night.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(DS.nightText.opacity(strokeOpacity), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    /// 全局宣纸背景：纸色 + 纤维纹理
    func paperBackground() -> some View {
        self.background(
            ZStack {
                DS.paper.ignoresSafeArea()
                DS.PaperTexture().ignoresSafeArea()
            }
        )
    }

    /// 眉标样式（全大写 + 宽字距 + 铜金）
    func eyebrowStyle(_ color: Color = DS.bronze) -> some View {
        self.font(DS.eyebrowFont)
            .foregroundColor(color)
            .tracking(DS.eyebrowTracking)
            .textCase(.uppercase)
    }
}

// MARK: - 朱砂印章按钮（签名交互）
//
// 按压：缩放 + 回弹 + 触感反馈，如按印落泥。

struct SealButton: View {
    let character: String          // 印文（单字，如 "求"）
    var caption: String? = nil     // 印下小字（如 "按印 · 开始求取"）
    var size: CGFloat = 64
    var enabled: Bool = true
    var busy: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.seal)
                        .fill(enabled || busy ? DS.cinnabar : DS.inkFaint.opacity(0.5))
                    RoundedRectangle(cornerRadius: DS.Radius.seal)
                        .stroke(DS.cinnabarDeep.opacity(enabled || busy ? 0.8 : 0.2), lineWidth: 1.5)
                        .padding(2)
                    if busy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(DS.paperHi)
                    } else {
                        Text(character)
                            .font(DS.display(size * 0.44, weight: .black, relativeTo: .largeTitle))
                            .foregroundColor(DS.paperHi)
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(2))
                .scaleEffect(pressed ? 0.94 : 1)
                .shadow(color: DS.cinnabarDeep.opacity(enabled || busy ? 0.35 : 0), radius: 8, y: 3)
                if let caption = caption {
                    Text(caption)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.inkSoft)
                        .tracking(2)
                }
            }
        }
        .buttonStyle(PressableSealStyle(pressed: $pressed))
        .disabled(!enabled)
        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: pressed)
        .accessibilityLabel(caption ?? character)
    }
}

struct PressableSealStyle: ButtonStyle {
    @Binding var pressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed = $0 }
    }
}
