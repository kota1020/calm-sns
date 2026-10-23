import SwiftUI
import FamilyControls
import ManagedSettings
import Combine
import WidgetKit

// 本物のインスタ・TikTokアプリを止める（スクリーンタイムの仕組み）。止めたアプリを開くと「制限中」の画面になる
@MainActor final class Shield: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var on = ShieldCore.on
    @Published var approved = AuthorizationCenter.shared.authorizationStatus == .approved
    @Published var error: String?
    private var watch: Any?
    private var change: Any?
    init() {
        // 許可の状態は起動直後に遅れて届くので、変わるたびに受け取る
        watch = AuthorizationCenter.shared.$authorizationStatus.receive(on: DispatchQueue.main).sink { [weak self] st in self?.approved = st == .approved }
        ShieldCore.migrate()
        on = ShieldCore.on
        selection = ShieldCore.selection()
        apply()   // 起動のたびに今のやり方でかけ直す（前の版の盾を外す）
        // ウィジェットで切り替えたら画面のスイッチも合わせる
        change = NotificationCenter.default.publisher(for: .calmShieldChanged).receive(on: DispatchQueue.main).sink { [weak self] _ in self?.on = ShieldCore.on }
    }
    func authorize() async {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
        catch { self.error = error.localizedDescription }
        approved = AuthorizationCenter.shared.authorizationStatus == .approved
    }
    func apply() {
        ShieldCore.save(on: on, selection: selection)
        ShieldCore.apply(on: on, selection: selection)
        WidgetCenter.shared.reloadAllTimelines()
    }
    var count: Int { selection.applicationTokens.count + selection.categoryTokens.count }
}

