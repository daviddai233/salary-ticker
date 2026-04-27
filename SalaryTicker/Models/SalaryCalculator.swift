import Foundation

/// 薪资类型
enum SalaryType: String, Codable, CaseIterable {
    case monthly = "月薪"
    case yearly = "年薪"
    
    var label: String { rawValue }
}

/// 工作日配置
struct WorkSchedule: Codable, Equatable {
    /// 上班时间（小时 0~23）
    var startHour: Int
    /// 上班时间（分钟 0~59）
    var startMinute: Int
    /// 下班时间（小时 0~23）
    var endHour: Int
    /// 下班时间（分钟 0~59）
    var endMinute: Int
    /// 午休开始时间（小时）
    var lunchStartHour: Int
    /// 午休开始时间（分钟）
    var lunchStartMinute: Int
    /// 午休结束时间（小时）
    var lunchEndHour: Int
    /// 午休结束时间（分钟）
    var lunchEndMinute: Int
    /// 每月工作天数（默认 22 天）
    var workDaysPerMonth: Int
    /// 是否包含周末（默认 false）
    var includeWeekends: Bool
    
    static let `default` = WorkSchedule(
        startHour: 9, startMinute: 0,
        endHour: 18, endMinute: 0,
        lunchStartHour: 12, lunchStartMinute: 0,
        lunchEndHour: 13, lunchEndMinute: 0,
        workDaysPerMonth: 22,
        includeWeekends: false
    )
    
    /// 计算总工作时长（秒），扣除午休
    var totalWorkSeconds: TimeInterval {
        let start = TimeInterval(startHour * 3600 + startMinute * 60)
        let end = TimeInterval(endHour * 3600 + endMinute * 60)
        let lunchStart = TimeInterval(lunchStartHour * 3600 + lunchStartMinute * 60)
        let lunchEnd = TimeInterval(lunchEndHour * 3600 + lunchEndMinute * 60)
        let lunchDuration = max(0, lunchEnd - lunchStart)
        return max(0, end - start - lunchDuration)
    }
    
    /// 每日工时（小时）
    var dailyWorkHours: Double {
        totalWorkSeconds / 3600.0
    }
    
    /// 每月总工作时长（秒）
    var monthlyWorkSeconds: TimeInterval {
        totalWorkSeconds * Double(workDaysPerMonth)
    }
}

/// 薪资设置
struct SalarySettings: Codable, Equatable {
    /// 薪资类型（月薪 / 年薪）
    var salaryType: SalaryType
    /// 薪资金额（元）
    var salaryAmount: Double
    /// 工作时间安排
    var schedule: WorkSchedule
    
    /// 实际月薪（统一转为月薪计算）
    var monthlySalary: Double {
        switch salaryType {
        case .monthly: return salaryAmount
        case .yearly:  return salaryAmount / 12.0
        }
    }
    
    /// 切换薪资类型，自动转换薪资金额
    mutating func setSalaryType(_ newType: SalaryType) {
        guard salaryType != newType else { return }
        let monthly = salaryType == .monthly ? salaryAmount : salaryAmount / 12.0
        salaryType = newType
        salaryAmount = newType == .monthly ? monthly : monthly * 12.0
    }
    
    static let `default` = SalarySettings(
        salaryType: .monthly,
        salaryAmount: 10000,
        schedule: .default
    )
}

/// 工资计算结果
struct SalarySnapshot {
    /// 今日已赚金额
    let earnedToday: Double
    /// 今日已工作秒数
    let workedSecondsToday: Double
    /// 每秒赚多少
    let perSecond: Double
    /// 每分钟赚多少
    let perMinute: Double
    /// 每小时赚多少
    let perHour: Double
    /// 是否在工作时间范围内
    let isWorking: Bool
    /// 工作状态描述
    let statusText: String
    /// 今日进度 (0~1)
    let progress: Double
    /// 距离下班剩余秒数（已下班或未上班时为 0）
    let remainingSeconds: Double
    
    /// 当日精确工资：每秒 xx.xx 元
    var formattedPerSecond: String {
        String(format: "¥%.4f/秒", perSecond)
    }
    
    /// 今日已赚金额
    var formattedEarnedToday: String {
        String(format: "¥%.2f", earnedToday)
    }
    
    /// 状态文案
    var formattedStatus: String {
        if isWorking {
            let hours = Int(workedSecondsToday) / 3600
            let minutes = (Int(workedSecondsToday) % 3600) / 60
            return "已工作 \(hours)h\(minutes)m"
        } else {
            return statusText
        }
    }
}
