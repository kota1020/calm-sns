import SwiftUI

// Calm：インスタとTikTokを「フォロー中だけ」で見るアプリ。
// インスタとTikTokのウェブ版をアプリの中で開き、おすすめ・リール・発見を消す（calm.js）。
// 本物のアプリはスクリーンタイムの仕組み（Shield）で止める。使った時間は毎日数える。
@main
struct CalmApp: App {
    @StateObject private var webs = WebStore()
    @StateObject private var usage = Usage()
    @StateObject private var shield = Shield()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(webs).environmentObject(usage).environmentObject(shield)
                .preferredColorScheme(.light)
        }
    }
}
