import SwiftUI
import AppKit

/// 菜单栏弹窗主界面 — 工作/摸鱼计时控制面板
struct MenuBarPopoverView: View {
    @Bindable var calculator: SalaryCalculator
    @Bindable var timer: WorkStateTimer

    /// 总时间（秒）— 由 SalaryCalculator 按工作时间段自动计算
    private var totalSeconds: Double { calculator.snapshot.workedSecondsToday }
    /// 摸鱼时间（不超过总时间）
    private var slackSeconds: Double { min(timer.slackSeconds, totalSeconds) }
    /// 工作时间 = 总时间 - 摸鱼时间
    private var workSeconds: Double { max(0, totalSeconds - slackSeconds) }
    /// 工作占比
    private var workRatio: Double {
        totalSeconds > 0 ? workSeconds / totalSeconds : 1.0
    }
    /// 摸鱼占比
    private var slackRatio: Double {
        totalSeconds > 0 ? slackSeconds / totalSeconds : 0
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部：状态文字 + 切换按钮
            VStack(spacing: 8) {
                stateTitle
                toggleButton
            }

            Divider()

            // 超大今日窝囊费
            totalEarnSection

            // 下班倒计时
            countdownSection

            // 红绿分段进度条
            ratioProgressBar

            // 工作/摸鱼 双卡片
            statsCards

            Divider()

            // 底部：设置 + 退出
            bottomButtons
        }
        .padding(16)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 状态文字（纯文字，无图标）

    private var stateTitle: some View {
        Text(timer.state == .working ? "工作中" : "摸鱼中")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(timer.state == .working ? .red : .green)
            .frame(height: 32)
    }

    // MARK: - 今日窝囊费（超大醒目）

    private var totalEarnSection: some View {
        VStack(spacing: 4) {
            Text("今日窝囊费")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(String(format: "¥%.2f", calculator.snapshot.earnedToday))
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(height: 60)
    }

    // MARK: - 下班倒计时

    private var countdownSection: some View {
        let remaining = calculator.snapshot.remainingSeconds
        let text: String
        if remaining > 0 {
            text = "距离下班：\(formatDuration(remaining))"
        } else if calculator.snapshot.progress >= 1.0 {
            text = "已下班 🎉"
        } else {
            text = "未到上班时间"
        }
        return Text(text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(height: 22)
    }

    // MARK: - 红绿分段进度条

    private var ratioProgressBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                if totalSeconds > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.red.opacity(0.8))
                        .frame(width: geo.size.width * workRatio, height: geo.size.height)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.green.opacity(0.8))
                        .frame(width: geo.size.width * slackRatio, height: geo.size.height)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .quaternaryLabelColor))
                }
            }
        }
        .frame(height: 8)
    }

    // MARK: - 工作/摸鱼 双卡片

    private var statsCards: some View {
        let hourlyRate = calculator.snapshot.perHour
        let workEarn = workSeconds / 3600.0 * hourlyRate
        let slackEarn = slackSeconds / 3600.0 * hourlyRate

        let workPercent = totalSeconds > 0 ? Int(workRatio * 100 + 0.5) : 100
        let slackPercent = 100 - workPercent

        return HStack(spacing: 10) {
            // 工作卡片
            VStack(spacing: 4) {
                Image(systemName: "hammer")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                Text(formatDuration(workSeconds))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(minWidth: 80)
                Text(String(format: "¥%.2f", workEarn))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(workPercent)%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.red.opacity(0.08)))

            // 摸鱼卡片
            VStack(spacing: 4) {
                Image(systemName: "fish")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
                Text(formatDuration(slackSeconds))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .frame(minWidth: 80)
                Text(String(format: "¥%.2f", slackEarn))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(slackPercent)%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.green.opacity(0.08)))
        }
    }

    // MARK: - 状态切换按钮（纯文字）

    private var toggleButton: some View {
        Button {
            timer.toggleState()
        } label: {
            Text("切换状态")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.bordered)
        .tint(timer.state == .working ? .green : .red)
    }

    // MARK: - 底部按钮（记录 + 设置 + 退出）

    /// 退出按钮是否 hover
    @State private var isQuitHovered = false

    private var bottomButtons: some View {
        HStack(spacing: 0) {
            Spacer()

            Button {
                openRecords()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("记录")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                openSettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("退出")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(isQuitHovered ? .red : .secondary)
            .onHover { hovering in
                isQuitHovered = hovering
            }

            Spacer()
        }
        .frame(height: 20)
    }

    // MARK: - 通过 AppDelegate 打开窗口

    private func openSettings() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.showSettingsWindow()
    }

    private func openRecords() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.showRecordsWindow(calculator: calculator, timer: timer)
    }

    // MARK: - 工具

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
