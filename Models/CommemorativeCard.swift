import UIKit

// MARK: - Commemorative Card (修行纪念卡)

/// 打卡纪念卡：每次打卡随机收藏一张，对应《道德经》81 章之一，全套 81 张。
/// 引文内置客户端（双语），收藏张数由服务端已有 total_checkins 推导（零服务端改动），
/// 具体发哪张由客户端从未拥有的章号里随机抽取并持久化。
struct CommemorativeCard: Identifiable {
    /// 道德经章号 1...81（随机发放，与打卡天数无固定对应）
    let number: Int
    let titleZh: String
    let titleEn: String

    var id: Int { number }

    /// 卡面艺术图（Assets 里的 imageset 名，用户分批生图后逐张补入；未就绪时客户端画程序化 fallback）
    var artName: String { "CardArt-\(number)" }
    var hasArt: Bool { UIImage(named: artName) != nil }

    func title(isChinese: Bool) -> String { isChinese ? titleZh : titleEn }
}

enum CommemorativeCardSeries {
    static let total = 81

    static func card(_ number: Int) -> CommemorativeCard? {
        guard (1...total).contains(number), number <= quotes.count else { return nil }
        let q = quotes[number - 1]
        return CommemorativeCard(number: number, titleZh: q.zh, titleEn: q.en)
    }

    /// 已解锁张数 = min(总打卡天数, 81)
    static func unlockedCount(totalCheckins: Int) -> Int {
        min(max(totalCheckins, 0), total)
    }

    // 已拥有卡集合（UserDefaults）：收藏张数上限 = min(总打卡天数, 81)，
    // 具体哪张在解锁时从未拥有的章号里随机抽取后记入。key 沿用旧版顺序发卡
    // 时代的存储，老用户已拿到的卡号自动平移，不会重复发放。
    private static let ownedKey = "commemorative_cards_revealed"

    static var ownedCount: Int { ownedNumbers.count }

    static func isOwned(_ number: Int) -> Bool {
        ownedNumbers.contains(number)
    }

    /// 随机发卡：已拥有张数少于目标张数 `targetCount` 时，从未拥有的章号里
    /// 随机抽一张记入拥有集合并返回；没有新卡可发时返回 nil。
    @discardableResult
    static func grantRandomUnownedCard(targetCount: Int) -> CommemorativeCard? {
        let owned = ownedNumbers
        guard owned.count < min(max(targetCount, 0), total) else { return nil }
        guard let pick = (1...total).filter({ !owned.contains($0) }).randomElement(),
              let card = card(pick) else { return nil }
        var updated = owned
        updated.insert(pick)
        UserDefaults.standard.set(updated.map(String.init), forKey: ownedKey)
        return card
    }

    private static var ownedNumbers: Set<Int> {
        Set((UserDefaults.standard.stringArray(forKey: ownedKey) ?? []).compactMap(Int.init))
    }

