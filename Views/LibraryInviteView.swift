import SwiftUI

// MARK: - Library Invite (增值型邀请)

/// 增值型邀请 —— 用户刚在 seek 结果页把一次洞见保存到日志之后弹。
///
/// 刻意不做成付费墙：这一刻用户刚拿到价值、情绪是正向的，所以主 CTA 是
/// 「去看看经藏」而不是「升级 Pro」。经藏前 5 章对免费用户本就开放，让用户
/// 先自己体会到经典原文与逐章精讲的价值，转化路径更长但更稳，也不会把
/// 「刚用完一次 seek」的满足感立刻换成「你该付钱了」的抵触。
///
/// 由 `AppState.showingLibraryInvite` 驱动，sheet 统一挂 ContentView 顶层
/// （理由见 ContentView 里对付费墙 sheet 的注释）。
struct LibraryInviteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(DS.bronze)
                .padding(.bottom, 22)

            Text(AppState.tr("library_invite_title"))
                .font(.system(size: 21, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(AppState.tr("library_invite_body"))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    // 先切 tab 再关 sheet：dismiss 是异步的，反过来可能出现
                    // 「sheet 已关、tab 没动」的空档。
                    appState.selectedTab = AppState.libraryTabTag
                    dismiss()
                } label: {
                    Text(AppState.tr("library_invite_cta"))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(DS.bronze)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    dismiss()
                } label: {
                    Text(AppState.tr("library_invite_later"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .presentationDetents([.medium])
    }
}
