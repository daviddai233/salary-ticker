import AppKit

/// 手动启动 NSApplication — 确保命令行 swift build 和 Xcode 都能正常工作
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 设置 Activation Policy：
// .accessory = 纯菜单栏 App（不在 Dock 显示，但可显示窗口）
app.setActivationPolicy(.accessory)

app.run()
