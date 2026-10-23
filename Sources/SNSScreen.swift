import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== SNSの画面：本物そのまま＋上に細い帯1本 =====
struct SNSScreen: View {
    let service: Service
    @EnvironmentObject var webs: WebStore
    @EnvironmentObject var usage: Usage
    @Environment(\.dismiss) private var dismiss
    @State private var settings = false
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer").font(.system(size: 12, weight: .medium))
                    Text("\(session) · 広告\(webs.ads) · おすすめ\(webs.suggested)").font(.system(size: 13, weight: .medium)).monospacedDigit()
                }.foregroundColor(C.sub)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundColor(C.ink).frame(width: 34, height: 34)
                    }.accessibilityLabel("ホームへ")
                    Spacer()
                    Menu {
                        if service == .tiktok {
                            Button { webs.tiktokFollowing() } label: { Label("フォロー中", systemImage: "person.2") }
                            Button { webs.tiktokMine() } label: { Label("自分のいいね・保存", systemImage: "heart") }
                        }
                        if service == .instagram {
                            Button { webs.instagram.load(URLRequest(url: URL(string: "https://www.instagram.com/")!)) } label: { Label("ホーム", systemImage: "house") }
                            Button { webs.instagram.load(URLRequest(url: URL(string: "https://www.instagram.com/?variant=following")!)) } label: { Label("フォロー中（新しい順）", systemImage: "person.2") }
                        }
                        Button { settings = true } label: { Label("\(service == .instagram ? "Instagram" : "TikTok")の設定", systemImage: "slider.horizontal.3") }
                        Button { (service == .instagram ? webs.instagram : webs.ttMine ? webs.tiktokMe : webs.tiktok).reload() } label: { Label("読み直す", systemImage: "arrow.clockwise") }
                        Button { dismiss() } label: { Label("ホームへ", systemImage: "house") }
                    } label: {
                        Image(systemName: "line.3.horizontal").font(.system(size: 15, weight: .semibold)).foregroundColor(C.ink)
                            .frame(width: 34, height: 34).background(Circle().fill(Color.white)).shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    }.accessibilityLabel("メニュー")
                }.padding(.horizontal, 10)
            }
            .frame(height: 40)
            Group {
                if service == .instagram {
                    WebView(view: webs.instagram).ignoresSafeArea(.container, edges: .bottom)
                } else {
                    // フォロー中と自分のページを重ねて持ち、見せる方だけ前に出す（切り替えで読み直さない）
                    ZStack {
                        WebView(view: webs.tiktokMe).opacity(webs.ttMine ? 1 : 0).allowsHitTesting(webs.ttMine)
                        WebView(view: webs.tiktok).opacity(webs.ttMine ? 0 : 1).allowsHitTesting(!webs.ttMine)
                    }
                }
            }
            if service == .tiktok { TikTokBar() }
        }
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $settings) { AppSettingsSheet(service: service).presentationDetents([.medium, .large]) }
        .onReceive(tick) { now = $0 }
        .onAppear { if service == .tiktok { webs.preloadMe() } }
    }
    private var session: String {
        let s = Int(now.timeIntervalSince(usage.sessionStart ?? now))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// TikTokの下のボタン（本物のTikTokと同じ位置）。ウェブ版には自分のページへのボタンが無いので足す
struct TikTokBar: View {
    @EnvironmentObject var webs: WebStore
    var body: some View {
        HStack {
            item("ホーム", webs.ttMine ? "house" : "house.fill", !webs.ttMine) { webs.tiktokFollowing() }
            item("プロフィール", webs.ttMine ? "person.fill" : "person", webs.ttMine) { webs.tiktokMine() }
        }
        .frame(height: 50)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
    }
    private func item(_ t: String, _ icon: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(t).font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(on ? .white : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(t)
    }
}

// ===== アプリごとの設定シート =====
struct AppSettingsSheet: View {
    let service: Service
    @EnvironmentObject var webs: WebStore
    @Environment(\.dismiss) private var dismiss
    @State private var cfg = Cfg.all
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(service == .instagram ? "Instagram" : "TikTok").font(.system(size: 17, weight: .semibold))
                HStack {
                    Spacer()
                    Button("完了") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundColor(C.ink)
                        .padding(.horizontal, 14).frame(height: 34).background(Capsule().fill(Color.white))
                }
            }.padding(.horizontal, C.pad).padding(.top, 18).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    header("止める")
                    group {
                        if service == .instagram {
                            locked("リールを止める")
                            divider()
                            toggle("検索を止める", "search")
                        } else {
                            locked("おすすめを止める")
                            divider()
                            toggle("検索を止める", "search")
                            divider()
                            toggle("ライブを止める", "live")
                        }
                    }
                    if service == .instagram {
                        header("消す")
                        group {
                            toggle("広告を消す", "ads")
                            divider()
                            toggle("おすすめの投稿を消す", "suggested")
                        }
                    }
                    header("アカウント")
                    group {
                        let on = service == .instagram ? webs.igLoggedIn : webs.ttLoggedIn
                        HStack {
                            Text(on ? "ログイン中" : "未ログイン").font(.system(size: 16))
                            Spacer()
                            if on { Button("ログアウト") { webs.logout(service) }.font(.system(size: 15)).foregroundColor(.red) }
                        }.padding(.horizontal, 16).frame(height: 50)
                    }
                }.padding(.horizontal, C.pad).padding(.bottom, 20)
            }
        }
        .foregroundColor(C.ink)
        .presentationBackground(C.sheet)
        .presentationCornerRadius(28)
        .onAppear { webs.refreshLogin() }
    }
    private func header(_ t: String) -> some View {
        Text(t).font(.system(size: 15, weight: .semibold)).foregroundColor(C.sub).padding(.leading, 4).padding(.top, 14)
    }
    private func group<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        VStack(spacing: 0, content: v).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
    }
    private func divider() -> some View { Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5).padding(.leading, 16) }
    private func locked(_ t: String) -> some View {
        HStack {
            Text(t).font(.system(size: 16))
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(C.sub)
            Toggle("", isOn: .constant(true)).labelsHidden().tint(C.on).allowsHitTesting(false)
        }.padding(.horizontal, 16).frame(height: 50)
    }
    private func toggle(_ t: String, _ k: String) -> some View {
        HStack {
            Text(t).font(.system(size: 16))
            Spacer()
            Toggle("", isOn: Binding(get: { cfg[k] ?? true }, set: { cfg[k] = $0; Cfg.set(k, $0); webs.applyCfg(service) }))
                .labelsHidden().tint(C.on)
        }.padding(.horizontal, 16).frame(height: 50)
    }
}
