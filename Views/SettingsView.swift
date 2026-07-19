import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager

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

                    // Always show Restore Purchases (for users whose entitlements need syncing)
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
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    .disabled(subscriptionManager.isLoading)

                    if !subscriptionManager.isPro {
                        Button(action: { subscriptionManager.showingPaywall = true }) {
                            HStack {
                                Text("Upgrade to Premium")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.17, green: 0.14, blue: 0.09))
                            .foregroundColor(.white)
                            .cornerRadius(12)
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
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

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
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $subscriptionManager.showingPaywall) {
            PaywallView()
        }
        .task {
            // Refresh subscription status when user opens Settings
            await subscriptionManager.refreshStatus()
        }
    }
}
