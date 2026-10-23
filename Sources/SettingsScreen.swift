import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== アカウント（ホームの「アカウント」から） =====
struct AccountSheet: View {
    let service: Service
    @EnvironmentObject var webs: WebStore
    @Environment(\.dismiss) private var dismiss
    @State private var user = ""
    @State private var pass = ""
    var body: some View {
        let on = service == .instagram ? webs.igLoggedIn : webs.ttLoggedIn
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("完了") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundColor(C.ink)
                    .padding(.horizontal, 14).frame(height: 34).background(Capsule().fill(Color.white))
            }
            AppIcon(s: service, size: 76)
            VStack(spacing: 4) {
                Text(service == .instagram ? "Instagram" : "TikTok").font(.system(size: 22, weight: .bold))
                HStack(spacing: 5) {
                    Circle().fill(on ? C.on : C.faint).frame(width: 8, height: 8)
                    Text(on ? "ログイン中" : "ログインしていません").font(.system(size: 14)).foregroundColor(C.sub)
                }
            }
            if on {
                VStack(spacing: 0) {
                    row("別のアカウントに入る", "arrow.left.arrow.right") { webs.logout(service); dismiss() }
                    Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5).padding(.leading, 52)
                    row("ログアウト", "rectangle.portrait.and.arrow.right", red: true) { webs.logout(service) }
                }.background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                Text("ログアウトすると、次に開いた時にログイン画面が出ます").font(.system(size: 12)).foregroundColor(C.sub)
            } else if service == .instagram {
                VStack(spacing: 10) {
                    TextField("ユーザー名", text: $user).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textContentType(.username).padding(13).background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                    SecureField("パスワード", text: $pass).textContentType(.password)
                        .padding(13).background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                    BlackButton(title: "ログイン") { webs.loginInstagram(user: user, pass: pass); pass = "" }
                    if let n = webs.loginNote { Text(n).font(.system(size: 12)).foregroundColor(C.sub) }
                }
            } else {
                Text("TikTokを開いて、画面の「Log in」から入ってください（Googleでも入れます）").font(.system(size: 13)).foregroundColor(C.sub).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, C.pad).padding(.top, 16)
        .foregroundColor(C.ink)
        .presentationBackground(C.sheet)
        .presentationCornerRadius(28)
        .onAppear { webs.refreshLogin() }
    }
    private func row(_ t: String, _ icon: String, red: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 16)).frame(width: 24)
                Text(t).font(.system(size: 16))
                Spacer()
            }.foregroundColor(red ? .red : C.ink).padding(.horizontal, 16).frame(height: 52)
        }
    }
}

// ===== 設定（ログイン） =====
struct SettingsScreen: View {
    @EnvironmentObject var webs: WebStore
    @State private var igUser = ""
    @State private var igPass = ""
    @State private var edit: Service?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("設定").title().padding(.top, 10).padding(.bottom, 6)
                Text("アカウント").font(.system(size: 15, weight: .semibold)).foregroundColor(C.sub).padding(.leading, 4)
                VStack(spacing: 0) {
                    acct(.instagram, "Instagram", webs.igLoggedIn)
                    Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5).padding(.leading, 64)
                    acct(.tiktok, "TikTok", webs.ttLoggedIn)
                }.card(18)
                if !webs.igLoggedIn {
                    // インスタはここからも入れる（ホームでインスタを開いてウェブのログイン画面から入ってもよい）
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Instagramにログイン").font(.system(size: 16, weight: .semibold))
                        TextField("ユーザー名", text: $igUser).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textContentType(.username).padding(13).background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .accessibilityIdentifier("calm-ig-user")
                        SecureField("パスワード", text: $igPass).textContentType(.password)
                            .padding(13).background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .accessibilityIdentifier("calm-ig-pass")
                            .submitLabel(.go).onSubmit(login)
                        BlackButton(title: "ログイン", action: login).accessibilityIdentifier("calm-ig-login")
                        if let n = webs.loginNote { Text(n).font(.system(size: 12)).foregroundColor(C.sub) }
                    }.padding(18).card().padding(.top, 12)
                }
                Text("ログインの情報はこの携帯の中だけに残ります").font(.system(size: 12)).foregroundColor(C.sub).padding(.top, 6).padding(.leading, 4)

                Text("ウィジェット").font(.system(size: 15, weight: .semibold)).foregroundColor(C.sub).padding(.leading, 4).padding(.top, 18)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield").font(.system(size: 20)).frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 9).fill(Color.white))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("「止める」のボタン").font(.system(size: 16))
                        Text("ホーム画面かロック画面を長押し →「編集」→「ウィジェットを追加」→ Calm。押すとアプリを開かずに切り替わります").font(.system(size: 12)).foregroundColor(C.sub)
                    }
                    Spacer(minLength: 0)
                }.padding(14).card(18)

                Text("このアプリ").font(.system(size: 15, weight: .semibold)).foregroundColor(C.sub).padding(.leading, 4).padding(.top, 18)
                VStack(spacing: 0) {
                    info("見られる物", "フォロー中・ストーリー・DM・自分のページ")
                    Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5).padding(.leading, 14)
                    info("消している物", "リール・発見・おすすめ・広告")
                    Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5).padding(.leading, 14)
                    info("時間の数字", "iPhoneのスクリーンタイム")
                }.card(18)
            }
            .padding(.horizontal, C.pad)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $edit) { s in AppSettingsSheet(service: s).presentationDetents([.medium, .large]) }
        .onAppear { webs.refreshLogin() }
    }
    private func login() { webs.loginInstagram(user: igUser, pass: igPass); igPass = "" }
    private func info(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).font(.system(size: 15))
            Spacer()
            Text(v).font(.system(size: 13)).foregroundColor(C.sub).multilineTextAlignment(.trailing)
        }.padding(.horizontal, 14).frame(minHeight: 50)
    }
    private func acct(_ s: Service, _ n: String, _ on: Bool) -> some View {
        Button { edit = s } label: {
            HStack(spacing: 12) {
                AppIcon(s: s, size: 36)
                Text(n).font(.system(size: 16)).foregroundColor(C.ink)
                Spacer()
                Text(on ? "ログイン中" : "未ログイン").font(.system(size: 14)).foregroundColor(C.sub)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(C.faint)
            }.padding(.horizontal, 14).frame(height: 60)
        }
    }
}
