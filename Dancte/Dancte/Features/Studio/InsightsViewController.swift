import UIKit

/// Where the hours actually went: volume, consistency, style split, which days
/// of the week you show up on, and the records worth beating.
final class InsightsViewController: UIViewController {

    private enum Range: Int, CaseIterable {
        case month, quarter, allTime

        var title: String {
            switch self {
            case .month:   return "4 weeks"
            case .quarter: return "12 weeks"
            case .allTime: return "All time"
            }
        }

        var days: Int? {
            switch self {
            case .month:   return 28
            case .quarter: return 84
            case .allTime: return nil
            }
        }
    }

    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let rangePicker = SegmentedPills(items: Range.allCases.map(\.title), accent: Palette.lime)
    private let tilesRow1 = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
    private let tilesRow2 = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
    private let tilesRow3 = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
    private let weekdayStack = UIStackView(axis: .vertical, spacing: 10)
    private let recordsStack = UIStackView(axis: .vertical, spacing: 0)
    private var distribution: DistributionBarView!
    private var sparkline: SparklineView!
    private var range: Range = .month

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        installBrandBackButton()
        styleNavigationBar(title: "Insights", subtitle: "What the numbers actually say")

        scroll.setTopPadding(12)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        rangePicker.onSelect = { [weak self] index in
            guard let self, let value = Range(rawValue: index) else { return }
            self.range = value
            self.reload()
        }
        rangePicker.translatesAutoresizingMaskIntoConstraints = false
        rangePicker.heightAnchor.constraint(equalToConstant: 40).isActive = true
        scroll.add(rangePicker)

