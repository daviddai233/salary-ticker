import SwiftUI

/// 设置面板
struct SettingsView: View {
    @Bindable var calculator: SalaryCalculator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题
                Text("⚙️ 工资设置")
                    .font(.title2.bold())
                
                Form {
                    // MARK: - 薪资设置
                    Section("💰 薪资") {
                        // 月薪 / 年薪 切换
                        Picker("薪资类型", selection: Binding(
                            get: { calculator.settings.salaryType },
                            set: { newType in
                                calculator.settings.setSalaryType(newType)
                            }
                        )) {
                            ForEach(SalaryType.allCases, id: \.self) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Text(calculator.settings.salaryType.label)
                                .frame(width: 80, alignment: .leading)
                            TextField("", value: $calculator.settings.salaryAmount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                            Text(calculator.settings.salaryType == .monthly ? "元/月" : "元/年")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // MARK: - 工作时间
                    Section("🕐 工作时间") {
                        TimePickerRow(
                            label: "上班时间",
                            hour: $calculator.settings.schedule.startHour,
                            minute: $calculator.settings.schedule.startMinute
                        )
                        
                        TimePickerRow(
                            label: "下班时间",
                            hour: $calculator.settings.schedule.endHour,
                            minute: $calculator.settings.schedule.endMinute
                        )
                    }
                    
                    // MARK: - 午休时间
                    Section("🍱 午休时间") {
                        TimePickerRow(
                            label: "午休开始",
                            hour: $calculator.settings.schedule.lunchStartHour,
                            minute: $calculator.settings.schedule.lunchStartMinute
                        )
                        
                        TimePickerRow(
                            label: "午休结束",
                            hour: $calculator.settings.schedule.lunchEndHour,
                            minute: $calculator.settings.schedule.lunchEndMinute
                        )
                    }
                    
                    // MARK: - 其他设置
                    Section("📊 其他") {
                        HStack {
                            Text("每月工作天数")
                                .frame(width: 120, alignment: .leading)
                            Stepper(
                                "\(calculator.settings.schedule.workDaysPerMonth) 天",
                                value: $calculator.settings.schedule.workDaysPerMonth,
                                in: 1...31
                            )
                        }
                        
                        Toggle("周末也算工作日", isOn: $calculator.settings.schedule.includeWeekends)
                    }
                }
                .formStyle(.grouped)
                
                // 重置按钮
                Button("恢复默认设置") {
                    calculator.settings = .default
                }
                .buttonStyle(.bordered)

                // MARK: - 薪资概览（只读展示）
                Section("📋 薪资概览") {
                    DetailRow(label: "月薪", value: String(format: "¥%.0f", calculator.settings.monthlySalary))
                    DetailRow(label: "年薪", value: String(format: "¥%.0f", calculator.settings.monthlySalary * 12))
                    DetailRow(label: "时薪", value: String(format: "¥%.2f", calculator.snapshot.perHour))
                    DetailRow(label: "秒薪", value: String(format: "¥%.6f", calculator.snapshot.perSecond))
                    DetailRow(label: "工作日", value: "\(calculator.settings.schedule.workDaysPerMonth) 天/月")
                }
            }
            .padding(16)
        }
    }
}

/// 详情行组件
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}

/// 时间选择行组件
struct TimePickerRow: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            
            HStack(spacing: 4) {
                Picker("", selection: $hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 70)
                .labelsHidden()
                
                Text(":")
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $minute) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 70)
                .labelsHidden()
            }
        }
    }
}
