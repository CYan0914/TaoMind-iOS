import SwiftUI
import UIKit

// MARK: - Commemorative Card Views (修行纪念卡)

/// 卡面视图：有艺术图（CardArt-N）用图，没有就画程序化宣纸 fallback。
/// 解锁弹窗、收藏册宫格、分享渲染三处共用。
struct CardFaceView: View {
    let card: CommemorativeCard
    let isChinese: Bool
    /// 收藏册宫格里用小字号
    var compact: Bool = false

    var body: some View {
        ZStack {
            if let art = UIImage(named: card.artName) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackArt
            }

            VStack(spacing: 0) {
                Spacer()

                // 底部渐隐衬底，保证任何艺术图上文字可读
                LinearGradient(
                    colors: [DS.ink.opacity(0.0),
                             DS.ink.opacity(0.72)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: compact ? 52 : 108)
                .overlay(bottomText)
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 18))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 18)
                .stroke(DS.bronze.opacity(0.35), lineWidth: 1)
        )
    }

    private var chapterLabel: String {
        isChinese ? "道德经 · 第\(card.number)章" : "Tao Te Ching · Chapter \(card.number)"
    }

    private var bottomText: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            Text(chapterLabel)
                .font(compact ? .system(size: 8, weight: .semibold) : .caption.weight(.semibold))
                .foregroundColor(DS.paperHi.opacity(0.85))
            Text(card.title(isChinese: isChinese))
                .font(compact ? .system(size: 9) : .custom("Georgia", size: 14, relativeTo: .footnote))
                .italic(!isChinese)
                .foregroundColor(DS.ink.opacity(0.04))
                .lineLimit(compact ? 2 : 3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 16)
        .padding(.bottom, compact ? 7 : 14)
        .padding(.top, compact ? 4 : 8)
    }

    /// 程序化 fallback：宣纸色渐变 + 水印章号 + ☯ 印。艺术图逐张补入后自动被替换。
    private var fallbackArt: some View {
        ZStack {
            LinearGradient(
                colors: [DS.ink.opacity(0.04),
                         DS.ink.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Text(String(card.number))
                .font(.system(size: compact ? 44 : 88, weight: .light, design: .serif))
                .foregroundColor(DS.bronze.opacity(0.16))

            VStack {
                HStack {
                    Spacer()
                    Text("☯")
                        .font(.system(size: compact ? 12 : 20))
                        .foregroundColor(DS.cinnabar.opacity(0.8))
                        .padding(compact ? 4 : 7)
                        .background(DS.ink.opacity(0.04).opacity(0.9))
                        .cornerRadius(4)
                        .rotation3DEffect(.degrees(4), axis: (x: 0, y: 0, z: 1))
                        .padding(compact ? 7 : 14)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Unlock Sheet（打卡成功后的新卡揭示弹窗）

/// 打卡成功随即弹出：今日新收的纪念卡 + 收集进度，可分享（分享图带 App Store 二维码）。
/// 全用户开放（收集是留存钩子，不是付费点）。
struct CommemorativeCardUnlockView: View {
    let card: CommemorativeCard
    /// 解锁这张卡时的总打卡天数（随机发卡后与卡号无对应关系，仅用于文案）
    let totalCheckins: Int
    let isChinese: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 18) {
            Text(AppState.tr("card_unlock_title"))
                .font(.custom("Georgia", size: 20, relativeTo: .title3))
                .fontWeight(.semibold)
                .foregroundColor(DS.ink)
                .padding(.top, 24)

            CardFaceView(card: card, isChinese: isChinese)
                .frame(width: 230)
                .scaleEffect(revealed ? 1 : 0.86)
                .opacity(revealed ? 1 : 0)
                .rotation3DEffect(.degrees(revealed ? 0 : -8), axis: (x: 0, y: 1, z: 0))

            Text(AppState.tr("card_unlocked_fmt", totalCheckins, card.number, CommemorativeCardSeries.total))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { showShare = true }) {
                Label(AppState.tr("Share"), systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DS.ink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 36)

            Button(AppState.tr("OK")) { dismiss() }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .onAppear {
            Analytics.cardUnlocked(number: card.number)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.15)) {
                revealed = true
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = CommemorativeCardRenderer.image(for: card, isChinese: isChinese) {
                ShareSheet(activityItems: [img])
            }
        }
    }
}

// MARK: - Collection（收藏册）

/// 修行纪念册：81 宫格，已拥有的章显示卡面、未拥有的显示剪影。
/// 已拥有集合持久化在客户端（随机发放），进度直接读 ownedCount。
struct CardCollectionView: View {
    let isChinese: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var previewCard: CommemorativeCard?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    private var owned: Int { CommemorativeCardSeries.ownedCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 进度
                    VStack(spacing: 8) {
                        Text("\(owned) / \(CommemorativeCardSeries.total)")
                            .font(.custom("Georgia", size: 30, relativeTo: .title))
                            .fontWeight(.bold)
                            .foregroundColor(DS.ink)
                        ProgressView(value: Double(owned), total: Double(CommemorativeCardSeries.total))
                            .tint(DS.cinnabar)
                            .padding(.horizontal, 48)
                        Text(AppState.tr("card_collection_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...CommemorativeCardSeries.total, id: \.self) { n in
                            if let card = CommemorativeCardSeries.card(n), CommemorativeCardSeries.isOwned(n) {
                                Button(action: { previewCard = card }) {
                                    CardFaceView(card: card, isChinese: isChinese, compact: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                lockedCell(number: n)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .paperBackground()
            .navigationTitle(AppState.tr("card_collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppState.tr("Close")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .sheet(item: $previewCard) { card in
                CardDetailSheet(card: card, isChinese: isChinese)
            }
            .onAppear { Analytics.collectionOpened() }
        }
    }

    private func lockedCell(number: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(DS.bronze.opacity(0.06))
            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(isChinese ? "第\(number)章" : "Ch. \(number)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

/// 收藏册点开单张大卡预览
private struct CardDetailSheet: View {
    let card: CommemorativeCard
    let isChinese: Bool

    var body: some View {
        VStack(spacing: 16) {
            CardFaceView(card: card, isChinese: isChinese)
                .frame(width: 270)
                .padding(.top, 32)
            Text("\(card.number) / \(CommemorativeCardSeries.total)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .presentationDetents([.medium])
    }
}

// MARK: - Share Rendering

/// 纪念卡分享图：卡面 + 底部署名与 App Store 二维码（裂变闭环，与分享卡同款）。
private struct CommemorativeCardShareView: View {
    let card: CommemorativeCard
    let isChinese: Bool

    var body: some View {
        VStack(spacing: 14) {
            CardFaceView(card: card, isChinese: isChinese)
                .frame(width: 270)

            HStack(spacing: 12) {
                if let qr = QRCodeMaker.appStoreQR() {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .padding(5)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppState.tr("share_card_subtitle"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DS.ink)
                    Text(AppState.tr("share_card_download_hint"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .padding(24)
        .frame(width: 340)
        .paperBackground()
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(DS.bronze.opacity(0.3), lineWidth: 1)
        )
    }
}

@MainActor
enum CommemorativeCardRenderer {
    static func image(for card: CommemorativeCard, isChinese: Bool) -> UIImage? {
        let renderer = ImageRenderer(content: CommemorativeCardShareView(card: card, isChinese: isChinese))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
