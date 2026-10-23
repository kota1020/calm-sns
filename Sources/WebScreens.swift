import SwiftUI
import WebKit

enum Service: String { case instagram, tiktok }

// ウェブ版を開く画面は1つずつ作って持ち続ける（タブを切り替えても読み直さない）
// http(s) 以外（instagram:// snssdk:// itms-apps:// など）へ移ろうとしたら止める＝本物のアプリやApp Storeに飛ばさない
final class StayInside: NSObject, WKNavigationDelegate, WKUIDelegate {
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = a.request.url?.scheme?.lowercased() ?? "https"
        let host = a.request.url?.host?.lowercased() ?? ""
        if !["http", "https", "about", "blob", "data"].contains(scheme) || host.hasSuffix("apps.apple.com") { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    // TikTokの自分のページの住所（/@名前）を覚える。次からは回り道（/profile → /@名前）をせず直接開く
    // 覚えるのは「自分のページ」の画面だけ（保存用の裏の画面が開いた他人の動画の住所を覚えると、次から「見つからない」になる）
    weak var meView: WKWebView?
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        guard w === meView, let u = w.url, u.host?.hasSuffix("tiktok.com") == true else { return }
        let parts = u.pathComponents.dropFirst()
        guard parts.count == 1, let first = parts.first, first.hasPrefix("@"), first.count > 2 else { return }
        UserDefaults.standard.set("https://www.tiktok.com/" + first, forKey: "ttMeURL")
    }
    // 新しい窓（Googleでログインなど）は、元の画面の上に重ねて開く。ログインが終わってサイトが窓を閉じたら外す
    // 同じ画面で開くと、ログイン後に元の画面へ結果が戻らず真っ白になる
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
        let pop = WKWebView(frame: w.bounds, configuration: c)
        pop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pop.customUserAgent = w.customUserAgent
        pop.navigationDelegate = self
        pop.uiDelegate = self
        w.addSubview(pop)
        return pop
    }
    func webViewDidClose(_ w: WKWebView) {
        w.removeFromSuperview()   // 元の画面はサイトが自分で進める（読み直すとログインの結果が消える）
    }
}

