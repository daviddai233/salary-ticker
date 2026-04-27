import SwiftUI

/// 首次启动欢迎页 — 引导用户填写月薪和工作时间
struct WelcomeView: View {
    let calculator: SalaryCalculator
    let onComplete: () -> Void
    
    // 表单临时状态
    @State private var salaryType: SalaryType = .monthly
    @State private var salaryAmount: Double = 10000
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 18
    @State private var endMinute: Int = 0
    @State private var lunchStartHour: Int = 12
    @State private var lunchStartMinute: Int = 0
    @State private var lunchEndHour: Int = 13
    @State private var lunchEndMinute: Int = 0
    @State private var workDaysPerMonth: Int = 22
    @State private var includeWeekends: Bool = false
    @State private var animateLogo = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: 顶部品牌区
            brandHeader
            
            Divider()
                .padding(.horizontal, 24)
            
            // MARK: 表单区（可滚动）
            ScrollView {
                VStack(spacing: 24) {
                    // 月薪
                    salarySection
                    
                    // 工作时间
                    workTimeSection
                    
                    // 午休时间
                    lunchSection
                    
                    // 其他
                    otherSection
                }
                .padding(24)
            }
            
            Divider()
                .padding(.horizontal, 24)
            
            // MARK: 底部按钮
            actionButtons
                .padding(20)
        }
        .frame(width: 460, height: 620)
        .onAppear {
            // 从 calculator 加载已有设置
            salaryType = calculator.settings.salaryType
            salaryAmount = calculator.settings.salaryAmount
            startHour = calculator.settings.schedule.startHour
            startMinute = calculator.settings.schedule.startMinute
            endHour = calculator.settings.schedule.endHour
            endMinute = calculator.settings.schedule.endMinute
            lunchStartHour = calculator.settings.schedule.lunchStartHour
            lunchStartMinute = calculator.settings.schedule.lunchStartMinute
            lunchEndHour = calculator.settings.schedule.lunchEndHour
            lunchEndMinute = calculator.settings.schedule.lunchEndMinute
            workDaysPerMonth = calculator.settings.schedule.workDaysPerMonth
            includeWeekends = calculator.settings.schedule.includeWeekends
            
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateLogo = true
            }
        }
    }
    
    // MARK: - 品牌头部
    
    private var brandHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "fish.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color(red: 0.15, green: 0.55, blue: 0.85)))
                .symbolEffect(.bounce, value: animateLogo)
                .opacity(animateLogo ? 1 : 0)
                .offset(y: animateLogo ? 0 : 10)
            
            Text("欢迎使用 SalaryTicker")
                .font(.title.bold())
            
            Text("输入你的薪资信息，实时查看每秒赚多少钱 💰")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }
    
    // MARK: - 薪资
    
    private var salarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "dollarsign.circle.fill", title: "薪资", color: .green)
            
            // 月薪 / 年薪 切换
            Picker("薪资类型", selection: $salaryType) {
                ForEach(SalaryType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: salaryType) { oldType, newType in
                // 切换薪资类型时自动转换金额
                guard oldType != newType else { return }
                let monthly = oldType == .monthly ? salaryAmount : salaryAmount / 12.0
                salaryAmount = newType == .monthly ? monthly : monthly * 12.0
            }
            .padding(.bottom, 4)
            
            HStack {
                TextField("请输入\(salaryType.label)", value: $salaryAmount, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(height: 40)
                
                Text(salaryType == .monthly ? "元/月" : "元/年")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    // MARK: - 工作时间
    
    private var workTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "clock.fill", title: "工作时间", color: .blue)
            
            HStack(spacing: 16) {
                TimePickerField(
                    label: "上班",
                    hour: $startHour,
                    minute: $startMinute
                )
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                TimePickerField(
                    label: "下班",
                    hour: $endHour,
                    minute: $endMinute
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    // MARK: - 午休时间
    
    private var lunchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "fork.knife", title: "午休时间", color: .orange)
            
            HStack(spacing: 16) {
                TimePickerField(
                    label: "开始",
                    hour: $lunchStartHour,
                    minute: $lunchStartMinute
                )
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                TimePickerField(
                    label: "结束",
                    hour: $lunchEndHour,
                    minute: $lunchEndMinute
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    // MARK: - 其他
    
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "calendar", title: "其他", color: .purple)
            
            HStack {
                Text("每月工作天数")
                    .font(.body)
                Spacer()
                Stepper("\(workDaysPerMonth) 天", value: $workDaysPerMonth, in: 1...31)
            }
            
            Toggle("周末也算工作日", isOn: $includeWeekends)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    // MARK: - 按钮
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("跳过，使用默认") {
                applySettings()
                onComplete()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button("开始计时 💰") {
                applySettings()
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
    
    // MARK: - 应用设置
    
    private func applySettings() {
        let schedule = WorkSchedule(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            lunchStartHour: lunchStartHour,
            lunchStartMinute: lunchStartMinute,
            lunchEndHour: lunchEndHour,
            lunchEndMinute: lunchEndMinute,
            workDaysPerMonth: workDaysPerMonth,
            includeWeekends: includeWeekends
        )
        
        calculator.settings = SalarySettings(
            salaryType: salaryType,
            salaryAmount: salaryAmount,
            schedule: schedule
        )
        
        SettingsStore.markOnboardingDone()
    }
}

// MARK: - 子组件

/// 区块标题
private struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(color)
    }
}

/// 时间选择器（小时:分钟）
private struct TimePickerField: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 2) {
                Picker("", selection: $hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 64)
                .labelsHidden()
                
                Text(":")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $minute) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 64)
                .labelsHidden()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
        }
    }
}
