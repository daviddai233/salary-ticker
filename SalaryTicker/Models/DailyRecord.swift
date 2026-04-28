import Foundation

/// 单日历史记录（持久化用）
struct DailyRecord: Codable, Identifiable {
    let id: String  // = dateKey
    let dateKey: String          // "2026-04-27"
    let totalEarned: Double      // 当日总窝囊费
    let workEarned: Double       // 工作窝囊费
    let slackEarned: Double      // 摸鱼窝囊费
    let workedSeconds: Double    // 工作秒数
    let slackSeconds: Double     // 摸鱼秒数
    let workRatio: Double        // 工作占比 0~1

    /// 工作时长格式化
    var formattedWorkTime: String {
        DailyRecord.formatDuration(workedSeconds)
    }

    /// 摸鱼时长格式化
    var formattedSlackTime: String {
        DailyRecord.formatDuration(slackSeconds)
    }

    /// 工作占比百分比
    var workPercent: Int {
        Int(workRatio * 100 + 0.5)
    }

    /// 摸鱼占比百分比
    var slackPercent: Int {
        100 - workPercent
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
