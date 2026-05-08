import SwiftUI
import AppKit

/// 菜单栏状态栏控制器（AppKit 层）
/// 负责创建 NSStatusItem、更新菜单栏文本、展示 Popover
/// 用一个统一 Timer 驱动所有数据刷新（菜单栏 + 弹窗），避免多 Timer 导致的抖动
@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?
    private let calculator: SalaryCalculator
    private let workTimer: WorkStateTimer
    /// 统一刷新定时器
    private var refreshTimer: Timer?
    /// 上次记录的日期 key，用于检测跨日
    private var lastRecordedDateKey: String = DailyRecord.todayKey()
    /// 上一次 tick 时的 snapshot 缓存（跨日用）
    private var lastTickSnapshot: SalarySnapshot = SalarySnapshot(earnedToday: 0, workedSecondsToday: 0, perSecond: 0, perMinute: 0, perHour: 0, isWorking: false, statusText: "", progress: 0, remainingSeconds: 0)
    /// 上一次 tick 时的 slack 缓存（跨日用）
    private var lastTickSlackSeconds: Double = 0
    /// 全天排班应工作秒数缓存（deinit 用，因为 deinit 无法访问 MainActor 的 calculator）
    private var cachedFullDaySeconds: Double = 0

    init(calculator: SalaryCalculator, workTimer: WorkStateTimer) {
        self.calculator = calculator
        self.workTimer = workTimer
        self.popover = NSPopover()

        // 创建菜单栏图标
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        cachedFullDaySeconds = calculator.settings.schedule.totalWorkSeconds
        setupButton()
        setupPopover()
        recoverPreviousDayIfNeeded()
        setupUnifiedTimer()
        setupEventMonitor()
    }

    // MARK: - Setup

    private func setupButton() {
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        let hostingController = NSHostingController(
            rootView: MenuBarPopoverView(calculator: calculator, timer: workTimer)
        )
        popover.contentViewController = hostingController
        // 让 SwiftUI 先布局一次，拿到真实尺寸
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let view = hostingController.view
            let size = view.fittingSize
            self.popover.contentSize = NSSize(width: ceil(size.width), height: ceil(size.height))
        }
    }

    /// 一个 Timer 统一驱动所有刷新：菜单栏文本 + calculator 重算 + timer tick
    private func setupUnifiedTimer() {
        updateMenuBarText()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // 0. 先缓存当前数据（在 tick 重置之前，跨日时这是昨天的最终数据）
                let prevDateKey = self.lastRecordedDateKey
                let prevSnapshot = self.calculator.snapshot
                let prevSlack = self.workTimer.slackSeconds
                // 1. 驱动 WorkStateTimer 累加摸鱼时长（可能跨日重置）
                self.workTimer.tick()
                // 2. 重算薪资数据（可能跨日重置）
                self.calculator.recalculate()
                // 3. 检查跨日，保存前一天记录（用缓存的数据）
                let todayKey = DailyRecord.todayKey()
                if todayKey != prevDateKey {
                    self.saveRecord(dateKey: prevDateKey, snapshot: prevSnapshot, slackSeconds: prevSlack)
                    print("[StatusBarController] 跨日保存：\(prevDateKey) -> 总计 ¥\(String(format: "%.2f", prevSnapshot.earnedToday))")
                    self.lastRecordedDateKey = todayKey
                }
                // 4. 缓存当前 tick 数据（供 deinit 使用）
                self.lastTickSnapshot = self.calculator.snapshot
                self.lastTickSlackSeconds = self.workTimer.slackSeconds
                self.cachedFullDaySeconds = self.calculator.settings.schedule.totalWorkSeconds
                // 5. 定期保存当日记录（每 60 秒）
                self.saveTodayRecordIfNeeded()
                // 6. 更新菜单栏
                self.updateMenuBarText()
                // @Observable 宏会自动追踪属性变化并通知 SwiftUI 刷新
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    private func setupEventMonitor() {
        // 点击外部关闭 popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                if let self, self.popover.isShown {
                    self.closePopover()
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            // show 后再次同步尺寸，防止抖动/偏移
            if let view = popover.contentViewController?.view {
                let size = view.fittingSize
                popover.contentSize = NSSize(width: ceil(size.width), height: ceil(size.height))
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Menu Bar Image Rendering

    /// 将图标和文字合成一张模板图片，设为 button.image
    /// template image 由系统自动渲染为合适的菜单栏颜色（浅色模式黑、深色模式白）
    private func renderMenuBarImage(iconName: String, amountText: String) -> NSImage? {
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig) else { return nil }

        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font]
        let textStr = NSAttributedString(string: "   " + amountText, attributes: textAttrs)
        let textSize = textStr.size()

        // 图标 13pt + 间距 + 文字
        let iconW: CGFloat = 13
        let spacing: CGFloat = 2
        let totalWidth = iconW + spacing + textSize.width
        let height: CGFloat = max(icon.size.height, textSize.height) + 4
        let image = NSImage(size: NSSize(width: totalWidth, height: height))

        image.lockFocus()
        // 绘制图标
        icon.draw(in: NSRect(x: 0, y: (height - icon.size.height) / 2,
                              width: icon.size.width, height: icon.size.height),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        // 绘制文字
        textStr.draw(at: NSPoint(x: iconW + spacing, y: (height - textSize.height) / 2))
        image.unlockFocus()

        image.isTemplate = true
        return image
    }

    // MARK: - 每日记录保存

    /// 启动时恢复前一天数据（如果 app 退出时没来得及保存）
    private func recoverPreviousDayIfNeeded() {
        guard let prevDateKey = workTimer.previousDateKey else { return }
        // 如果 HistoryStore 已有该天记录，说明退出时已成功保存，跳过
        guard HistoryStore.get(dateKey: prevDateKey) == nil else { return }
        // 没有记录 → 用旧 slackSeconds + calculator 的全天数据恢复
        // 此时 calculator 已经 recalculate 过（当前是新一天），但 perHour 不变
        let schedule = calculator.settings.schedule
        let totalSec = schedule.totalWorkSeconds  // 已下班 = 全天排班时长
        let slackSec = min(workTimer.previousSlackSeconds, totalSec)
        let workSec = max(0, totalSec - slackSec)
        let hourlyRate = calculator.settings.monthlySalary / schedule.monthlyWorkSeconds
        let workR = totalSec > 0 ? workSec / totalSec : 1.0

        let record = DailyRecord(
            id: prevDateKey,
            dateKey: prevDateKey,
            totalEarned: totalSec / 3600.0 * hourlyRate,
            workEarned: workSec / 3600.0 * hourlyRate,
            slackEarned: slackSec / 3600.0 * hourlyRate,
            workedSeconds: workSec,
            slackSeconds: slackSec,
            workRatio: workR
        )
        HistoryStore.save(record)
        print("[StatusBarController] 启动恢复前一天记录：\(prevDateKey) -> 总计 ¥\(String(format: "%.2f", record.totalEarned))")
    }

    /// 上次保存的总工作时长快照（用于定期保存判断）
    private var lastSavedWorkedSeconds: Double = -1

    /// 定期保存当日记录（每 60 秒检查一次，有变化才写盘）
    private func saveTodayRecordIfNeeded() {
        let snapshot = calculator.snapshot
        let totalSec = snapshot.workedSecondsToday

        // 总工作时长没有显著变化（至少 60 秒），跳过
        // 无论工作还是摸鱼状态，工作时间每秒都在流逝，所以用总时长判断最可靠
        guard totalSec > 0 && abs(totalSec - lastSavedWorkedSeconds) >= 60 else { return }
        lastSavedWorkedSeconds = totalSec

        saveTodayRecord()
    }

    /// 保存当日记录到 HistoryStore（使用实时数据，已过下班时间则用全天满额兜底）
    func saveTodayRecord() {
        let snapshot = calculator.snapshot
        // 如果已下班（progress == 1.0 或 workedSeconds == totalWorkSeconds），直接用满额
        // 否则用实时工作秒数
        let slackSec = min(workTimer.slackSeconds, snapshot.workedSecondsToday)
        saveRecord(dateKey: DailyRecord.todayKey(), snapshot: snapshot, slackSeconds: slackSec)
    }

    /// 保存指定日期的记录（内部通用方法）
    /// - 工作日：workedSeconds 取「实际工时」与「全天排班时长」的较大值
    ///   确保退出时未到下班的中间数据，不会比全天满额还少（工资按天发）
    /// - 摸鱼时长保留原始值，不做放大
    private func saveRecord(dateKey: String, snapshot: SalarySnapshot, slackSeconds: Double) {
        let schedule = calculator.settings.schedule
        let fullDaySec = schedule.totalWorkSeconds      // 全天排班应工作秒数
        let perSecond = snapshot.perSecond              // 每秒工资（从 snapshot 取，perSecond 不因跨日变化）
        let hourlyRate = snapshot.perHour

        // 实际工时（来自 snapshot，可能是下班前的不完整值）
        let actualSec = snapshot.workedSecondsToday

        // 判断当天是否应算工作日（只要 perSecond > 0 且 fullDaySec > 0 就算）
        let isWorkDay = fullDaySec > 0 && perSecond > 0

        // 工时取较大值：如果是工作日，保底用全天满额（避免提前退出导致记录偏低）
        let effectiveSec = isWorkDay ? max(actualSec, fullDaySec) : actualSec

        let slackSec = min(slackSeconds, effectiveSec)
        let workSec = max(0, effectiveSec - slackSec)
        let workR = effectiveSec > 0 ? workSec / effectiveSec : 1.0
        let totalEarned = effectiveSec * perSecond

        let record = DailyRecord(
            id: dateKey,
            dateKey: dateKey,
            totalEarned: totalEarned,
            workEarned: workSec / 3600.0 * hourlyRate,
            slackEarned: slackSec / 3600.0 * hourlyRate,
            workedSeconds: workSec,
            slackSeconds: slackSec,
            workRatio: workR
        )
        HistoryStore.save(record)
    }

    // MARK: - Menu Bar Text Update

    /// 更新菜单栏显示：状态图标 + 总收入（基于工作时间段的自动计算）
    private func updateMenuBarText() {
        guard let button = statusItem.button else { return }

        let state = workTimer.state
        let totalEarn = calculator.snapshot.earnedToday
        let iconName = state == .working ? "hammer" : "fish"
        let amountText = String(format: "¥%.0f", totalEarn)

        let compositeImage = renderMenuBarImage(iconName: iconName, amountText: amountText)
        if let compositeImage {
            button.image = compositeImage
            button.title = ""
            button.attributedTitle = NSAttributedString()
        }

        statusItem.length = compositeImage?.size.width ?? NSStatusItem.variableLength
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        refreshTimer?.invalidate()
        // deinit 是 nonisolated，用缓存的最终数据保存
        let dateKey = lastRecordedDateKey
        let actualSec = lastTickSnapshot.workedSecondsToday
        // 只在有实际工作时长时才保存，避免覆盖已有记录
        guard actualSec > 0 else { return }

        let perSecond = lastTickSnapshot.perSecond
        let hourlyRate = lastTickSnapshot.perHour
        // 全天满额兜底：工作日取全天排班时长的较大值
        let isWorkDay = cachedFullDaySeconds > 0 && perSecond > 0
        let effectiveSec = isWorkDay ? max(actualSec, cachedFullDaySeconds) : actualSec

        let slackSec = min(lastTickSlackSeconds, effectiveSec)
        let workSec = max(0, effectiveSec - slackSec)
        let workR = effectiveSec > 0 ? workSec / effectiveSec : 1.0
        let totalEarned = effectiveSec * perSecond
        let record = DailyRecord(
            id: dateKey,
            dateKey: dateKey,
            totalEarned: totalEarned,
            workEarned: workSec / 3600.0 * hourlyRate,
            slackEarned: slackSec / 3600.0 * hourlyRate,
            workedSeconds: workSec,
            slackSeconds: slackSec,
            workRatio: workR
        )
        HistoryStore.save(record)
        print("[StatusBarController] deinit 保存：\(dateKey), eff=\(effectiveSec)s")
    }
}
