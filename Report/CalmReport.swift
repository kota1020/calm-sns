import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

// 携帯のスクリーンタイム（iOSが数えた本当の時間）を読む部品。
// iOSの決まりで、時間の数字はこの中でしか読めない。Calm本体はこの画面を埋め込んで見せるだけ。
@main
struct CalmReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TimeReport { TimeView(data: $0) }
        HomeReport { HomeView(data: $0) }
    }
}

extension DeviceActivityReport.Context {
    static let time = Self("time")
    static let home = Self("home")
}

// Calm自身の名前（入れた人ごとに違う。報告の部品の名前から「.report」を外した物）
let calmID = (Bundle.main.bundleIdentifier ?? "").replacingOccurrences(of: ".report", with: "")
// SNSとして数えるアプリ（Calm自身も入れる）
let SOCIAL: Set<String> = [
    calmID, "com.burbn.instagram", "com.zhiliaoapp.musically", "com.ss.iphone.ugc.Ame",
    "com.atebits.Tweetie2", "com.google.ios.youtube", "com.toyopagroup.picaboo", "com.burbn.barcelona",
    "com.facebook.Facebook", "com.reddit.Reddit", "AlexisBarreyat.BeReal",
]

struct AppRow: Identifiable { let id: String; let name: String; let token: ApplicationToken?; var sec: TimeInterval }
struct Day: Identifiable { let id: Int; let label: String; let date: String; let sec: TimeInterval; let today: Bool }
struct TimeData {
    var today: TimeInterval = 0     // 今日のSNSの合計
    var calm: TimeInterval = 0      // そのうちCalmの中
    var days: [Day] = []
    var apps: [AppRow] = []
    var byDay: [Int: [AppRow]] = [:]          // 何日前 → その日のアプリ別（0＝今日）
    var calmByDay: [Int: TimeInterval] = [:]  // 何日前 → その日のCalmの時間
}

// 7日分を日ごとに足す。今日の分はアプリごとにも分ける
func collect(_ data: DeviceActivityResults<DeviceActivityData>) async -> TimeData {
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: Date())
    var perDay: [Date: TimeInterval] = [:]
    var apps: [String: AppRow] = [:]
    var dayApps: [Int: [String: AppRow]] = [:]
    var out = TimeData()
    for await d in data {
        for await seg in d.activitySegments {
            let day = cal.startOfDay(for: seg.dateInterval.start)
            for await cat in seg.categories {
                for await a in cat.applications {
                    let id = a.application.bundleIdentifier ?? ""
                    guard SOCIAL.contains(id) else { continue }
                    let t = a.totalActivityDuration
                    perDay[day, default: 0] += t
                    let ago = cal.dateComponents([.day], from: day, to: todayStart).day ?? 0
                    let nm = a.application.localizedDisplayName ?? id
                    dayApps[ago, default: [:]][id, default: AppRow(id: id, name: nm, token: a.application.token, sec: 0)].sec += t
                    if id == calmID { out.calmByDay[ago, default: 0] += t }
                    if day == todayStart {
                        out.today += t
                        if id == calmID { out.calm += t }
                        let name = a.application.localizedDisplayName ?? id
                        apps[id, default: AppRow(id: id, name: name, token: a.application.token, sec: 0)].sec += t
                    }
                }
            }
        }
    }
    let wd = ["日", "月", "火", "水", "木", "金", "土"]
    // 35日ぶん（古い順）。グラフは左にずらすと前の日が見える
    out.days = (0..<35).reversed().map { i in
        let d = cal.date(byAdding: .day, value: -i, to: todayStart)!
        return Day(id: i, label: wd[cal.component(.weekday, from: d) - 1], date: "\(cal.component(.month, from: d))/\(cal.component(.day, from: d))", sec: perDay[d] ?? 0, today: i == 0)
    }
    out.apps = apps.values.filter { $0.sec >= 60 }.sorted { $0.sec > $1.sec }
    for (k, v) in dayApps { out.byDay[k] = v.values.filter { $0.sec >= 60 }.sorted { $0.sec > $1.sec } }
    return out
}

struct TimeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .time
    let content: (TimeData) -> TimeView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TimeData { await collect(data) }
}
struct HomeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .home
    let content: (TimeData) -> HomeView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TimeData { await collect(data) }
}

