import SwiftUI

/// 记录页面 — 日历视图 + 当日窝囊费详情
struct RecordsView: View {
    @Bindable var calculator: SalaryCalculator
    @Bindable var timer: WorkStateTimer

    /// 当前选中的月份
    @State private var displayMonth = Date()
    /// 当前选中的日期 key
    @State private var selectedDateKey: String?
    /// 所有历史记录缓存
    @State private var records: [String: DailyRecord] = [:]
    /// 是否正在显示今日实时数据
    @State private var showTodayLive: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // 页面标题
            Text("窝囊费记录")
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()

            // 月份切换
            monthHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // 日历网格
            calendarGrid
                .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 12)

            // 当日数据详情
            detailSection
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            loadRecords()
            // 默认选中今天
            selectedDateKey = DailyRecord.todayKey()
        }
    }

    // MARK: - 月份切换

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)

            Text(monthFormatter.string(from: displayMonth))
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)

            Button {
                changeMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - 日历网格

    private var calendarGrid: some View {
        let daysInMonth = numberOfDays(in: displayMonth)
        let firstWeekday = firstWeekdayOfMonth(displayMonth)
        let calendar = Calendar.current

        return VStack(spacing: 6) {
            // 星期标题行
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期格子
            let rows = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0))
            ForEach(0..<rows, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { colIndex in
                        let dayIndex = rowIndex * 7 + colIndex
                        let cell = calendarCell(dayIndex: dayIndex, firstWeekday: firstWeekday, daysInMonth: daysInMonth)
                        cell
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                    }
                }
            }
        }
    }

    // MARK: - 日历单元格

    @ViewBuilder
    private func calendarCell(dayIndex: Int, firstWeekday: Int, daysInMonth: Int) -> some View {
        let adjustedIndex = dayIndex - firstWeekday + 1
        if adjustedIndex < 1 || adjustedIndex > daysInMonth {
            // 空白占位
            Color.clear
        } else {
            let date = dateForDay(adjustedIndex, in: displayMonth)
            let key = dateFormatter.string(from: date)
            let isToday = key == DailyRecord.todayKey()
            let isSelected = key == selectedDateKey
            let hasRecord = records[key] != nil
            let isFuture = date > Date()

            Button {
                selectedDateKey = key
                showTodayLive = isToday
            } label: {
                ZStack {
                    // 选中背景
                    if isSelected {
                        Circle()
                            .fill(.blue)
                    } else if isToday {
                        Circle()
                            .strokeBorder(.blue, lineWidth: 1.5)
                    }

                    // 有数据的圆点指示
                    if hasRecord && !isSelected {
                        Circle()
                            .fill(.blue.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .offset(y: 12)
                    }

                    Text("\(adjustedIndex)")
                        .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(
                            isFuture ? AnyShapeStyle(.quaternary) :
                            isSelected ? AnyShapeStyle(Color.white) :
                            isToday ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.primary)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
        }
    }

    // MARK: - 当日数据详情

    private var detailSection: some View {
        Group {
            if showTodayLive && selectedDateKey == DailyRecord.todayKey() {
                // 今日实时数据
                liveTodayDetail
            } else if let key = selectedDateKey, let record = records[key] {
                // 历史记录数据
                historicalDetail(record: record)
            } else {
                // 无数据
                noDataPlaceholder
            }
        }
    }

    /// 今日实时数据（从当前 calculator/timer 读取）
    private var liveTodayDetail: some View {
        let snapshot = calculator.snapshot
        let totalSec = snapshot.workedSecondsToday
        let slackSec = min(timer.slackSeconds, totalSec)
        let workSec = max(0, totalSec - slackSec)
        let hourlyRate = snapshot.perHour
        let workEarn = workSec / 3600.0 * hourlyRate
        let slackEarn = slackSec / 3600.0 * hourlyRate
        let workR = totalSec > 0 ? workSec / totalSec : 1.0

        return VStack(spacing: 12) {
            Text(formatDateDisplay(selectedDateKey!))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            // 总窝囊费
            VStack(spacing: 2) {
                Text("当日总窝囊费")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Text(String(format: "¥%.2f", snapshot.earnedToday))
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
            }

            // 双卡片
            HStack(spacing: 10) {
                // 工作
                detailCard(
                    icon: "hammer",
                    color: .red,
                    time: formatDuration(workSec),
                    amount: workEarn,
                    percent: Int(workR * 100 + 0.5)
                )
                // 摸鱼
                detailCard(
                    icon: "fish",
                    color: .green,
                    time: formatDuration(slackSec),
                    amount: slackEarn,
                    percent: 100 - Int(workR * 100 + 0.5)
                )
            }

            // 进度条
            ratioBar(workRatio: workR, slackRatio: totalSec > 0 ? 1.0 - workR : 0)

            Text("📊 今日实时数据")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 历史记录详情
    private func historicalDetail(record: DailyRecord) -> some View {
        VStack(spacing: 12) {
            Text(formatDateDisplay(record.dateKey))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            // 总窝囊费
            VStack(spacing: 2) {
                Text("当日总窝囊费")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Text(String(format: "¥%.2f", record.totalEarned))
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
            }

            // 双卡片
            HStack(spacing: 10) {
                detailCard(
                    icon: "hammer",
                    color: .red,
                    time: record.formattedWorkTime,
                    amount: record.workEarned,
                    percent: record.workPercent
                )
                detailCard(
                    icon: "fish",
                    color: .green,
                    time: record.formattedSlackTime,
                    amount: record.slackEarned,
                    percent: record.slackPercent
                )
            }

            // 进度条
            ratioBar(workRatio: record.workRatio, slackRatio: 1.0 - record.workRatio)

            Text("📝 历史记录")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 无数据占位
    private var noDataPlaceholder: some View {
        VStack(spacing: 8) {
            Text(formatDateDisplay(selectedDateKey ?? ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer().frame(height: 16)

            Text("暂无记录")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Text("该日期没有窝囊费数据")
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)

            Spacer().frame(height: 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 子组件

    private func detailCard(icon: String, color: Color, time: String, amount: Double, percent: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(time)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(String(format: "¥%.2f", amount))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("\(percent)%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
    }

    private func ratioBar(workRatio: Double, slackRatio: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.red.opacity(0.8))
                    .frame(width: geo.size.width * workRatio, height: geo.size.height)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.green.opacity(0.8))
                    .frame(width: geo.size.width * slackRatio, height: geo.size.height)
            }
        }
        .frame(height: 8)
    }

    // MARK: - 月份操作

    private func changeMonth(_ offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayMonth) {
            displayMonth = newMonth
        }
    }

    private func loadRecords() {
        records = HistoryStore.loadAll()
    }

    // MARK: - 日期工具

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f
    }

    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    private func numberOfDays(in date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func firstWeekdayOfMonth(_ date: Date) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    private func dateForDay(_ day: Int, in month: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: month)
        components.day = day
        return Calendar.current.date(from: components) ?? month
    }

    private func formatDateDisplay(_ dateKey: String) -> String {
        guard !dateKey.isEmpty else { return "" }
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dateKey }
        let weekdays = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        guard let date = Calendar.current.date(from: comps) else { return dateKey }
        let wd = Calendar.current.component(.weekday, from: date)
        return String(format: "%d年%d月%d日 %@", parts[0], parts[1], parts[2], weekdays[wd])
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
