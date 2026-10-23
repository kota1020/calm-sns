import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== 見た目の決まり：白地・黒文字・薄い灰色のカード =====
enum C {
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let sub = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let faint = Color(red: 0.78, green: 0.78, blue: 0.80)
    static let card = Color(red: 0.955, green: 0.955, blue: 0.965)
    static let sheet = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let on = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let pad: CGFloat = 20
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
}
struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).animation(C.spring, value: configuration.isPressed)
    }
}
extension View {
    func card(_ r: CGFloat = 24) -> some View { background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(C.card)) }
    func title() -> some View { font(.system(size: 30, weight: .bold)).kerning(-0.5).frame(maxWidth: .infinity, alignment: .leading) }
}
extension DeviceActivityReport.Context {
    static let time = Self("time")
    static let home = Self("home")
}
// 今日を含む35日（スクリーンタイムを読む範囲。グラフを左にずらすと前の日が見える）。
// 終わりを「今」にすると画面を描くたびに範囲が変わって読み直しになり、真っ白のままになる。なので終わりは明日の0時に固定する
func weekFilter() -> DeviceActivityFilter {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let start = cal.date(byAdding: .day, value: -34, to: today)!
    let end = cal.date(byAdding: .day, value: 1, to: today)!
    return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)), users: .all, devices: .init([.iPhone]))
}

// スクリーンタイムの画面を埋め込む。読み込み中は白にせず「読み込み中」を出す
struct ScreenTimeReport: View {
    let context: DeviceActivityReport.Context
    @State private var filter = weekFilter()
    var body: some View {
        ZStack {
            ProgressView().tint(C.sub)
            DeviceActivityReport(context, filter: filter)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            let f = weekFilter()
            if f != filter { filter = f }   // 日付が変わった時だけ読み直す
        }
    }
}

// ===== アプリのアイコン（本物に近い色） =====
struct AppItem: Identifiable { let id: Service; let name: String }
let APPS = [AppItem(id: .instagram, name: "Instagram"), AppItem(id: .tiktok, name: "TikTok")]

struct AppIcon: View {
    let s: Service; var size: CGFloat = 150
    var body: some View {
        // App Storeの公式アイコン（Resources/icon_ig.png・icon_tt.png）を、iOSのアイコンと同じ角の丸みで切る
        Image(uiImage: UIImage(named: s == .instagram ? "icon_ig.png" : "icon_tt.png") ?? UIImage())
            .resizable().interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: size * 0.06, y: size * 0.03)
    }
}
