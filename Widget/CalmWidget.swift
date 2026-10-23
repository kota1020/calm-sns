import WidgetKit
import SwiftUI
import AppIntents

// ホーム画面・ロック画面の「止める」ボタンだけのウィジェット。押すとその場で切り替わる（アプリは開かない）
@main
struct CalmWidgets: WidgetBundle {
    var body: some Widget { StopWidget() }
}

struct StopEntry: TimelineEntry { let date: Date; let on: Bool }

struct StopProvider: TimelineProvider {
    func placeholder(in context: Context) -> StopEntry { StopEntry(date: Date(), on: true) }
    func getSnapshot(in context: Context, completion: @escaping (StopEntry) -> Void) { completion(StopEntry(date: Date(), on: ShieldCore.blockedNow)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StopEntry>) -> Void) {
        completion(Timeline(entries: [StopEntry(date: Date(), on: ShieldCore.blockedNow)], policy: .never))
    }
}

struct StopWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "calm-stop", provider: StopProvider()) { e in StopView(e: e) }
            .configurationDisplayName("止める")
            .description("本物のインスタ・TikTokを止める／戻す")
            .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct StopView: View {
    let e: StopEntry
    @Environment(\.widgetFamily) private var fam
    var body: some View {
        // Toggle にすると、押した瞬間に見た目が切り替わる（裏でCalmが止める処理をする間も待たせない）
        Toggle(isOn: e.on, intent: ToggleShieldIntent()) { EmptyView() }
            .toggleStyle(StopStyle(fam: fam))
            .containerBackground(for: .widget) { Color.clear }
    }
}

struct StopStyle: ToggleStyle {
    let fam: WidgetFamily
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: { StopFace(on: configuration.isOn, fam: fam) }
            .buttonStyle(.plain)
    }
}

struct StopFace: View {
    let on: Bool
    let fam: WidgetFamily
    var body: some View {
        let icon = on ? "lock.fill" : "lock.open"
        let word = on ? "止め中" : "オフ"
        switch fam {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                    Text(word).font(.system(size: 10, weight: .semibold))
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Calm").font(.system(size: 11)).opacity(0.7)
                    Text(word).font(.system(size: 17, weight: .bold))
                }
                Spacer(minLength: 0)
            }
        default:
            // ホーム画面：ジム・残り日数と同じ白黒の形。上に名前、真ん中に大きい丸ボタン、下に状態
            VStack(alignment: .leading, spacing: 0) {
                Text("Calm").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(on ? Color.white : Color.white.opacity(0.18))
                        Image(systemName: icon).font(.system(size: 30, weight: .semibold)).foregroundStyle(on ? Color.black : Color.white)
                    }.frame(width: 70, height: 70)
                    Spacer()
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline) {
                    Text(word).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text("押して切替").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}
