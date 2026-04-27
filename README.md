// SalaryTicker
// macOS 菜单栏实时工资计时器

## 功能
- 输入月薪，实时显示每秒赚多少钱
- 菜单栏常驻，显示今日已赚金额
- 点击展开详情面板（进度条、时薪、分薪、秒薪等）
- 支持自定义上下班时间和午休时间
- 设置自动持久化（UserDefaults）

## 技术栈
- Swift 5.10 / 6.x
- SwiftUI + AppKit
- macOS 14+
- Xcode 16+

## 项目结构

```
SalaryTicker/
├── Package.swift                        # Swift Package Manager 配置
├── README.md                            # 本文件
│
└── SalaryTicker/                        # 源代码根目录
    ├── AppDelegate.swift                # App 入口 (@main)
    ├── Info.plist                       # App 配置（LSUIElement=true 纯菜单栏）
    │
    ├── Models/                          # 📦 数据模型层
    │   └── SalaryCalculator.swift       #   WorkSchedule + SalarySettings + SalarySnapshot
    │
    ├── Services/                        # ⚙️ 业务逻辑层
    │   ├── SalaryCalculatorService.swift#   工资实时计算引擎（每秒刷新）
    │   └── SettingsStore.swift          #   UserDefaults 持久化
    │
    ├── Views/                           # 🎨 UI 层
    │   ├── MenuBarPopoverView.swift     #   菜单栏弹窗主界面（已赚/进度/详情）
    │   ├── SettingsView.swift           #   设置面板（月薪/工作时间/午休）
    │   └── StatusBarController.swift    #   NSStatusItem 菜单栏控制器
    │
    ├── TouchBar/                        # 🔲 Touch Bar 扩展（预留给旧设备）
    │   └── TouchBarProvider.swift       #   Touch Bar 实时工资展示（已注释）
    │
    ├── Extensions/                      # 扩展（预留）
    └── Resources/                       # 资源文件（预留）
```

## 架构说明

```
┌─────────────────────────────────────────────────┐
│                   AppDelegate                    │
│              (NSApplicationDelegate)             │
├──────────────────────┬──────────────────────────┤
│  StatusBarController │    Settings Window       │
│  (NSStatusItem)      │    (NSHostingController) │
├──────────────────────┴──────────────────────────┤
│           MenuBarPopoverView (SwiftUI)           │
│           SettingsView (SwiftUI)                 │
├─────────────────────────────────────────────────┤
│         SalaryCalculator (@Observable)            │
│         · 每秒定时刷新                            │
│         · 计算已赚金额/进度/时薪                   │
├──────────────────────┬──────────────────────────┤
│  SalaryCalculator    │     SettingsStore         │
│  (计算引擎)           │     (UserDefaults)        │
├──────────────────────┴──────────────────────────┤
│          Models: WorkSchedule / SalarySettings   │
└─────────────────────────────────────────────────┘
```

## 运行方式

### 方式一：命令行编译运行
```bash
cd SalaryTicker
swift build
.build/debug/SalaryTicker
```

### 方式二：Xcode 打开
```bash
# 生成 Xcode 项目
cd SalaryTicker
swift package generate-xcodeproj --xcconfig-overrides Package.xcconfig
# 或直接用 Xcode 打开
open Package.swift
```

## 使用方法
1. 启动 App 后，菜单栏出现 💴 图标
2. 图标旁实时显示今日已赚金额（如 `¥ 123.45`）
3. 点击图标 → 展开详情面板，查看：
   - 今日已赚（大数字实时跳动）
   - 工作进度条
   - 时薪 / 分薪 / 秒薪
4. 点击「设置」→ 配置：
   - 月薪金额
   - 上班/下班时间
   - 午休开始/结束时间
   - 每月工作天数
   - 是否包含周末
5. 设置自动保存，重启无需重新输入

## 状态自动识别

| 时间段       | 菜单栏显示        | 弹窗状态     |
|-------------|------------------|-------------|
| 上班前       | `距上班 2h30m`   | 等待上班      |
| 工作中（午休前）| `¥ 123.45` 🟢  | 工作中 3h20m |
| 午休中       | `¥ 280.00` 🟢   | 午休中       |
| 午休后工作中  | `¥ 350.00` 🟢   | 工作中 5h10m |
| 已下班       | `已下班 🎉`      | 今日完成      |
| 周末         | `周末休息 🎉`    | 休息中       |

## 关于 Touch Bar
Touch Bar API 已在 macOS 15 SDK 中被 Apple 完全移除。
本项目保留了 Touch Bar 代码（`TouchBar/TouchBarProvider.swift`，已注释），
如需在旧版 MacBook Pro (2016-2020) 上使用，请在 Xcode 15 + macOS 14 SDK 下编译。

## License
MIT
