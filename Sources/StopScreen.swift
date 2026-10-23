import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== 止める =====
struct StopScreen: View {
    @EnvironmentObject var shield: Shield
    @State private var picking = false
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("止めるアプリ").title().padding(.top, 10)
                if !shield.approved {
                    AskPermission().padding(.horizontal, -C.pad).padding(.top, 6)
                } else {
                    Orbit(tokens: Array(shield.selection.applicationTokens), on: shield.on) { picking = true }
                        .frame(height: 330)
                    HStack(spacing: 6) {
                        Image(systemName: shield.on ? "checkmark.shield.fill" : "exclamationmark.shield").foregroundColor(shield.on ? C.on : C.sub)
                        Text(shield.on ? "\(shield.count)個を止め中" : "止めていない").font(.system(size: 16, weight: .semibold))
                    }
                    Text(shield.on ? "本物のアプリは開けません。Calmから開いてください" : "下のスイッチで止めます").font(.system(size: 13)).foregroundColor(C.sub)
                        .padding(.bottom, 14)
                    HStack(spacing: 12) {
                        Button { picking = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "slider.horizontal.3").font(.system(size: 16))
                                Text("アプリを選ぶ").font(.system(size: 15, weight: .medium))
                            }.foregroundColor(C.ink).frame(maxWidth: .infinity).frame(height: 60).card(20)
                        }.buttonStyle(Press())
                        HStack(spacing: 8) {
                            Text("止める").font(.system(size: 15, weight: .medium))
                            Toggle("", isOn: Binding(get: { shield.on }, set: { shield.on = $0; shield.apply(); ShieldCore.record($0) })).labelsHidden().tint(C.on)
                        }.frame(maxWidth: .infinity).frame(height: 60).card(20)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle").font(.system(size: 18)).foregroundColor(C.sub)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("止めるとどうなる？").font(.system(size: 15, weight: .semibold))
                            Text("本物のインスタ・TikTokはリールとおすすめが出るので開けなくします。Calmの中ならフォロー中だけ見られます").font(.system(size: 13)).foregroundColor(C.sub)
                        }
                        Spacer(minLength: 0)
                    }.padding(16).card(20)
                }
                if let e = shield.error { Text(e).font(.system(size: 12)).foregroundColor(.red) }
            }
            .padding(.horizontal, C.pad).padding(.bottom, 20)
        }
        .familyActivityPicker(isPresented: $picking, selection: $shield.selection)
        .onChange(of: shield.selection) { _, _ in shield.apply() }
    }
}

// 真ん中にCalm、周りに止めたアプリのアイコン。線でつなぐ
struct Orbit: View {
    let tokens: [ApplicationToken]
    let on: Bool
    let add: () -> Void
    var body: some View {
        GeometryReader { g in
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let r = min(g.size.width, g.size.height) / 2 - 40
            let n = max(tokens.count + 1, 6)
            let pts = (0..<n).map { i -> CGPoint in
                let a = -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(n)
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
            ZStack {
                Path { p in for q in pts.prefix(tokens.count + 1) { p.move(to: c); p.addLine(to: q) } }
                    .stroke(C.faint.opacity(0.7), lineWidth: 1)
                ForEach(Array(tokens.enumerated()), id: \.offset) { i, t in
                    Label(t).labelStyle(.iconOnly).scaleEffect(2.4)
                        .frame(width: 60, height: 60)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                        .opacity(on ? 1 : 0.45)
                        .position(pts[i])
                }
                Button(action: add) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundColor(C.sub)
                        .frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(C.faint, style: StrokeStyle(lineWidth: 1.5, dash: [5])))
                }.position(pts[tokens.count])
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage(named: "icon_calm.png") ?? UIImage())
                    .resizable().frame(width: 84, height: 84)
                    .background(RoundedRectangle(cornerRadius: 19, style: .continuous).fill(C.ink))
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
                    .position(c)
            }
        }
    }
}
