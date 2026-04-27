import Foundation

/// 设置持久化存储（UserDefaults）
enum SettingsStore {
    private static let salaryKey = "salary_settings"
    private static let onboardingDoneKey = "onboarding_done"
    
    /// 是否已完成首次引导
    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingDoneKey)
    }
    
    /// 标记首次引导已完成
    static func markOnboardingDone() {
        UserDefaults.standard.set(true, forKey: onboardingDoneKey)
    }
    
    /// 加载设置
    static func load() -> SalarySettings {
        guard let data = UserDefaults.standard.data(forKey: salaryKey) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(SalarySettings.self, from: data)
        } catch {
            print("[SettingsStore] 解码失败: \(error)")
            return .default
        }
    }
    
    /// 保存设置
    static func save(_ settings: SalarySettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: salaryKey)
        } catch {
            print("[SettingsStore] 编码失败: \(error)")
        }
    }
    
    /// 清除设置
    static func clear() {
        UserDefaults.standard.removeObject(forKey: salaryKey)
        UserDefaults.standard.removeObject(forKey: onboardingDoneKey)
    }
}