        scroll.add(makeTotalsSection().gutterPadded())
        scroll.add(makeTrendSection().gutterPadded())
        scroll.add(makeStyleSection().gutterPadded())
        scroll.add(makeWeekdaySection().gutterPadded())
        scroll.add(makeRecordsSection().gutterPadded())

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .danctePractice, object: nil)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func section(eyebrow: String, title: String, body: UIView) -> UIView {
        let header = SectionHeader(eyebrow: eyebrow, title: title)
        let column = UIStackView(arrangedSubviews: [header, body])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    private func makeTotalsSection() -> UIView {
        let grid = UIStackView(axis: .vertical, spacing: 10)
        grid.addArrangedSubview(tilesRow1)
        grid.addArrangedSubview(tilesRow2)
        grid.addArrangedSubview(tilesRow3)
        return section(eyebrow: "The window", title: "Totals", body: grid)
    }

    private func makeTrendSection() -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: "MINUTES PER WEEK", attributes: [
            .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint
        ])

        sparkline = SparklineView(accent: Palette.lime)
        sparkline.translatesAutoresizingMaskIntoConstraints = false
        sparkline.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let stack = UIStackView(arrangedSubviews: [eyebrow, sparkline])
        stack.axis = .vertical
        stack.spacing = 10

        card.addSubviews(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return section(eyebrow: "Momentum", title: "The trend", body: card)
    }

    private func makeStyleSection() -> UIView {
        distribution = DistributionBarView()
        return section(eyebrow: "Where the hours go", title: "By style", body: distribution)
    }

    private func makeWeekdaySection() -> UIView {
        return section(eyebrow: "When you show up", title: "By weekday", body: weekdayStack)
    }

    private func makeRecordsSection() -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        card.addSubviews(recordsStack)
        NSLayoutConstraint.activate([
            recordsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            recordsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            recordsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            recordsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        return section(eyebrow: "Personal bests", title: "Records", body: card)
    }

    // MARK: - Render

    @objc private func reload() {
        let sessions = store.sessions(inLast: range.days)
        let totalMinutes = sessions.reduce(0) { $0 + $1.minutes }
        let count = sessions.count
        let average = count == 0 ? 0 : totalMinutes / count
        let longest = sessions.map(\.minutes).max() ?? 0

        let byDay = Dictionary(grouping: sessions) { $0.date.startOfDay }
        let activeDays = byDay.count

        // How much of the window actually had work in it.
        let windowDays: Int
        if let days = range.days {
            windowDays = days
        } else if let first = sessions.map(\.date).min() {
            windowDays = (Calendar.current.dateComponents([.day], from: first.startOfDay, to: Date().startOfDay).day ?? 0) + 1
        } else {
            windowDays = 1
        }
        let consistency = min(1, Double(activeDays) / Double(max(windowDays, 1)))

        buildTiles(total: totalMinutes, count: count, average: average,
                   longest: longest, activeDays: activeDays, consistency: consistency, sessions: sessions)

        sparkline.setValues(store.weeklySeries(weeks: range == .month ? 6 : 12).map { CGFloat($0.minutes) })

        let styleMinutes = Dictionary(grouping: sessions, by: \.style)
            .map { (style: $0.key, minutes: $0.value.reduce(0) { $0 + $1.minutes }) }
            .sorted { $0.minutes > $1.minutes }
        distribution.setData(styleMinutes, total: totalMinutes)

        buildWeekdays(sessions)
        buildRecords(sessions, styleMinutes: styleMinutes)
    }

    private func buildTiles(total: Int, count: Int, average: Int, longest: Int,
                            activeDays: Int, consistency: Double, sessions: [PracticeSession]) {
        for row in [tilesRow1, tilesRow2, tilesRow3] {
            row.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }

        tilesRow1.addArrangedSubview(StatTile(value: Format.longDuration(Double(total * 60)),
                                              caption: "Time on the floor", accent: Palette.lime,
                                              symbol: "clock.fill", compact: true))
        tilesRow1.addArrangedSubview(StatTile(value: "\(count)", caption: "Sessions",
                                              accent: Palette.cyan, symbol: "checkmark.circle.fill", compact: true))

        tilesRow2.addArrangedSubview(StatTile(value: Format.minutes(average), caption: "Average session",
                                              accent: Palette.violet, symbol: "chart.bar.fill", compact: true))
        tilesRow2.addArrangedSubview(StatTile(value: Format.minutes(longest), caption: "Longest session",
                                              accent: Palette.blaze, symbol: "flame.fill", compact: true))

        tilesRow3.addArrangedSubview(StatTile(value: "\(activeDays)", caption: "Active days",
                                              accent: Palette.amber, symbol: "calendar", compact: true))
        tilesRow3.addArrangedSubview(StatTile(value: "\(Int(consistency * 100))%", caption: "Consistency",
                                              accent: Palette.magenta, symbol: "target", compact: true))
    }

    private func buildWeekdays(_ sessions: [PracticeSession]) {
        weekdayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let calendar = Calendar.current
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let byWeekday = Dictionary(grouping: sessions) { calendar.component(.weekday, from: $0.date) }
        let order = [2, 3, 4, 5, 6, 7, 1]
        let values = order.map { (weekday: $0, minutes: byWeekday[$0]?.reduce(0) { $0 + $1.minutes } ?? 0) }
        let maximum = max(values.map(\.minutes).max() ?? 0, 1)

        guard values.contains(where: { $0.minutes > 0 }) else {
            let label = UILabel()
            label.text = "No sessions in this window yet."
            label.font = Typo.caption
            label.textColor = Palette.textFaint
            weekdayStack.addArrangedSubview(label)
            return
        }

        for entry in values {
            let row = RatioBarRow(caption: names[entry.weekday],
                                  value: entry.minutes == 0 ? "—" : Format.minutes(entry.minutes),
                                  accent: entry.minutes == maximum ? Palette.lime : Palette.cyan,
                                  captionWidth: 42)
            row.configure(caption: names[entry.weekday],
                          value: entry.minutes == 0 ? "—" : Format.minutes(entry.minutes),
                          ratio: CGFloat(entry.minutes) / CGFloat(maximum),
                          accent: entry.minutes == maximum ? Palette.lime : Palette.cyan)
            weekdayStack.addArrangedSubview(row)
        }
    }

    private func buildRecords(_ sessions: [PracticeSession], styleMinutes: [(style: DanceStyle, minutes: Int)]) {
        recordsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let byWeek = Dictionary(grouping: sessions) { session in
            Calendar.current.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date.startOfDay
        }
        let bestWeek = byWeek.values.map { $0.reduce(0) { $0 + $1.minutes } }.max() ?? 0
        let drillCounts = Dictionary(grouping: sessions.flatMap(\.drills), by: { $0 })
        let topDrill = drillCounts.max { $0.value.count < $1.value.count }?.key

        let allTime = store.stats
        var rows: [(String, String, String, UIColor)] = [
            ("Longest session", Format.minutes(sessions.map(\.minutes).max() ?? 0), "timer", Palette.blaze),
            ("Best week", Format.minutes(bestWeek), "calendar.badge.clock", Palette.amber),
            ("Longest streak", "\(allTime.longestStreak) days", "flame.fill", Palette.lime)
        ]
        if let topDrill {
            rows.append(("Most drilled", topDrill, "repeat", Palette.cyan))
        }
        if let top = styleMinutes.first {
            rows.append(("Main style", top.style.title, "music.note", top.style.accent))
        }

        for (index, row) in rows.enumerated() {
            if index > 0 {
                recordsStack.addArrangedSubview(SeamView(color: Palette.stroke.withAlphaComponent(0.6)))
            }
            recordsStack.addArrangedSubview(makeRecordRow(title: row.0, value: row.1, symbol: row.2, accent: row.3))
        }
    }

    private func makeRecordRow(title: String, value: String, symbol: String, accent: UIColor) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
        icon.tintColor = accent
        icon.contentMode = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .dancte(14.5, .semibold)
        titleLabel.textColor = Palette.textMuted

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .dancte(15.5, .bold)
        valueLabel.textColor = Palette.text
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, titleLabel, UIView(), valueLabel])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 13, left: 0, bottom: 13, right: 0)
        return row
    }
}
