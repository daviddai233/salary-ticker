import Foundation

/// 用户手动标记的状态
enum WorkState: String, Codable {
    case working = "working"
    case slacking = "slacking"
}

/// 单日计时数据（持久化用）
struct DayTimeRecord: Codable {
    /// 日期字符串 "2026-04-23"
    let dateKey: String
    /// 摸鱼秒数（只有手动标记摸鱼时才累加）
    var slackSeconds: Double
    /// 当前状态（默认工作）
    var currentState: WorkState
    /// 进入当前状态的时间戳（Date.timeIntervalSince1970）
    var stateChangedAt: Double

    /// 格式化摸鱼时长
    var formattedSlackTime: String {
        Self.formatDuration(slackSeconds)
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func empty(state: WorkState = .working) -> DayTimeRecord {
        DayTimeRecord(
            dateKey: todayKey(),
            slackSeconds: 0,
            currentState: state,
            stateChangedAt: Date().timeIntervalSince1970
        )
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}

/// 工作/摸鱼状态管理
/// - 总时间由 SalaryCalculator 按工作时间段自动计算
/// - 本类只负责：1) 摸鱼/工作状态标记  2) 摸鱼时长累计  3) 持久化
/// - 默认状态为"工作"，不手动切换则全部算工作
/// - 刷新由外部驱动（StatusBarController 的统一 Timer），不自建 Timer
@Observable
class WorkStateTimer {
    private(set) var record: DayTimeRecord

    /// 当前状态
    var state: WorkState {
        record.currentState
    }

    /// 摸鱼时长（秒）
    var slackSeconds: Double { record.slackSeconds }

    /// 格式化摸鱼时长
    var formattedSlackTime: String {
        record.formattedSlackTime
    }

    private static let storeKey = "work_state_timer"
    /// 上次持久化的 slack 秒数，避免频繁写盘
    private var lastSavedSlack: Double

    init() {
        let loadedRecord = WorkStateTimer.loadRecord()
        self.record = loadedRecord
        self.lastSavedSlack = loadedRecord.slackSeconds
    }

    // MARK: - 状态切换

    func toggleState() {
        tick()
        let newState: WorkState = record.currentState == .working ? .slacking : .working
        record.currentState = newState
        record.stateChangedAt = Date().timeIntervalSince1970
        flushSave()
        // @Observable 宏会自动追踪 record 的变化，无需手动发通知
    }

    // MARK: - 外部驱动刷新（每秒由 StatusBarController 调用）

    /// 每秒调用：只在摸鱼状态时累加摸鱼时长
    func tick() {
        let todayKey = DayTimeRecord.todayKey()

        // 日期变了，重置
        if record.dateKey != todayKey {
            record = DayTimeRecord.empty(state: .working)
            lastSavedSlack = 0
        }

        // 只有摸鱼状态才累加摸鱼时长
        if record.currentState == .slacking {
            record.slackSeconds += 1
        }

        // 每 10 秒才写一次 UserDefaults，减少 IO
        if abs(record.slackSeconds - lastSavedSlack) >= 10 {
            flushSave()
        }
    }

    // MARK: - 持久化

    private func flushSave() {
        lastSavedSlack = record.slackSeconds
        do {
            let data = try JSONEncoder().encode(record)
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        } catch {
            print("[WorkStateTimer] 编码失败: \(error)")
        }
    }

    private static func loadRecord() -> DayTimeRecord {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else {
            return .empty()
        }
        do {
            var loaded = try JSONDecoder().decode(DayTimeRecord.self, from: data)
            let todayKey = DayTimeRecord.todayKey()

            if loaded.dateKey != todayKey {
                loaded = .empty(state: .working)
            } else {
                // 同一天，补算从上次退出到现在（仅摸鱼状态补算）
                let elapsed = Date().timeIntervalSince1970 - loaded.stateChangedAt
                if elapsed > 1 && loaded.currentState == .slacking {
                    loaded.slackSeconds += floor(elapsed)
                    loaded.stateChangedAt = Date().timeIntervalSince1970
                }
                // 保护：补算后如果状态已切回工作，将 stateChangedAt 更新为当前时间
                // 避免下次启动时误判
                if loaded.currentState == .working {
                    loaded.stateChangedAt = Date().timeIntervalSince1970
                }
            }
            return loaded
        } catch {
            print("[WorkStateTimer] 解码失败: \(error)")
            return .empty()
        }
    }
}
