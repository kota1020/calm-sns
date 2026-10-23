import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== ホーム =====
struct HomeScreen: View {
    @EnvironmentObject var webs: WebStore
    @EnvironmentObject var shield: Shield
    @Binding var open: Service?
    @Binding var tab: Tab
    @State private var focus: Service? = .instagram
    @State private var settings: Service?
    @State private var account: Service?
    @AppStorage("hideLinkBar") private var hideLinkBar = false
    @State private var linkNote: String?
    var body: some View {
        let cur = APPS.first { $0.id == focus } ?? APPS[0]
        VStack(spacing: 0) {
            HStack {
                Text("Calm").font(.system(size: 28, weight: .heavy)).kerning(-0.8)
                Spacer()
                Button { tab = .stop } label: {
                    HStack(spacing: 5) {
                        Image(systemName: shield.on ? "lock.fill" : "lock.open").font(.system(size: 12, weight: .semibold))
                        Text(shield.on ? "止め中" : "止めていない").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 12).frame(height: 32).background(Capsule().fill(C.card))
                }.buttonStyle(Press())
            }
            .padding(.horizontal, C.pad).padding(.top, 6)

            if !hideLinkBar {
                HStack(spacing: 10) {
                    Image(systemName: "link").font(.system(size: 14, weight: .semibold)).foregroundColor(C.sub)
                    Button(action: openCopiedLink) {
                        Text(linkNote ?? "コピーしたリンクをCalmで開く").font(.system(size: 14)).foregroundColor(linkNote == nil ? C.ink : C.sub)
                            .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button { withAnimation(C.spring) { hideLinkBar = true } } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundColor(C.sub).frame(width: 28, height: 28)
                    }
                }
                .padding(.leading, 16).padding(.trailing, 8).frame(height: 48).card(24)
                .padding(.horizontal, C.pad).padding(.top, 14)
            }

            VStack(spacing: 2) {
                Text("今日のSNS").font(.system(size: 14)).foregroundColor(C.sub)
                if shield.approved {
                    ScreenTimeReport(context: .home).frame(height: 52)
                } else {
                    Text("—").font(.system(size: 40, weight: .bold)).frame(height: 52)
                }
                Button { tab = .time } label: {
                    HStack(spacing: 3) { Text("くわしく見る"); Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
                        .font(.system(size: 13)).foregroundColor(C.sub)
                }
            }
            .padding(.top, 26)

            // アプリのカルーセル：真ん中の1個を大きく、押すと全画面で開く
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(APPS) { a in
                        let on = focus == a.id
                        Button { if on { open = a.id } else { withAnimation(C.spring) { focus = a.id } } } label: {
                            AppIcon(s: a.id, size: 150).scaleEffect(on ? 1 : 0.72)
                        }
                        .buttonStyle(Press())
                        .accessibilityLabel(a.name)
                        .id(a.id)
                    }
                }
                .padding(.vertical, 20)   // 影が切れないように
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, (UIScreen.main.bounds.width - 150) / 2)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focus, anchor: .center)
            .frame(height: 200).padding(.top, 8)

            Button { account = cur.id } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle").font(.system(size: 13))
                    Text(loggedIn(cur.id) ? "アカウント" : "ログインする").font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(C.ink).padding(.horizontal, 12).frame(height: 30).background(Capsule().fill(C.card))
            }.padding(.top, 10)

            HStack(spacing: 6) {
                ForEach(APPS) { a in
                    Capsule().fill(focus == a.id ? C.ink : C.faint).frame(width: focus == a.id ? 16 : 6, height: 6)
                }
            }.padding(.top, 12)

            VStack(spacing: 12) {
                bigCard("\(cur.name)の設定", cur.id == .instagram ? "リールを止め中" : "おすすめを止め中", "slider.horizontal.3") { settings = cur.id }
                bigCard("広告・おすすめを消す", cur.id == .instagram ? "広告とおすすめの投稿を出さない" : "フォロー中だけを出す", "xmark") { settings = cur.id }
            }
            .padding(.horizontal, C.pad).padding(.top, 22)
            Spacer(minLength: 0)
        }
        .sheet(item: $settings) { s in AppSettingsSheet(service: s).presentationDetents([.medium, .large]) }
        .sheet(item: $account) { s in AccountSheet(service: s).presentationDetents([.medium, .large]) }
        .onAppear { webs.refreshLogin() }
    }
    private func loggedIn(_ s: Service) -> Bool { s == .instagram ? webs.igLoggedIn : webs.ttLoggedIn }
    private func openCopiedLink() {
        guard let t = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), let u = URL(string: t),
              let s = webs.open(u) else { note("インスタかTikTokのリンクをコピーしてから押してください"); return }
        open = s
    }
    private func note(_ t: String) {
        withAnimation { linkNote = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { linkNote = nil } }
    }
    private func bigCard(_ t: String, _ sub: String, _ art: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Image(systemName: art).font(.system(size: 92, weight: .bold)).foregroundColor(C.ink.opacity(0.06))
                    .frame(maxWidth: .infinity, alignment: .trailing).offset(x: 18, y: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t).font(.system(size: 18, weight: .semibold)).foregroundColor(C.ink)
                    Text(sub).font(.system(size: 13)).foregroundColor(C.sub)
                }.padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96).card().clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.buttonStyle(Press())
    }
}
