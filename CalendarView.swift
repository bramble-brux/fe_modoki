import SwiftUI
import Charts

struct CalendarScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var records: [SessionRecord] = []
    @State private var selectedMonth: Date = Date()

    private var calendar: Calendar { Calendar.current }

    private var monthRecords: [SessionRecord] {
        records.filter { record in
            calendar.isDate(record.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var monthTotalSeconds: Int {
        monthRecords.reduce(0) { $0 + $1.durationSeconds }
    }

    private var dailyData: [(day: Int, seconds: Int)] {
        let range = calendar.range(of: .day, in: .month, for: selectedMonth) ?? 1..<32
        var dict: [Int: Int] = [:]
        for d in range { dict[d] = 0 }
        for record in monthRecords {
            let day = calendar.component(.day, from: record.date)
            dict[day, default: 0] += record.durationSeconds
        }
        return range.map { (day: $0, seconds: dict[$0] ?? 0) }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: selectedMonth)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        monthSelector
                        monthSummarySection
                        chartSection
                        historySection
                    }
                    .padding()
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            records = RecordStore.load()
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Month Summary

    private var monthSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("月間 Work 合計")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .tracking(1)
            Text(formatDuration(monthTotalSeconds))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.workAccent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceAlt)
        .cornerRadius(14)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日別 Work 時間")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .tracking(1)

            Chart(dailyData, id: \.day) { item in
                BarMark(
                    x: .value("日", item.day),
                    y: .value("分", Double(item.seconds) / 60.0)
                )
                .foregroundStyle(AppTheme.chartBar)
                .cornerRadius(2)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: 5)) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppTheme.textTertiary)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.surfaceAlt)
        .cornerRadius(14)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Work 履歴")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .tracking(1)

            if monthRecords.isEmpty {
                Text("この月の記録はありません")
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(monthRecords) { record in
                    historyRow(record)
                }
            }
        }
        .padding()
        .background(AppTheme.surfaceAlt)
        .cornerRadius(14)
    }

    @ViewBuilder
    private func historyRow(_ record: SessionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(record.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(formatTime(record.date))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text(formatDuration(record.durationSeconds))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.workAccent)
        }
        .padding(.vertical, 4)

        if record.id != monthRecords.last?.id {
            Divider().overlay(AppTheme.textTertiary)
        }
    }

    // MARK: - Helpers

    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)時間\(m)分"
        } else {
            return "\(m)分"
        }
    }
}
