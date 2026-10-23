import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== 時間。数字は全部iOSのスクリーンタイムから =====
struct TimeScreen: View {
    @EnvironmentObject var shield: Shield
    var body: some View {
        VStack(spacing: 0) {
            Text("スクリーンタイム").title().padding(.horizontal, C.pad).padding(.top, 10).padding(.bottom, 12)
            ToggleCount().padding(.horizontal, C.pad).padding(.bottom, 14)
            if shield.approved {
                ScreenTimeReport(context: .time).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AskPermission()
                Spacer()
            }
        }
    }
}

// 「止める」をオフにした回数（ウィジェットとCalmの中のスイッチ、どちらで押しても数える）
struct ToggleCount: View {
    @EnvironmentObject var shield: Shield
    var body: some View {
        let days = ShieldCore.offCounts(days: 7)   // 古い順。最後が今日
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日オフにした").font(.system(size: 12)).foregroundColor(C.sub)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(days.last?.n ?? 0)").font(.system(size: 30, weight: .bold)).monospacedDigit()
                    Text("回").font(.system(size: 13)).foregroundColor(C.sub)
                }
            }
            Spacer(minLength: 0)
            // この7日のオフにした回数（小さい棒）
            let mx = max(1, days.map(\.n).max() ?? 1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 3) {
                        Text(d.n > 0 ? "\(d.n)" : "").font(.system(size: 9)).foregroundColor(C.sub)
                        RoundedRectangle(cornerRadius: 3).fill(i == days.count - 1 ? C.ink : C.ink.opacity(0.22))
                            .frame(width: 14, height: max(3, CGFloat(d.n) / CGFloat(mx) * 34))
                        Text(d.label).font(.system(size: 9)).foregroundColor(i == days.count - 1 ? C.ink : C.sub)
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12).card(20)
        .id(shield.on)   // 切り替えたら数え直す
    }
}

struct AskPermission: View {
    @EnvironmentObject var shield: Shield
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("スクリーンタイムの使用を許可してください").font(.system(size: 17, weight: .semibold))
            Text("時間の数字と、本物のアプリを止めるのに使います").font(.system(size: 14)).foregroundColor(C.sub)
            BlackButton(title: "許可する") { Task { await shield.authorize() } }
        }.padding(20).card().padding(.horizontal, C.pad)
    }
}

struct BlackButton: View {
    let title: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52).background(Capsule().fill(C.ink))
        }.buttonStyle(Press())
    }
}
