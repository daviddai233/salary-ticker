import AppKit
import SwiftUI

/// App 入口（通过 main.swift 启动）
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    private var calculator: SalaryCalculator!
    private var workTimer: WorkStateTimer!
    private var welcomeWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化计算引擎
        calculator = SalaryCalculator()
        // 初始化工作/摸鱼计时器
        workTimer = WorkStateTimer()
        
        // 初始化菜单栏
        statusBarController = StatusBarController(calculator: calculator, workTimer: workTimer)
        
        setupMainMenu()
        
        // 启动后短暂延迟再弹窗，确保 App 完全就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showInitialWindow()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 菜单栏 App 不随窗口关闭退出
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
