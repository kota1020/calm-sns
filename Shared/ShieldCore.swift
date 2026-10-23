import Foundation
import AppIntents
import FamilyControls
import ManagedSettings
import WidgetKit
import Security

// Calm本体とウィジェットで同じ「止める」の状態（オン・オフ、止めるアプリ、切り替えた回数）を読み書きする場所。
// アプリグループが使えないので、両方から読めるキーチェーンの共有グループ（Info.plist の CalmKeychainGroup）に置く
enum SharedStore {
    static let group = Bundle.main.object(forInfoDictionaryKey: "CalmKeychainGroup") as? String ?? ""
    private static func base() -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "calm", kSecAttrAccount as String: "state"]
        if !group.isEmpty { q[kSecAttrAccessGroup as String] = group }
        return q
    }
    static func load() -> [String: Any] {
        var q = base(); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j
    }
    static func save(_ j: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: j) else { return }
        let q = base()
        if SecItemUpdate(q as CFDictionary, [kSecValueData as String: d] as CFDictionary) == errSecItemNotFound {
            var a = q; a[kSecValueData as String] = d; a[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(a as CFDictionary, nil)
        }
    }
    static func update(_ f: (inout [String: Any]) -> Void) { var j = load(); f(&j); save(j) }
}

// 「止める」のオン・オフの中身。Calm本体とホーム画面のウィジェットの両方から使う
// 状態はキーチェーンの共有グループに置き、本体とウィジェットの両方から読む
enum ShieldCore {
    static var on: Bool { SharedStore.load()["on"] as? Bool ?? false }
    static var blockedNow: Bool { !(ManagedSettingsStore().application.blockedApplications ?? []).isEmpty }
    static func selection() -> FamilyActivitySelection {
        guard let b = SharedStore.load()["sel"] as? String, let d = Data(base64Encoded: b),
              let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: d) else { return FamilyActivitySelection() }
        return s
    }
    static func save(on: Bool, selection: FamilyActivitySelection) {
        let d = try? JSONEncoder().encode(selection)
        SharedStore.update { j in
            j["on"] = on
            if let d { j["sel"] = d.base64EncodedString() }
        }
    }
    // 本物のアプリを隠す（「制限中」の盾はCalmの中のサイトまで止めるので使わない）
    static func apply(on: Bool, selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.application.blockedApplications = on && !selection.applicationTokens.isEmpty ? Set(selection.applicationTokens.map { Application(token: $0) }) : nil
    }
    // 切り替えた回数を日ごとに残す（"2026-10-23": [オン, オフ]）
    private static func dayKey(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
    static func record(_ on: Bool) {
        SharedStore.update { j in
            var all = j["log"] as? [String: [Int]] ?? [:]
            var v = all[dayKey()] ?? [0, 0]
            v[on ? 0 : 1] += 1
            all[dayKey()] = v
            j["log"] = all
        }
    }
    // 直近の日ごとのオフにした回数（古い順）
    static func offCounts(days: Int) -> [(label: String, n: Int)] {
        let all = SharedStore.load()["log"] as? [String: [Int]] ?? [:]
        let cal = Calendar.current, wd = ["日", "月", "火", "水", "木", "金", "土"]
        return (0..<days).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: Date())!
            return (wd[cal.component(.weekday, from: d) - 1], all[dayKey(d)]?[1] ?? 0)
        }
    }
    static func todayCounts() -> (on: Int, off: Int) {
        let v = (SharedStore.load()["log"] as? [String: [Int]])?[dayKey()] ?? [0, 0]
        return (v[0], v[1])
    }
    static func set(_ v: Bool) {
        record(v)
        let s = selection()
        save(on: v, selection: s)
        apply(on: v, selection: s)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .calmShieldChanged, object: nil)
    }
    // 前の版の保存場所（本体だけのUserDefaults）から一度だけ移す
    static func migrate() {
        let u = UserDefaults.standard
        guard SharedStore.load()["sel"] == nil, let d = u.data(forKey: "shieldSelection") else { return }
        SharedStore.update { j in
            j["sel"] = d.base64EncodedString()
            j["on"] = u.bool(forKey: "shieldOn")
            if let l = u.dictionary(forKey: "toggleLog") { j["log"] = l }
        }
    }
}
extension Notification.Name { static let calmShieldChanged = Notification.Name("calmShieldChanged") }

// ウィジェットのボタンが呼ぶ命令。止める仕組みはCalm本体でしか動かないので、本体を裏で起こして動かす（LiveActivityIntent）。
// 本体は裏で起きた時はインスタ等を読まないので、すぐ終わる
struct ToggleShieldIntent: SetValueIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Calmの止めるを切り替える"
    static var description = IntentDescription("本物のインスタ・TikTokを止める／戻す")
    @Parameter(title: "止める") var value: Bool
    init() {}
    init(_ v: Bool) { value = v }
    func perform() async throws -> some IntentResult {
        ShieldCore.set(value)
        return .result()
    }
}