// ===== 見た目（Calm本体の C と同じ値） =====
enum C {
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let sub = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let card = Color(red: 0.955, green: 0.955, blue: 0.965)
    static let track = Color(red: 0.90, green: 0.90, blue: 0.91)
}
func dur(_ s: TimeInterval) -> String {
    let m = Int(s) / 60
    return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
}

// ホームの「今日のSNS 41m」
struct HomeView: View {
    let data: TimeData
    var body: some View {
        Text(dur(data.today)).font(.system(size: 40, weight: .bold)).kerning(-0.5).monospacedDigit()
            .foregroundColor(C.ink).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)   // 後ろの「読み込み中」の印を隠す
    }
}

// 時間のタブ：丸（Calmで見た割合）・この7日・今日のアプリ別
struct TimeView: View {
    let data: TimeData
    @State private var sel = 0   // 選んだ日（何日前）。棒を押すとその日の詳しい中身になる
    var body: some View {
        let day = data.days.first { $0.id == sel }
        let total = day?.sec ?? 0
        let calm = data.calmByDay[sel] ?? 0
        let apps = data.byDay[sel] ?? []
        let name = sel == 0 ? "今日" : "\(day?.date ?? "")（\(day?.label ?? "")）"
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                let share = total > 0 ? calm / total : 0
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(C.track, lineWidth: 9)
                        Circle().trim(from: 0, to: share).stroke(C.ink, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text("\(Int((share * 100).rounded()))%").font(.system(size: 19, weight: .semibold)).monospacedDigit()
                    }.frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(name)Calmで見た割合").font(.system(size: 17, weight: .semibold))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(dur(calm)).font(.system(size: 17, weight: .bold))
                            Text("Calmの中").font(.system(size: 14)).foregroundColor(C.sub)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill").font(.system(size: 13)).foregroundColor(C.sub)
                        Text("日ごと").font(.system(size: 16, weight: .medium))
                        Spacer()
                        Text("押すとその日の中身・← ずらすと前の日").font(.system(size: 11)).foregroundColor(C.sub)
                    }
                    let mx = max(600, data.days.map(\.sec).max() ?? 0)
                    ScrollViewReader { pr in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach(data.days) { d in
                                    let on = d.id == sel
                                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { sel = d.id } } label: {
                                        VStack(spacing: 5) {
                                            Text(d.sec >= 60 ? dur(d.sec) : "").font(.system(size: 10, weight: on ? .semibold : .regular)).foregroundColor(on ? C.ink : C.sub).lineLimit(1).minimumScaleFactor(0.7)
                                            RoundedRectangle(cornerRadius: 6).fill(on ? C.ink : C.ink.opacity(0.22))
                                                .frame(height: max(4, CGFloat(d.sec / mx) * 150))
                                            Text(d.label).font(.system(size: 12, weight: on ? .bold : .regular)).foregroundColor(on ? C.ink : C.sub)
                                            Text(d.date).font(.system(size: 9, weight: on ? .semibold : .regular)).foregroundColor(on ? C.ink : C.sub)
                                        }.frame(width: 40)
                                    }.buttonStyle(.plain).id(d.id)
                                }
                            }
                        }
                        .frame(height: 205, alignment: .bottom)
                        .onAppear { pr.scrollTo(0, anchor: .trailing) }   // 最初は今日（右端）を見せる
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass").font(.system(size: 13)).foregroundColor(C.sub)
                        Text("\(name)のSNS").font(.system(size: 16, weight: .medium))
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(dur(total)).font(.system(size: 40, weight: .bold)).monospacedDigit()
                        Text("合計").font(.system(size: 15)).foregroundColor(C.sub)
                    }
                    if apps.isEmpty {
                        Text("1分以上使ったSNSはありません").font(.system(size: 13)).foregroundColor(C.sub)
                    }
                    ForEach(apps) { a in
                        HStack(spacing: 12) {
                            if let t = a.token { Label(t).labelStyle(.iconOnly).scaleEffect(1.5).frame(width: 34, height: 34) }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(a.name).font(.system(size: 16))
                                    Spacer()
                                    Text(dur(a.sec)).font(.system(size: 14)).foregroundColor(C.sub).monospacedDigit()
                                }
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(C.track)
                                        Capsule().fill(C.ink).frame(width: max(6, g.size.width * CGFloat(a.sec / max(1, total))))
                                    }
                                }.frame(height: 6)
                            }
                        }
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(C.card))
            }
            .foregroundColor(C.ink)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .background(Color.white)
    }
}
