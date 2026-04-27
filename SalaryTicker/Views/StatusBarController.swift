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

    init(calculator: SalaryCalculator, workTimer: WorkStateTimer) {
        self.calculator = calculator
        self.workTimer = workTimer
        self.popover = NSPopover()

        // 创建菜单栏图标
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupButton()
        setupPopover()
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
                // 1. 驱动 WorkStateTimer 累加摸鱼时长
                self.workTimer.tick()
                // 2. 重算薪资数据
                self.calculator.recalculate()
                // 3. 更新菜单栏
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
    }
}
