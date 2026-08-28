import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showReferral = false

    var body: some View {
        List {
            // MARK: - Subscription Section
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Text("☯")
                            .font(.system(size: 36))
                        Spacer()
                        if subscriptionManager.isPro {
                            Label("Active", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        } else {
                            Text("Free Tier")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                    }

                    if subscriptionManager.isPro {
                        Text("You have full access to all features. Thank you for supporting TaoMind!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unlimited wisdom sessions, journal entries, and more.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if subscriptionManager.isPro {
                        Button(action: { Task { await subscriptionManager.restore() } }) {
                            HStack {
                                if subscriptionManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Text("Restore Purchases")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DS.ink.opacity(0.045))
                            .foregroundColor(.primary)
                            .cornerRadius(DS.Radius.card)
                        }
                        .disabled(subscriptionManager.isLoading)
                    } else {
                        Button(action: { subscriptionManager.openPaywall(.generic) }) {
                            HStack {
                                Text("Upgrade to Premium")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DS.ink)
                            .foregroundColor(.white)
                            .cornerRadius(DS.Radius.card)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Label("TaoMind Premium", systemImage: subscriptionManager.isPro ? "crown.fill" : "crown")
            }

            // MARK: - Preferences
            Section {
                Picker("Language", selection: $appState.language) {
                    ForEach(AppState.Language.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }

                Text("Responses will appear in your selected language when supported.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("Preferences", systemImage: "gearshape")
            }

            // MARK: - About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.secondary)
                }

                // 评分入口（兜底：不受 7 天节点规则限制）
                Button {
                    ReviewPromptService.shared.promptNow()
                } label: {
                    HStack {
                        Text(AppState.tr("rate_taomind"))
                        Spacer()
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)

                // 推荐裂变入口（双向 7 天 Pro）
                Button {
                    showReferral = true
                } label: {
                    HStack {
                        Text(AppState.tr("referral_title"))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("✨")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Text("API Status")
                    Spacer()
                    Label("Connected", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }

                Link("Privacy Policy", destination: URL(string: "https://cyan0914.github.io/taomind-privacy/privacy.html")!)
                Link("Terms of Service", destination: URL(string: "https://cyan0914.github.io/taomind-privacy/terms.html")!)
            } header: {
                Label("About", systemImage: "info.circle")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TaoMind brings the wisdom of the Tao Te Ching and Diamond Sutra to your modern challenges.")
                        .font(.caption)
                    Text("\nAll AI-generated content is reflective in nature and not a substitute for professional advice.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showReferral) {
            ReferralView()
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $subscriptionManager.showingPaywall) {
            PaywallView(context: subscriptionManager.paywallContext)
        }
        .task {
            // Refresh subscription status when user opens Settings
            await subscriptionManager.refreshStatus()
        }
    }
}
