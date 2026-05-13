import AppKit
import SwiftUI

/// App 入口（通过 main.swift 启动）
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    private var calculator: SalaryCalculator!
    private var workTimer: WorkStateTimer!
    private var welcomeWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    private var recordsWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化计算引擎
        calculator = SalaryCalculator()
        // 初始化工作/摸鱼计时器
        workTimer = WorkStateTimer()
        
        // 初始化菜单栏
        statusBarController = StatusBarController(calculator: calculator, workTimer: workTimer)
        
        setupMainMenu()
        
        // 清理脏数据（启动时一次性）
        cleanupStaleRecords()

        // 启动后短暂延迟再弹窗，确保 App 完全就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showInitialWindow()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 菜单栏 App 不随窗口关闭退出
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前保存当日记录
        statusBarController?.saveTodayRecord()
    }
    
    // MARK: - 数据清理

    /// 清理脏数据，并修正因提前退出导致工时不足全天的历史记录
    private func cleanupStaleRecords() {
        // 1. 删除已知空记录（workedSeconds == 0 的周末误写记录）
        let staleDates = ["2026-04-27", "2026-04-28", "2026-05-02", "2026-05-03"]
        for dateKey in staleDates {
            if let record = HistoryStore.get(dateKey: dateKey), record.workedSeconds == 0 {
                HistoryStore.delete(dateKey: dateKey)
                print("[AppDelegate] 清理空记录：\(dateKey)")
            }
        }

        // 2. 清理所有周末记录（无论有无数据，周末不应有记录）
        let schedule = calculator.settings.schedule
        let allRecords = HistoryStore.loadSorted()
        for record in allRecords {
            if StatusBarController.isWeekend(dateKey: record.dateKey, schedule: schedule) {
                HistoryStore.delete(dateKey: record.dateKey)
                print("[AppDelegate] 清理周末记录：\(record.dateKey)")
            }
        }

        // 3. 修正 5/7 记录（因提前退出导致工时只有 4h59m，应为全天满额 6h30m）
        let fullDaySec = calculator.settings.schedule.totalWorkSeconds
        let perSecond = calculator.settings.monthlySalary / calculator.settings.schedule.monthlyWorkSeconds
        let hourlyRate = perSecond * 3600

        let fixDates = ["2026-05-07"]
        for dateKey in fixDates {
            guard let existing = HistoryStore.get(dateKey: dateKey) else { continue }
            let total = existing.workedSeconds + existing.slackSeconds
            // 只修正总工时明显不足全天的记录（< 全天 90%）
            guard total < fullDaySec * 0.9 else { continue }
            let slackSec = existing.slackSeconds
            let workSec = max(0, fullDaySec - slackSec)
            let workR = fullDaySec > 0 ? workSec / fullDaySec : 1.0
            let fixed = DailyRecord(
                id: dateKey,
                dateKey: dateKey,
                totalEarned: fullDaySec * perSecond,
                workEarned: workSec / 3600.0 * hourlyRate,
                slackEarned: slackSec / 3600.0 * hourlyRate,
                workedSeconds: workSec,
                slackSeconds: slackSec,
                workRatio: workR
            )
            HistoryStore.save(fixed)
            print("[AppDelegate] 修正不足全天记录：\(dateKey) \(total)s -> \(fullDaySec)s")
        }
    }

    // MARK: - 窗口管理
    
    /// 根据状态显示初始窗口
    private func showInitialWindow() {
        if !SettingsStore.hasCompletedOnboarding {
            showWelcomeWindow()
        }
        // 已配置过不弹窗，菜单栏可见即可
    }
    
    /// 显示欢迎引导页
    private func showWelcomeWindow() {
        if let wc = welcomeWindowController {
            wc.showWindow(nil)
            bringToFront(wc.window!)
            return
        }
        
        let welcomeView = WelcomeView(calculator: calculator) { [weak self] in
            self?.closeWelcomeWindow()
        }
        let hosting = NSHostingController(rootView: welcomeView)
        
        let window = NSWindow(contentViewController: hosting)
        window.title = "窝囊费 — 欢迎使用"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 620))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        welcomeWindowController = NSWindowController(window: window)
        welcomeWindowController?.showWindow(nil)
        bringToFront(window)
    }
    
    /// 关闭欢迎页
    private func closeWelcomeWindow() {
        welcomeWindowController?.close()
        welcomeWindowController = nil
    }
    
    /// 显示设置窗口
    func showSettingsWindow() {
        if let wc = settingsWindowController {
            wc.showWindow(nil)
            bringToFront(wc.window!)
            return
        }
        
        let settingsView = SettingsView(calculator: calculator)
        let hosting = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hosting)
        window.title = "窝囊费 — 设置"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 400, height: 540))
        window.minSize = NSSize(width: 360, height: 480)
        window.center()
        window.isReleasedWhenClosed = false
        
        settingsWindowController = NSWindowController(window: window)
        settingsWindowController?.showWindow(nil)
        bringToFront(window)
    }

    /// 显示记录窗口
    func showRecordsWindow(calculator: SalaryCalculator, timer: WorkStateTimer) {
        if let wc = recordsWindowController {
            wc.showWindow(nil)
            bringToFront(wc.window!)
            return
        }

        let recordsView = RecordsView(calculator: calculator, timer: timer)
        let hosting = NSHostingController(rootView: recordsView)

        let window = NSWindow(contentViewController: hosting)
        window.title = "窝囊费 — 记录"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 380, height: 560))
        window.minSize = NSSize(width: 360, height: 480)
        window.center()
        window.isReleasedWhenClosed = false

        recordsWindowController = NSWindowController(window: window)
        recordsWindowController?.showWindow(nil)
        bringToFront(window)
    }
    
    /// 显示欢迎页（从菜单栏「重新设置」触发）
    func showWelcomeFromMenu() {
        SettingsStore.clear()
        welcomeWindowController = nil
        showWelcomeWindow()
    }
    
    /// 强制将窗口提到最前面
    private func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.level = .floating
        // 0.5秒后恢复正常 level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            window.level = .normal
        }
    }
    
    // MARK: - 主菜单
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App 菜单
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(title: "关于 SalaryTicker", action: #selector(showAbout), keyEquivalent: "")
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            NSMenuItem(title: "退出 SalaryTicker", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 操作菜单
        let actionMenuItem = NSMenuItem()
        let actionMenu = NSMenu()
        actionMenu.addItem(
            NSMenuItem(title: "打开设置…", action: #selector(openSettings), keyEquivalent: ",")
        )
        actionMenu.addItem(NSMenuItem.separator())
        actionMenu.addItem(
            NSMenuItem(title: "重新设置（欢迎页）", action: #selector(resetAndShowWelcome), keyEquivalent: "")
        )
        actionMenuItem.submenu = actionMenu
        mainMenu.addItem(actionMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Menu Actions
    
    @objc private func openSettings() {
        showSettingsWindow()
    }
    
    @objc private func resetAndShowWelcome() {
        showWelcomeFromMenu()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "SalaryTicker"
        alert.informativeText = "实时工资计时器\n\n输入月薪，实时查看你每秒赚多少钱。\n\nVersion 1.0.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时不退出 App
    }
}
