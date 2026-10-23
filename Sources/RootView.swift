import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// ===== 一番外側：下のタブ（アイコンだけ）。SNSはホームから全画面で開く =====
enum Tab: String { case time, home, stop, settings }

struct RootView: View {
    @EnvironmentObject var usage: Usage
    @EnvironmentObject var webs: WebStore
    @AppStorage("tab3") private var tab: Tab = .home
    @State private var open: Service?
    var body: some View {
        VStack(spacing: 0) {
            // 4つの画面は作ったまま持ち、見せる1つだけ前に出す。切り替えのたびに作り直さないので速い
            // （スクリーンタイムの読み込みも1回で済む）
            ZStack {
                page(.time) { TimeScreen() }
                page(.home) { HomeScreen(open: $open, tab: $tab) }
                page(.stop) { StopScreen() }
                page(.settings) { SettingsScreen() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar(tab: $tab)
        }
        .background(Color.white.ignoresSafeArea())
        .foregroundColor(C.ink)
        .onAppear { webs.warmUp() }
        .fullScreenCover(item: $open) { s in SNSScreen(service: s) }
        .onChange(of: open) { _, s in usage.current = s; if s != nil { webs.resetCounts() } else { webs.pauseAll() } }
    }
}
extension RootView {
    func page<V: View>(_ t: Tab, @ViewBuilder _ v: () -> V) -> some View {
        v().opacity(tab == t ? 1 : 0).allowsHitTesting(tab == t).accessibilityHidden(tab != t)
    }
}
extension Service: Identifiable { var id: String { rawValue } }

struct TabBar: View {
    @Binding var tab: Tab
    var body: some View {
        HStack {
            item(.time, "chart.bar.xaxis", "時間")
            item(.home, "house", "ホーム")
            item(.stop, "shield", "止める")
            item(.settings, "gearshape", "設定")
        }
        .frame(height: 54).padding(.horizontal, 12)
        .background(Color.white)
    }
    private func item(_ t: Tab, _ icon: String, _ name: String) -> some View {
        Button { tab = t } label: {
            Image(systemName: tab == t && t != .time ? icon + ".fill" : icon).font(.system(size: 21, weight: tab == t ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(tab == t ? C.ink : C.faint)
        }
        .accessibilityLabel(name)
    }
}