    /// 《道德经》81 章章首句（王弼本章句 + 英译对齐 App 现有经文风格），
    /// 下标 i 即第 i+1 章。
    private static let quotes: [(zh: String, en: String)] = [
        ("道可道，非常道。", "The Tao that can be told is not the eternal Tao."),
        ("天下皆知美之为美，斯恶已。", "When the world knows beauty as beauty, ugliness arises."),
        ("不尚贤，使民不争。", "Do not exalt the talented, and people will not compete."),
        ("道冲而用之或不盈。", "The Tao is empty, yet inexhaustible."),
        ("天地不仁，以万物为刍狗。", "Heaven and earth are not kind — they treat all things as straw dogs."),
        ("谷神不死，是谓玄牝。", "The valley spirit never dies."),
        ("天长地久。", "Heaven is lasting and earth endures."),
        ("上善若水。", "The highest good is like water."),
        ("持而盈之，不如其已。", "Fill a cup to the brim and it will spill."),
        ("载营魄抱一，能无离乎？", "Can you hold your spirit and embrace the One without letting it slip away?"),
        ("三十辐共一毂，当其无，有车之用。", "Thirty spokes share one hub — the empty center makes the wheel useful."),
        ("五色令人目盲。", "Five colors blind the eye."),
        ("宠辱若惊。", "Favor and disgrace are alike a shock."),
        ("视之不见，名曰夷。", "Look at it and it cannot be seen — it is invisible."),
        ("孰能浊以静之徐清？", "Who can wait until the mud settles and the water clears?"),
        ("致虚极，守静笃。", "Reach the utmost emptiness; hold fast to stillness."),
        ("太上，下知有之。", "The best leader is one whose existence is barely known."),
        ("大道废，有仁义。", "When the great Tao is abandoned, benevolence and righteousness appear."),
        ("绝圣弃智，民利百倍。", "Abandon sageliness, discard cleverness — people benefit a hundredfold."),
        ("绝学无忧。", "Give up contrived learning, and there are no vexations."),
        ("孔德之容，惟道是从。", "The greatest virtue follows the Tao alone."),
        ("曲则全，枉则直。", "Yield and be whole; bend and be straight."),
        ("希言自然。", "Few words come naturally."),
        ("企者不立，跨者不行。", "One who stands on tiptoe is not steady."),
        ("有物混成，先天地生。", "There is something formlessly complete, born before heaven and earth."),
        ("重为轻根，静为躁君。", "The heavy is the root of the light; stillness rules the restless."),
        ("善行无辙迹。", "A good traveler leaves no tracks."),
        ("知其雄，守其雌，为天下溪。", "Know the masculine, keep to the feminine — a channel for the world."),
        ("将欲取天下而为之，吾见其不得已。", "Whoever tries to force the world, I see will never succeed."),
        ("以道佐人主者，不以兵强天下。", "One who guides a ruler with the Tao does not subdue the world by force."),
        ("夫兵者，不祥之器。", "Weapons are instruments of misfortune."),
        ("道常无名，朴虽小，天下莫能臣。", "The Tao is forever nameless — simple and small, yet nothing can master it."),
        ("知人者智，自知者明。", "Knowing others is wisdom; knowing yourself is enlightenment."),
        ("大道泛兮，其可左右。", "The great Tao flows everywhere, to the left and to the right."),
        ("执大象，天下往。", "Hold the great image, and the world will come to you."),
        ("将欲歙之，必固张之。", "To shrink something, you must first let it expand."),
        ("道常无为而无不为。", "The Tao never acts, yet nothing is left undone."),
        ("上德不德，是以有德。", "The highest virtue does not strive for virtue — thus it has virtue."),
        ("昔之得一者。", "Since ancient times, all things have found the One."),
        ("反者道之动，弱者道之用。", "Returning is the movement of the Tao; yielding is its way."),
        ("上士闻道，勤而行之。", "The best student hears of the Tao and practices it diligently."),
        ("道生一，一生二，二生三，三生万物。", "The Tao gives birth to One, One to Two, Two to Three, Three to all things."),
        ("天下之至柔，驰骋天下之至坚。", "The softest thing in the world rides roughshod over the hardest."),
        ("名与身孰亲？", "Fame or self: which is dearer?"),
        ("大成若缺，其用不弊。", "The greatest perfection seems imperfect — yet its use never fails."),
        ("天下有道，却走马以粪。", "When the world has the Tao, galloping horses are returned to plow the fields."),
        ("不出户，知天下。", "Without going out the door, one knows the world."),
        ("为学日益，为道日损。", "The student gains daily; the practitioner of the Tao loses daily."),
        ("圣人常无心，以百姓心为心。", "The sage has no fixed mind — they take the people's mind as their mind."),
        ("出生入死。", "We come into life and enter death."),
        ("道生之，德畜之。", "The Tao gives them birth; virtue nurtures them."),
        ("天下有始，以为天下母。", "The world has a beginning — it is the mother of the world."),
        ("使我介然有知，行于大道。", "If I had any certainty, I would walk only the great Way."),
        ("善建者不拔，善抱者不脱。", "What is well planted cannot be uprooted."),
        ("含德之厚，比于赤子。", "One rich in virtue is like a newborn infant."),
        ("知者不言，言者不知。", "Those who know do not speak; those who speak do not know."),
        ("以正治国，以奇用兵。", "Govern the country with rectitude; wage war with surprise."),
        ("其政闷闷，其民淳淳。", "When the government is relaxed, the people are honest."),
        ("治人事天，莫若啬。", "In governing people and serving heaven, nothing compares to frugality."),
        ("治大国，若烹小鲜。", "Governing a great country is like cooking a small fish."),
        ("大国者下流，天下之交。", "A great country is like low ground — where all streams converge."),
        ("道者，万物之奥。", "The Tao is the hidden refuge of all things."),
        ("为无为，事无事，味无味。", "Act without doing; work without effort; taste the flavorless."),
        ("合抱之木，生于毫末。", "A tree that fills the arms grows from a tiny shoot."),
        ("古之善为道者，非以明民。", "The ancients who practiced the Tao did not make people clever — they kept them simple."),
        ("江海所以能为百谷王者，以其善下之。", "Rivers and seas are kings of all valleys because they lie below them."),
        ("我有三宝，持而保之。", "I have three treasures I hold and keep."),
        ("善为士者，不武。", "A good warrior is not violent."),
        ("用兵有言：吾不敢为主而为客。", "The strategists say: I dare not be the host — I prefer to be the guest."),
        ("吾言甚易知，甚易行。", "My words are very easy to understand and very easy to practice."),
        ("知不知，尚矣。", "To know that you do not know is highest."),
        ("民不畏威，则大威至。", "When people no longer fear force, great force arrives."),
        ("勇于敢则杀，勇于不敢则活。", "Daring to act brings death; daring not to act brings life."),
        ("民不畏死，奈何以死惧之？", "If people do not fear death, how can death frighten them?"),
        ("民之饥，以其上食税之多。", "People starve because those above them consume too much in taxes."),
        ("人之生也柔弱，其死也坚强。", "One is born soft and supple; in death, hard and rigid."),
        ("天之道，其犹张弓与？", "The way of heaven is like drawing a bow."),
        ("天下莫柔弱于水。", "Nothing in the world is softer than water."),
        ("和大怨，必有余怨。", "Where a great grievance is patched up, some resentment remains."),
        ("小国寡民。", "A small country with few people."),
        ("信言不美，美言不信。", "Truthful words are not beautiful; beautiful words are not truthful."),
    ]
}
