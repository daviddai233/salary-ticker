import AppKit

/// Touch Bar 实时工资展示（仅适用于 macOS 14 及以下的 MacBook Pro 2016-2020）
///
/// ⚠️ 注意：此文件在 macOS 15+ SDK (Swift 6.x) 上**无法编译**，
/// 因为 Apple 已从 SDK 中完全移除 NSTouchBar 相关 API。
///
/// 如果需要 Touch Bar 支持，请在 Xcode 中手动将 Deployment Target
/// 设置为 macOS 14.0 并使用 Xcode 15 编译。
///
/// 当前版本使用 swift build 编译，目标为 macOS 14+，Touch Bar 代码被排除在编译之外。
/// 菜单栏功能不受影响。

// MARK: - 以下代码需在 macOS 14 SDK 下编译
// 取消注释即可启用

/*
final class TouchBarProvider: NSObject, NSTouchBarDelegate {
    
    private let calculator: SalaryCalculator
    
    private let earnedItemIdentifier: NSTouchBarItem.Identifier
    private let rateItemIdentifier: NSTouchBarItem.Identifier
    private let statusItemIdentifier: NSTouchBarItem.Identifier
    private let progressItemIdentifier: NSTouchBarItem.Identifier
    
    init(calculator: SalaryCalculator) {
        self.calculator = calculator
        self.earnedItemIdentifier = NSTouchBarItem.Identifier(rawValue: "com.salaryticker.earned")
        self.rateItemIdentifier = NSTouchBarItem.Identifier(rawValue: "com.salaryticker.rate")
        self.statusItemIdentifier = NSTouchBarItem.Identifier(rawValue: "com.salaryticker.status")
        self.progressItemIdentifier = NSTouchBarItem.Identifier(rawValue: "com.salaryticker.progress")
        super.init()
    }
    
    func makeTouchBar() -> NSTouchBar? {
        guard NSClassFromString("NSTouchBar") != nil else { return nil }
        
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            statusItemIdentifier,
            earnedItemIdentifier,
            rateItemIdentifier,
            progressItemIdentifier,
            NSTouchBarItem.Identifier.flexibleSpace,
        ]
        return bar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == statusItemIdentifier {
            return makeStatusLabel()
        } else if identifier == earnedItemIdentifier {
            return makeEarnedLabel()
        } else if identifier == rateItemIdentifier {
            return makeRateLabel()
        } else if identifier == progressItemIdentifier {
            return makeProgressSlider()
        }
        return nil
    }
    
    private func makeStatusLabel() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: statusItemIdentifier)
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        item.view = label
        label.stringValue = calculator.snapshot.formattedStatus
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { label.stringValue = self?.calculator.snapshot.formattedStatus ?? "" }
        }
        return item
    }
    
    private func makeEarnedLabel() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: earnedItemIdentifier)
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        label.textColor = calculator.snapshot.isWorking ? .systemGreen : .labelColor
        label.alignment = .center
        item.view = label
        label.stringValue = calculator.snapshot.formattedEarnedToday
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                label.stringValue = self?.calculator.snapshot.formattedEarnedToday ?? "¥0.00"
                label.textColor = self?.calculator.snapshot.isWorking == true ? .systemGreen : .labelColor
            }
        }
        return item
    }
    
    private func makeRateLabel() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: rateItemIdentifier)
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        item.view = label
        label.stringValue = calculator.snapshot.formattedPerSecond
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { label.stringValue = self?.calculator.snapshot.formattedPerSecond ?? "" }
        }
        return item
    }
    
    private func makeProgressSlider() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: progressItemIdentifier)
        let slider = NSSlider()
        slider.isContinuous = true
        slider.isEnabled = false
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = calculator.snapshot.progress
        item.view = slider
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { slider.doubleValue = self?.calculator.snapshot.progress ?? 0 }
        }
        return item
    }
}
*/
