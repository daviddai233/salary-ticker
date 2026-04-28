import Foundation

/// 历史记录持久化存储（UserDefaults）
enum HistoryStore {
    private static let storeKey = "daily_records"

    /// 加载所有历史记录
    static func loadAll() -> [String: DailyRecord] {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else {
            return [:]
        }
        do {
            let records = try JSONDecoder().decode([String: DailyRecord].self, from: data)
            return records
        } catch {
            print("[HistoryStore] 解码失败: \(error)")
            return [:]
        }
    }

    /// 加载所有记录（按日期降序）
    static func loadSorted() -> [DailyRecord] {
        let all = loadAll()
        return all.values.sorted { $0.dateKey > $1.dateKey }
    }

    /// 保存/更新某天记录
    static func save(_ record: DailyRecord) {
        var all = loadAll()
        all[record.dateKey] = record
        flush(all)
    }

    /// 获取某天记录
    static func get(dateKey: String) -> DailyRecord? {
        loadAll()[dateKey]
    }

    /// 删除某天记录
    static func delete(dateKey: String) {
        var all = loadAll()
        all.removeValue(forKey: dateKey)
        flush(all)
    }

    /// 清除所有记录
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: storeKey)
    }

    private static func flush(_ records: [String: DailyRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: storeKey)
        } catch {
            print("[HistoryStore] 编码失败: \(error)")
        }
    }
}
