import SwiftUI

// MARK: - Milestone Info (连续打卡里程碑)

struct MilestoneInfo: Identifiable, Equatable {
    let days: Int
    let titleZh: String
    let titleEn: String
    let quoteZh: String
    let quoteEn: String

    var id: Int { days }

    static let all: [MilestoneInfo] = [
        MilestoneInfo(
            days: 7,
            titleZh: "初窥门径", titleEn: "A Foot in the Door",
            quoteZh: "合抱之木，生于毫末；九层之台，起于累土。",
            quoteEn: "A tree that fills a man's arms grows from a tiny sprout."
        ),
        MilestoneInfo(
            days: 21,
            titleZh: "习惯初成", titleEn: "Habit Takes Root",
            quoteZh: "为之于未有，治之于未乱。",
            quoteEn: "Deal with things before they happen; set things in order before there is confusion."
        ),
        MilestoneInfo(
            days: 49,
            titleZh: "如理作意", titleEn: "Wisdom Deepens",
            quoteZh: "知人者智，自知者明。",
            quoteEn: "Knowing others is intelligence; knowing yourself is true wisdom."
        ),
        MilestoneInfo(
            days: 81,
            titleZh: "九九归一", titleEn: "The Way Returns",
            quoteZh: "大器晚成，大音希声，大象无形。",
            quoteEn: "The great vessel is last completed; the great sound is barely heard; the great image has no form."
        ),
    ]
}

// MARK: - Milestone Celebration

struct MilestoneCelebrationView: View {
    let milestone: MilestoneInfo
    let isChinese: Bool
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🎋")
                .font(.system(size: 56))

            Text("\(milestone.days)")
                .font(.custom("Georgia", size: 54, relativeTo: .largeTitle))
                .fontWeight(.bold)
                .foregroundColor(DS.ink)

            Text(String(format: AppState.tr("streak_days_fmt"), milestone.days))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(isChinese ? milestone.titleZh : milestone.titleEn)
                .font(.custom("Georgia", size: 22, relativeTo: .title2))
                .fontWeight(.semibold)
                .foregroundColor(DS.ink)

            Text("“\(isChinese ? milestone.quoteZh : milestone.quoteEn)”")
                .font(.custom("Georgia", size: 16, relativeTo: .body))
                .italic()
                .foregroundColor(DS.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 28)

            Button(action: onShare) {
                Label(AppState.tr("Share"), systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DS.ink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
    }
}
