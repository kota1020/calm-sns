import SwiftUI

// SNSの画面を開いてからの時間（上の帯の「0:16」）。
// 1日の時間はここでは数えない。iOSのスクリーンタイムから読む（Report/CalmReport.swift）
@MainActor final class Usage: ObservableObject {
    @Published var sessionStart: Date?
    var current: Service? { didSet { if current != oldValue { sessionStart = current == nil ? nil : Date() } } }
}