@MainActor final class WebStore: ObservableObject {
    static let guardian = StayInside()
    // iPhoneのSafariと同じ名乗り。アプリ内ブラウザだと分かると「アプリで開いて」と出るため
    static let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
    // パソコンのSafariの名乗り。TikTokの携帯版には自分のいいね・保存の画面が無いので、そこだけこれで開く
    static let macUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"
    static let script: String = {
        guard let url = Bundle.main.url(forResource: "calm", withExtension: "js"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s
    }()
    // 画面は使う時に初めて作る（ウィジェットから裏で起こされた時に、作るだけで数秒かかるのを避ける）
    lazy var instagram: WKWebView = Self.make(nil, counter)
    lazy var tiktok: WKWebView = Self.make(nil, counter)
    // TikTokの自分のページ（パソコン版）。フォロー中とは別の画面にして持ち続ける＝切り替えても読み直さない
    lazy var tiktokMe: WKWebView = { let w = Self.make(nil, counter, ua: Self.macUA); Self.guardian.meView = w; return w }()
    // この回で消した広告・おすすめの数（上の帯に出す）
    @Published var ads = 0
    @Published var suggested = 0
    private let counter: Counter
    @Published var igLoggedIn = false
    @Published var ttLoggedIn = false
    @Published var loginNote: String?

    // ログインしているか＝サイトの「sessionid」クッキーがあるか
    func refreshLogin() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let ig = cookies.contains { $0.domain.contains("instagram.com") && $0.name == "sessionid" && !$0.value.isEmpty }
            let tt = cookies.contains { $0.domain.contains("tiktok.com") && $0.name == "sessionid" && !$0.value.isEmpty }
            Task { @MainActor in self.igLoggedIn = ig; self.ttLoggedIn = tt }
        }
    }

    // インスタのログイン：ログイン画面を開き、欄が出たら名前とパスワードを入れて送る。パスワードはどこにも保存しない
    func loginInstagram(user: String, pass: String) {
        loginNote = "ログイン中…"
        instagram.load(URLRequest(url: URL(string: "https://www.instagram.com/accounts/login/")!))
        let js = """
        (function(u, p) {
          const f = document.querySelector('input[name="username"], input[name="email"]');
          const g = document.querySelector('input[name="password"], input[name="pass"]');
          if (!f || !g) return 'wait';
          const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
          set.call(f, u); f.dispatchEvent(new Event('input', { bubbles: true }));
          set.call(g, p); g.dispatchEvent(new Event('input', { bubbles: true }));
          const b = document.querySelector('button[type="submit"]') || [...document.querySelectorAll('button, div[role=button]')].find(x => /^(Log in|ログイン)$/.test(x.textContent.trim()));
          if (!b) return 'nobutton';
          setTimeout(() => b.click(), 300);
          return 'sent';
        })(%@, %@)
        """
        func q(_ s: String) -> String { let d = try! JSONSerialization.data(withJSONObject: [s]); return String(String(data: d, encoding: .utf8)!.dropFirst().dropLast()) }
        let code = js.replacingOccurrences(of: "%@", with: "\u{1}").components(separatedBy: "\u{1}")
        let filled = code[0] + q(user) + code[1] + q(pass) + code[2]
        var tries = 0
        func attempt() {
            tries += 1
            instagram.evaluateJavaScript(filled) { r, _ in
                Task { @MainActor in
                    if (r as? String) == "sent" {
                        self.loginNote = "送った。確かめ中…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                            self.refreshLogin()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                self.loginNote = self.igLoggedIn ? "ログインできた" : "まだ。画面で確認が出ていないか見てください"
                                if self.igLoggedIn { self.instagram.load(URLRequest(url: URL(string: "https://www.instagram.com/?variant=following")!)) }
                            }
                        }
                    } else if tries < 20 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { attempt() }
                    } else { self.loginNote = "ログイン画面の欄が見つからなかった" }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { attempt() }
    }

    func logout(_ s: Service) {
        let host = s == .instagram ? "instagram.com" : "tiktok.com"
        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { recs in
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: recs.filter { $0.displayName.contains(host) }) {
                Task { @MainActor in
                    self.refreshLogin()
                    (s == .instagram ? self.instagram : self.tiktok).reload()
                }
            }
        }
    }
    init() {
        let c = Counter()
        counter = c
        // 前の版が間違って覚えた住所（@_ など）は捨てる
        if let u = UserDefaults.standard.string(forKey: "ttMeURL"), u.hasSuffix("/@_") || u.contains("/video/") { UserDefaults.standard.removeObject(forKey: "ttMeURL") }
        counter.got = { [weak self] a, s in self?.ads = a; self?.suggested = s }
        counter.save = { [weak self] id, user in self?.saveTikTok(id: id, user: user) }
    }
    // 画面が出た時に1回だけ読み込みを始める
    func warmUp() {
        guard instagram.url == nil else { return }
        instagram.load(URLRequest(url: URL(string: "https://www.instagram.com/")!))
        tiktok.load(URLRequest(url: URL(string: "https://www.tiktok.com/following")!))
        refreshLogin()
    }
    // 自分のページは、TikTokを開いてフォロー中が出た後に裏で読んでおく（起動時に3つ同時に読むと全部遅くなる）
    func preloadMe() { DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.loadMe() } }
    private func loadMe() {
        guard tiktokMe.url == nil else { return }
        // いつも /profile を開く（TikTokが自分のページへ送ってくれる）。覚えた住所を使うと、間違えた時に「見つからない」になる
        let u = "https://www.tiktok.com/profile"
        tiktokMe.load(URLRequest(url: URL(string: u)!))
    }
    // TikTokの自分のページ（いいね・保存のタブがある）とフォロー中を切り替える。画面を入れ替えるだけで読み直さない
    @Published var ttMine = false
    func tiktokMine() { loadMe(); pause(tiktok); ttMine = true }
    func tiktokFollowing() { pause(tiktokMe); ttMine = false }
    // 見えていない画面の動画は止める（裏で音が鳴ったり回線を使ったりしないように）
    func pause(_ w: WKWebView) { w.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())") }
    func pauseAll() { [instagram, tiktok, tiktokMe].forEach(pause) }
    // ===== TikTokの保存 =====
    // 携帯版には保存ボタンが無い。見えない所にパソコン版の画面を1枚置き、その動画を開いて本物の保存ボタンを押す
    private lazy var saver: WKWebView = {
        let w = Self.make(nil, counter, ua: Self.macUA)
        w.configuration.userContentController.addUserScript(WKUserScript(source: "setInterval(() => document.querySelectorAll('video').forEach(v => { v.muted = true; v.pause(); }), 300);", injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        w.frame = CGRect(x: 0, y: 0, width: 1280, height: 900)
        w.isHidden = true
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.addSubview(w)
        return w
    }()
    func saveTikTok(id: String, user: String) {
        let u = "https://www.tiktok.com/@\(user.isEmpty ? "_" : user)/video/\(id)"
        saver.load(URLRequest(url: URL(string: u)!))
        // 保存ボタン：data-e2e か aria-label に favorite / collect / bookmark が入る物。もう押してあれば押さない
        let js = """
        (function(){
          const b = [...document.querySelectorAll('[data-e2e*="favorite" i], [data-e2e*="collect" i], [aria-label*="favorite" i], [aria-label*="collect" i], [aria-label*="お気に入り"]')]
            .map(e => e.closest('button,[role=button]') || e).find(e => e.getBoundingClientRect().width > 0);
          if (!b) return 'wait';
          if (b.getAttribute('aria-pressed') === 'true') return 'already';
          b.click(); return 'clicked';
        })()
        """
        var tries = 0
        func attempt() {
            tries += 1
            saver.evaluateJavaScript(js) { [weak self] r, _ in
                guard let self else { return }
                let res = r as? String ?? "wait"
                if res == "clicked" || res == "already" { self.markSaved(id, true) }
                else if tries < 25 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { attempt() } }
                else {
                    self.markSaved(id, false)
                    // 押せなかった時は、画面にあったボタンの名前を残す（直す時の手がかり）
                    self.saver.evaluateJavaScript("location.href + '\\n' + [...document.querySelectorAll('button,[role=button],[data-e2e]')].map(b => (b.getAttribute('aria-label')||'') + '|' + (b.getAttribute('data-e2e')||'')).filter(x => x !== '|').slice(0,120).join('\\n')") { r, _ in
                        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("save-fail.txt")
                        try? (r as? String ?? "").write(to: u, atomically: true, encoding: .utf8)
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { attempt() }
    }
    private func markSaved(_ id: String, _ ok: Bool) {
        tiktok.evaluateJavaScript("window.__calmSaved && window.__calmSaved('\(id)', \(ok))")
        if ok { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.saver.load(URLRequest(url: URL(string: "about:blank")!)) } }
    }

    // 回の始まりに数を0に戻す
    func resetCounts() { ads = 0; suggested = 0 }

    // 設定（Cfg）を変えたら、決まりを入れ直して読み直す
    func applyCfg(_ s: Service) {
        for w in s == .instagram ? [instagram] : [tiktok, tiktokMe] {
            Self.install(w.configuration.userContentController)
            if w.url != nil { w.reload() }
        }
    }
    // リンクを開く（インスタかTikTokのリンクだけ）
    func open(_ u: URL) -> Service? {
        let h = u.host?.lowercased() ?? ""
        let s: Service? = h.hasSuffix("instagram.com") ? .instagram : h.hasSuffix("tiktok.com") ? .tiktok : nil
        if let s { (s == .instagram ? instagram : tiktok).load(URLRequest(url: u)) }
        return s
    }
    private static func install(_ uc: WKUserContentController) {
        uc.removeAllUserScripts()
        let cfg = try! JSONSerialization.data(withJSONObject: Cfg.all)
        uc.addUserScript(WKUserScript(source: "window.__calmCfg=\(String(data: cfg, encoding: .utf8)!);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        uc.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }
    private static func make(_ start: URL?, _ counter: Counter, ua: String = safariUA) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()          // ログインを覚えておく
        cfg.allowsInlineMediaPlayback = true          // 動画は画面の中で再生（勝手に全画面にしない）
        cfg.preferences.isElementFullscreenEnabled = false
        cfg.allowsPictureInPictureMediaPlayback = false
        cfg.mediaTypesRequiringUserActionForPlayback = []
        install(cfg.userContentController)
        cfg.userContentController.add(counter, name: "calm")
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.customUserAgent = ua
        w.navigationDelegate = guardian
        w.uiDelegate = guardian
        w.allowsBackForwardNavigationGestures = true
        w.backgroundColor = .white
        w.scrollView.backgroundColor = .white
        let rc = UIRefreshControl()
        rc.addAction(UIAction { [weak w] _ in w?.reload(); rc.endRefreshing() }, for: .valueChanged)
        w.scrollView.refreshControl = rc
        if let start { w.load(URLRequest(url: start)) }
        return w
    }
}

// calm.js から届く「消した数」を受け取る
final class Counter: NSObject, WKScriptMessageHandler {
    var got: ((Int, Int) -> Void)?
    var save: ((String, String) -> Void)?
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let d = m.body as? [String: Any] else { return }
        if let sv = d["save"] as? [String: Any], let id = sv["id"] as? String {
            let user = sv["user"] as? String ?? ""
            DispatchQueue.main.async { self.save?(id, user) }
            return
        }
        let a = d["ads"] as? Int ?? 0, s = d["suggested"] as? Int ?? 0
        DispatchQueue.main.async { self.got?(a, s) }
    }
}

// アプリごとの設定。オンが「止める・消す」
enum Cfg {
    static let keys = ["search", "ads", "suggested", "live"]
    static func get(_ k: String) -> Bool { UserDefaults.standard.object(forKey: "cfg." + k) as? Bool ?? true }
    static func set(_ k: String, _ v: Bool) { UserDefaults.standard.set(v, forKey: "cfg." + k) }
    static var all: [String: Bool] { Dictionary(uniqueKeysWithValues: keys.map { ($0, get($0)) }) }
}

struct WebView: UIViewRepresentable {
    let view: WKWebView
    func makeUIView(context: Context) -> WKWebView { view }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

