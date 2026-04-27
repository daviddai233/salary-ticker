import Foundation

/// 工资实时计算引擎
/// 刷新由外部驱动（StatusBarController 的统一 Timer），不自建 Timer
@Observable
class SalaryCalculator {
    var settings: SalarySettings {
        didSet {
            SettingsStore.save(settings)
            recalculate()
        }
    }
    
    /// 最新的计算结果
    private(set) var snapshot: SalarySnapshot
    
    init(settings: SalarySettings = SettingsStore.load()) {
        self.settings = settings
        self.snapshot = SalarySnapshot(
            earnedToday: 0,
            workedSecondsToday: 0,
            perSecond: 0,
            perMinute: 0,
            perHour: 0,
            isWorking: false,
            statusText: "未开始",
            progress: 0,
            remainingSeconds: 0
        )
        recalculate()
    }
    
    /// 核心计算逻辑（由外部定时调用）
    func recalculate() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second, .weekday], from: now)
        
        guard let hour = components.hour,
              let minute = components.minute,
              let second = components.second,
              let weekday = components.weekday else { return }
        
        let s = settings.schedule
        
        // 检查是否是工作日
        let isWeekend = (weekday == 1 || weekday == 7)
        if isWeekend && !s.includeWeekends {
            let idle = makeIdleSnapshot(statusText: "周末休息 🎉", progress: 1.0)
            snapshot = idle
            return
        }
        
        // 当前时间转为今日秒数
        let currentSeconds = Double(hour * 3600 + minute * 60 + second)
        let startSeconds = Double(s.startHour * 3600 + s.startMinute * 60)
        let endSeconds = Double(s.endHour * 3600 + s.endMinute * 60)
        let lunchStartSeconds = Double(s.lunchStartHour * 3600 + s.lunchStartMinute * 60)
        let lunchEndSeconds = Double(s.lunchEndHour * 3600 + s.lunchEndMinute * 60)
        
        let perSecond = settings.monthlySalary / s.monthlyWorkSeconds
        let perMinute = perSecond * 60
        let perHour = perMinute * 60
        
        var workedSeconds: Double = 0
        var isWorking = false
        var statusText = ""
        var progress: Double = 0
        var remainingSeconds: Double = 0
        
        if currentSeconds < startSeconds {
            // 还没上班
            let diff = startSeconds - currentSeconds
            let hours = Int(diff) / 3600
            let mins = (Int(diff) % 3600) / 60
            statusText = "距上班 \(hours)h\(mins)m"
            progress = 0
        } else if currentSeconds >= endSeconds {
            // 已下班
            workedSeconds = s.totalWorkSeconds
            statusText = "已下班 🎉"
            progress = 1.0
        } else {
            // 在工作时间内
            isWorking = true
            let elapsed = currentSeconds - startSeconds
            
            // 计算扣除午休后的实际工作秒数
            if currentSeconds <= lunchStartSeconds {
                // 上班后，午休前
                workedSeconds = elapsed
            } else if currentSeconds <= lunchEndSeconds {
                // 午休中
                workedSeconds = lunchStartSeconds - startSeconds
            } else {
                // 午休后
                workedSeconds = elapsed - (lunchEndSeconds - lunchStartSeconds)
            }
            
            workedSeconds = max(0, min(workedSeconds, s.totalWorkSeconds))
            progress = workedSeconds / s.totalWorkSeconds
            
            let hours = Int(workedSeconds) / 3600
            let mins = (Int(workedSeconds) % 3600) / 60
            statusText = "工作中 \(hours)h\(mins)m"
            
            // 距离下班剩余秒数
            remainingSeconds = endSeconds - currentSeconds
        }
        
        let earnedToday = workedSeconds * perSecond
        
        snapshot = SalarySnapshot(
            earnedToday: earnedToday,
            workedSecondsToday: workedSeconds,
            perSecond: perSecond,
            perMinute: perMinute,
            perHour: perHour,
            isWorking: isWorking,
            statusText: statusText,
            progress: progress,
            remainingSeconds: remainingSeconds
        )
    }
    
    /// 创建空闲状态的 snapshot
    private func makeIdleSnapshot(statusText: String, progress: Double) -> SalarySnapshot {
        let s = settings.schedule
        let perSecond = settings.monthlySalary / s.monthlyWorkSeconds
        return SalarySnapshot(
            earnedToday: 0,
            workedSecondsToday: 0,
            perSecond: perSecond,
            perMinute: perSecond * 60,
            perHour: perSecond * 3600,
            isWorking: false,
            statusText: statusText,
            progress: progress,
            remainingSeconds: 0
        )
    }
}
