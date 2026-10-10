import UIKit

// MARK: - Progress ring

/// The studio's signature meter — a thick rounded ring with room for a value
/// in the middle. Used for weekly targets, plan progress and daily goals.
final class ProgressRingView: UIView {

    private let track = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let glow = CAShapeLayer()
    private var lineWidth: CGFloat
    private var accent: UIColor
    private let centerContainer = UIView()

    private(set) var progress: CGFloat = 0

    init(size: CGFloat, lineWidth: CGFloat = 12, accent: UIColor = Palette.lime) {
        self.lineWidth = lineWidth
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        for layer in [glow, track, ring] {
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            layer.lineWidth = lineWidth
            self.layer.addSublayer(layer)
        }
        track.strokeColor = Palette.strokeHi.withAlphaComponent(0.35).cgColor
        ring.strokeColor = accent.cgColor
        glow.strokeColor = accent.withAlphaComponent(0.5).cgColor
        glow.lineWidth = lineWidth + 6
        ring.strokeEnd = 0
        glow.strokeEnd = 0

        centerContainer.translatesAutoresizingMaskIntoConstraints = false
        centerContainer.backgroundColor = .clear
        addSubview(centerContainer)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            centerContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerContainer.widthAnchor.constraint(equalTo: widthAnchor, constant: -lineWidth * 3.0),
            centerContainer.heightAnchor.constraint(equalTo: heightAnchor, constant: -lineWidth * 2.9)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = lineWidth / 2
        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                                radius: min(bounds.width, bounds.height) / 2 - inset,
                                startAngle: -.pi / 2,
                                endAngle: .pi * 1.5,
                                clockwise: true)
        [track, glow, ring].forEach { $0.path = path.cgPath; $0.frame = bounds }
        updateStroke(animated: false)
    }

    func setCenter(_ view: UIView) {
        centerContainer.subviews.forEach { $0.removeFromSuperview() }
        centerContainer.addSubviews(view)
        view.pinEdges(to: centerContainer)
    }

    func setAccent(_ color: UIColor) {
        accent = color
        ring.strokeColor = color.cgColor
        glow.strokeColor = color.withAlphaComponent(0.5).cgColor
    }

    func setProgress(_ value: CGFloat, animated: Bool = true, duration: TimeInterval = 0.9) {
        progress = min(max(value, 0), 1)
        updateStroke(animated: animated, duration: duration)
    }

    private func updateStroke(animated: Bool, duration: TimeInterval = 0.9) {
        let target = progress
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = ring.presentation()?.strokeEnd ?? ring.strokeEnd
            animation.toValue = target
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ring.add(animation, forKey: "progress")
            glow.add(animation, forKey: "progress")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeEnd = target
        glow.strokeEnd = target
        CATransaction.commit()
    }
}

// MARK: - Weekly bars

/// Seven-day volume chart used on the Studio dashboard and the history screen.
final class WeekBarsView: UIView {

    private var series: [(date: Date, minutes: Int)] = []
    private var bars: [UIView] = []
    private var valueLabels: [UILabel] = []
    private var dayLabels: [UILabel] = []
    private var barHeights: [NSLayoutConstraint] = []
    private let accent: UIColor
    private let chartHeight: CGFloat
    private let maxBarHeight: CGFloat

    init(accent: UIColor = Palette.lime, chartHeight: CGFloat = 132) {
        self.accent = accent
        self.chartHeight = chartHeight
        self.maxBarHeight = chartHeight - 48
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let columns = UIStackView(axis: .horizontal, spacing: 6, distribution: .fillEqually)
        addSubviews(columns)
        NSLayoutConstraint.activate([
            columns.leadingAnchor.constraint(equalTo: leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor),
            columns.topAnchor.constraint(equalTo: topAnchor),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: chartHeight)
        ])

        for _ in 0..<7 {
            let column = UIView()
            column.translatesAutoresizingMaskIntoConstraints = false

            let value = UILabel()
            value.font = .dancteMono(10, .bold)
            value.textColor = Palette.textFaint
            value.textAlignment = .center
            value.text = "—"
            value.translatesAutoresizingMaskIntoConstraints = false

            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.layer.cornerRadius = 8
            bar.layer.cornerCurve = .continuous
            bar.backgroundColor = accent.withAlphaComponent(0.28)

            let day = UILabel()
            day.font = .dancte(10.5, .bold)
            day.textColor = Palette.textFaint
            day.textAlignment = .center
            day.translatesAutoresizingMaskIntoConstraints = false

            column.addSubviews(value, bar, day)
            let height = bar.heightAnchor.constraint(equalToConstant: 6)
            NSLayoutConstraint.activate([
                value.centerXAnchor.constraint(equalTo: column.centerXAnchor),
                value.topAnchor.constraint(equalTo: column.topAnchor),

                day.centerXAnchor.constraint(equalTo: column.centerXAnchor),
                day.bottomAnchor.constraint(equalTo: column.bottomAnchor),

                bar.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 3),
                bar.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -3),
                bar.bottomAnchor.constraint(equalTo: day.topAnchor, constant: -7),
                bar.topAnchor.constraint(greaterThanOrEqualTo: value.bottomAnchor, constant: 4),
                height
            ])

            bars.append(bar)
            valueLabels.append(value)
            dayLabels.append(day)
            barHeights.append(height)
            columns.addArrangedSubview(column)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setData(_ series: [(date: Date, minutes: Int)], animate: Bool = true) {
        self.series = series
        let maximum = max(series.map(\.minutes).max() ?? 0, 1)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"

        func target(for minutes: Int) -> CGFloat {
            guard minutes > 0 else { return 6 }
            let ratio = CGFloat(minutes) / CGFloat(maximum)
            return max(12, maxBarHeight * ratio)
        }

        for (index, entry) in series.enumerated() where index < bars.count {
            dayLabels[index].text = formatter.string(from: entry.date).uppercased()
            valueLabels[index].text = entry.minutes == 0 ? "—" : "\(entry.minutes)"
            valueLabels[index].textColor = entry.minutes == 0 ? Palette.textFaint : accent
            dayLabels[index].textColor = entry.date.isToday ? accent : Palette.textFaint
            bars[index].backgroundColor = entry.minutes == 0
                ? Palette.strokeHi.withAlphaComponent(0.3)
                : (entry.date.isToday ? accent : accent.withAlphaComponent(0.45))
        }

        guard animate else {
            for (index, entry) in series.enumerated() where index < barHeights.count {
                barHeights[index].constant = target(for: entry.minutes)
            }
            return
        }

        for height in barHeights { height.constant = 6 }
        layoutIfNeeded()
        UIView.animate(withDuration: 0.55, delay: 0.04, options: [.curveEaseOut]) {
            for (index, entry) in series.enumerated() where index < self.barHeights.count {
                self.barHeights[index].constant = target(for: entry.minutes)
            }
            self.layoutIfNeeded()
        }
    }
}

// MARK: - Practice heatmap

/// Calendar heatmap of training days. Column per week, row per weekday, with
/// intensity mapped onto the accent colour.
final class HeatmapView: UIView {

    private let weeks: Int
    private let accent: UIColor
    private var cells: [UIView] = []
    private var monthLabels: [UILabel] = []
    private let cellSize: CGFloat
    private let gap: CGFloat

    init(weeks: Int = 15, accent: UIColor = Palette.lime, cellSize: CGFloat = 13, gap: CGFloat = 4) {
        self.weeks = weeks
        self.accent = accent
        self.cellSize = cellSize
        self.gap = gap
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let calendar = Calendar.current
        let today = Date().startOfDay
        // Anchor so the final column contains today.
        let weekdayOfToday = calendar.component(.weekday, from: today)
        let start = calendar.date(byAdding: .day, value: -((weeks - 1) * 7 + weekdayOfToday - 1), to: today) ?? today

        let grid = UIView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)

        for column in 0..<weeks {
            for row in 0..<7 {
                let cell = UIView()
                cell.translatesAutoresizingMaskIntoConstraints = false
                cell.layer.cornerRadius = 4
                cell.layer.cornerCurve = .continuous
                cell.backgroundColor = Palette.strokeHi.withAlphaComponent(0.22)
                cell.tag = column * 7 + row
                cell.accessibilityLabel = "No session"
                grid.addSubview(cell)
                cells.append(cell)
                NSLayoutConstraint.activate([
                    cell.widthAnchor.constraint(equalToConstant: cellSize),
                    cell.heightAnchor.constraint(equalToConstant: cellSize),
                    cell.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: CGFloat(column) * (cellSize + gap)),
                    cell.topAnchor.constraint(equalTo: grid.topAnchor, constant: CGFloat(row) * (cellSize + gap))
                ])
            }
            let label = UILabel()
            label.font = .dancte(9, .bold)
            label.textColor = Palette.textFaint
            label.translatesAutoresizingMaskIntoConstraints = false
            grid.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: CGFloat(column) * (cellSize + gap)),
                label.topAnchor.constraint(equalTo: grid.topAnchor, constant: -14)
            ])
            monthLabels.append(label)
            // Remember which date each column starts on for month labelling.
            columnStarts.append(calendar.date(byAdding: .day, value: column * 7, to: start) ?? start)
        }
        _ = monthLabels

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor),
            grid.heightAnchor.constraint(equalToConstant: CGFloat(7) * (cellSize + gap)),
            heightAnchor.constraint(equalToConstant: CGFloat(7) * (cellSize + gap) + 18)
        ])

        self.startDate = start
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var startDate: Date = Date()
    private var columnStarts: [Date] = []

    func setData(_ series: [(date: Date, minutes: Int)]) {
        let calendar = Calendar.current
        let lookup = Dictionary(series.map { ($0.date.startOfDay, $0.minutes) }) { first, _ in first }
        let maximum = max(series.map(\.minutes).max() ?? 0, 1)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        // Columns are narrow, so a month label is only worth drawing when it has
        // room — otherwise "SEP" and "OCT" collide into one word.
        var lastLabelled = -99
        for column in 0..<weeks {
            let columnStart = columnStarts[safe: column] ?? startDate
            let nextStart = columnStarts[safe: column + 1] ?? calendar.date(byAdding: .day, value: 7, to: columnStart) ?? columnStart
            let isLastColumn = column == weeks - 1
            let changesMonth = calendar.component(.month, from: columnStart) != calendar.component(.month, from: nextStart)
            let hasRoom = column - lastLabelled >= 4
            let showsMonth = (changesMonth && hasRoom) || (isLastColumn && column - lastLabelled >= 3)
            if showsMonth { lastLabelled = column }
            monthLabels[column].text = showsMonth ? monthFormatter.string(from: columnStart).uppercased() : ""

            for row in 0..<7 {
                let index = column * 7 + row
                guard let cell = cells[safe: index] else { continue }
                let day = calendar.date(byAdding: .day, value: row, to: columnStart) ?? columnStart
                let minutes = lookup[day.startOfDay] ?? 0
                let isFuture = day > Date().startOfDay

                if isFuture {
                    cell.backgroundColor = UIColor.clear
                    cell.layer.borderWidth = 1
                    cell.layer.borderColor = Palette.strokeHi.withAlphaComponent(0.2).cgColor
                    cell.accessibilityLabel = "Upcoming"
                } else if minutes == 0 {
                    cell.backgroundColor = Palette.strokeHi.withAlphaComponent(0.22)
                    cell.layer.borderWidth = 0
                    cell.accessibilityLabel = "Rest day"
                } else {
                    let ratio = CGFloat(minutes) / CGFloat(maximum)
                    cell.backgroundColor = accent.withAlphaComponent(0.28 + ratio * 0.72)
                    cell.layer.borderWidth = 0
                    let label = DateFormatter.localizedString(from: day, dateStyle: .medium, timeStyle: .none)
                    cell.accessibilityLabel = "\(minutes) minutes on \(label)"
                }
            }
        }
    }
}

// MARK: - Distribution bar

/// Horizontal stacked bar plus legend, used for style breakdowns.
final class DistributionBarView: UIView {

    private let bar = UIView()
    private let legend = UIStackView(axis: .vertical, spacing: 10)
    private var segments: [UIView] = []

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.layer.cornerRadius = 12
        bar.layer.cornerCurve = .continuous
        bar.clipsToBounds = true
        bar.backgroundColor = Palette.surfaceHi

        let column = UIStackView(arrangedSubviews: [bar, legend])
        column.axis = .vertical
        column.spacing = 18
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        column.pinEdges(to: self)

        NSLayoutConstraint.activate([bar.heightAnchor.constraint(equalToConstant: 24)])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setData(_ items: [(style: DanceStyle, minutes: Int)], total: Int) {
        bar.subviews.forEach { $0.removeFromSuperview() }
        legend.arrangedSubviews.forEach { $0.removeFromSuperview() }
        segments = []

        let safeTotal = max(total, 1)
        var offset: CGFloat = 0
        let totalRatio = CGFloat(items.reduce(0) { $0 + $1.minutes }) / CGFloat(safeTotal)

        for item in items.prefix(6) {
            let ratio = CGFloat(item.minutes) / CGFloat(safeTotal)
            guard ratio > 0 else { continue }
            let segment = UIView()
            segment.translatesAutoresizingMaskIntoConstraints = false
            segment.backgroundColor = item.style.accent
            bar.addSubview(segment)
            NSLayoutConstraint.activate([
                segment.topAnchor.constraint(equalTo: bar.topAnchor),
                segment.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
                segment.widthAnchor.constraint(equalTo: bar.widthAnchor, multiplier: ratio)
            ])
            if offset == 0 {
                segment.leadingAnchor.constraint(equalTo: bar.leadingAnchor).isActive = true
            } else if let previous = segments.last {
                segment.leadingAnchor.constraint(equalTo: previous.trailingAnchor).isActive = true
            }
            offset += ratio
            segments.append(segment)

            legend.addArrangedSubview(makeLegendRow(for: item, total: safeTotal))
        }

        if segments.isEmpty || totalRatio <= 0 {
            let empty = UIView()
            empty.translatesAutoresizingMaskIntoConstraints = false
            empty.backgroundColor = Palette.strokeHi.withAlphaComponent(0.3)
            bar.addSubview(empty)
            empty.pinEdges(to: bar)
        }
    }

    private func makeLegendRow(for item: (style: DanceStyle, minutes: Int), total: Int) -> UIView {
        let dot = UIView()
        dot.backgroundColor = item.style.accent
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false

        let name = UILabel()
        name.text = item.style.title
        name.font = .dancte(14, .semibold)
        name.textColor = Palette.text

        let share = UILabel()
        share.text = "\(Int((Double(item.minutes) / Double(total) * 100).rounded()))%"
        share.font = .dancteMono(12, .bold)
        share.textColor = item.style.accent

        let minutes = UILabel()
        minutes.text = Format.minutes(item.minutes)
        minutes.font = .dancteMono(12, .semibold)
        minutes.textColor = Palette.textMuted
        minutes.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [dot, name, UIView(), minutes, share])
        row.axis = .horizontal
        row.spacing = 9
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
        share.widthAnchor.constraint(equalToConstant: 42).isActive = true
        minutes.widthAnchor.constraint(equalToConstant: 62).isActive = true
        return row
    }
}

// MARK: - Sparkline

/// Compact trend line used on stat cards.
final class SparklineView: UIView {

    private let line = CAShapeLayer()
    private let fill = CAShapeLayer()
    private var values: [CGFloat] = []
    private var accent: UIColor

    init(accent: UIColor = Palette.lime) {
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.addSublayer(fill)
        layer.addSublayer(line)
        line.fillColor = UIColor.clear.cgColor
        line.lineWidth = 2.5
        line.lineCap = .round
        line.lineJoin = .round
        line.strokeColor = accent.cgColor
        fill.strokeColor = UIColor.clear.cgColor
        fill.fillColor = accent.withAlphaComponent(0.14).cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValues(_ values: [CGFloat], accent: UIColor? = nil) {
        self.values = values
        if let accent {
            self.accent = accent
            line.strokeColor = accent.cgColor
            fill.fillColor = accent.withAlphaComponent(0.14).cgColor
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard values.count > 1, bounds.width > 0 else {
            line.path = nil
            fill.path = nil
            return
        }
        let maximum = max(values.max() ?? 1, 1)
        let step = bounds.width / CGFloat(values.count - 1)
        let path = UIBezierPath()
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: CGFloat(index) * step,
                                y: bounds.height - (value / maximum) * (bounds.height - 4) - 2)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        line.path = path.cgPath

        let area = UIBezierPath(cgPath: path.cgPath)
        area.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        area.addLine(to: CGPoint(x: 0, y: bounds.height))
        area.close()
        fill.path = area.cgPath
    }
}

// MARK: - Ratio row

/// One labelled progress rule: caption on the left, a value on the right and a
/// filled track between them. Used for stage breakdowns, weekday patterns and
/// week-by-week plan adherence.
final class RatioBarRow: UIView {

    private let captionLabel = UILabel()
    private let valueLabel = UILabel()
    private let track = UIView()
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint!
    private var accent: UIColor

    init(caption: String = "", value: String = "", accent: UIColor = Palette.lime, captionWidth: CGFloat = 96) {
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        captionLabel.text = caption
        captionLabel.font = .dancte(12.5, .semibold)
        captionLabel.textColor = Palette.textMuted
        captionLabel.lineBreakMode = .byTruncatingTail
        captionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        valueLabel.text = value
        valueLabel.font = .dancteMono(12, .bold)
        valueLabel.textColor = accent
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        track.backgroundColor = Palette.strokeHi.withAlphaComponent(0.35)
        track.layer.cornerRadius = 3.5
        track.layer.cornerCurve = .continuous
        track.clipsToBounds = true

        fill.backgroundColor = accent
        fill.layer.cornerRadius = 3.5
        fill.layer.cornerCurve = .continuous

        track.addSubviews(fill)
        addSubviews(captionLabel, track, valueLabel)
        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            captionLabel.widthAnchor.constraint(equalToConstant: captionWidth),

            track.leadingAnchor.constraint(equalTo: captionLabel.trailingAnchor, constant: 10),
            track.heightAnchor.constraint(equalToConstant: 7),
            track.centerYAnchor.constraint(equalTo: centerYAnchor),

            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fillWidth,

            valueLabel.leadingAnchor.constraint(equalTo: track.trailingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(caption: String, value: String, ratio: CGFloat, accent: UIColor? = nil) {
        captionLabel.text = caption
        valueLabel.text = value
        if let accent {
            self.accent = accent
            valueLabel.textColor = accent
            fill.backgroundColor = accent
        }
        let clamped = max(0, min(1, ratio))
        fillWidth.isActive = false
        fillWidth = fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(0.0001, clamped))
        fillWidth.isActive = true
        layoutIfNeeded()
    }
}

// MARK: - Training board

/// The week as seven columns of actual minutes measured against the target the
/// goals asked for. Rest days read as hollow, future days sit back, and today
/// is the only column that shouts.
final class WeekBoardView: UIView {

    private struct Column {
        let column: UIView
        let value: UILabel
        let bar: UIView
        let marker: UIView
        let day: UILabel
        let barHeight: NSLayoutConstraint
    }

    private let accent: UIColor
    private let chartHeight: CGFloat
    private let maxBarHeight: CGFloat
    private var columns: [Column] = []

    init(accent: UIColor = Palette.lime, chartHeight: CGFloat = 150) {
        self.accent = accent
        self.chartHeight = chartHeight
        self.maxBarHeight = chartHeight - 62
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(axis: .horizontal, spacing: 6, distribution: .fillEqually)
        addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: chartHeight)
        ])

        for _ in 0..<7 {
            let column = UIView()

            let value = UILabel()
            value.font = .dancteMono(10, .bold)
            value.textColor = Palette.textFaint
            value.textAlignment = .center
            value.text = "—"

            let bar = UIView()
            bar.layer.cornerRadius = 8
            bar.layer.cornerCurve = .continuous
            bar.backgroundColor = accent.withAlphaComponent(0.28)

            // The tick that shows what the goal asked of this day.
            let marker = UIView()
            marker.backgroundColor = Palette.text.withAlphaComponent(0.55)
            marker.layer.cornerRadius = 1

            let day = UILabel()
            day.font = .dancte(10.5, .bold)
            day.textColor = Palette.textFaint
            day.textAlignment = .center

            column.addSubviews(value, bar, marker, day)
            let height = bar.heightAnchor.constraint(equalToConstant: 6)
            NSLayoutConstraint.activate([
                value.centerXAnchor.constraint(equalTo: column.centerXAnchor),
                value.topAnchor.constraint(equalTo: column.topAnchor),

                day.centerXAnchor.constraint(equalTo: column.centerXAnchor),
                day.bottomAnchor.constraint(equalTo: column.bottomAnchor),

                bar.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 3),
                bar.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -3),
                bar.bottomAnchor.constraint(equalTo: day.topAnchor, constant: -7),
                bar.topAnchor.constraint(greaterThanOrEqualTo: value.bottomAnchor, constant: 4),
                height,

                marker.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                marker.trailingAnchor.constraint(equalTo: column.trailingAnchor),
                marker.heightAnchor.constraint(equalToConstant: 2),
                marker.bottomAnchor.constraint(equalTo: bar.bottomAnchor)
            ])

            columns.append(Column(column: column, value: value, bar: bar, marker: marker, day: day, barHeight: height))
            row.addArrangedSubview(column)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setData(_ items: [(date: Date, minutes: Int, planned: Int, isRest: Bool)], animate: Bool = true) {
        let maximum = max(items.map(\.minutes).max() ?? 0, items.map(\.planned).max() ?? 0, 1)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        let today = Date().startOfDay

        func barHeight(_ minutes: Int) -> CGFloat {
            guard minutes > 0 else { return 6 }
            return max(12, maxBarHeight * CGFloat(minutes) / CGFloat(maximum))
        }

        func markerOffset(_ planned: Int) -> CGFloat {
            guard planned > 0 else { return 0 }
            return min(maxBarHeight * CGFloat(planned) / CGFloat(maximum), maxBarHeight)
        }

        for (index, item) in items.enumerated() where index < columns.count {
            let column = columns[index]
            let isFuture = item.date.startOfDay > today
            let isToday = item.date.isToday

            column.day.text = formatter.string(from: item.date).uppercased()
            column.day.textColor = isToday ? accent : Palette.textFaint

            column.value.text = item.minutes == 0 ? (item.isRest ? "rest" : "—") : "\(item.minutes)"
            column.value.textColor = item.minutes == 0 ? Palette.textFaint : accent
            column.value.alpha = isFuture ? 0.4 : 1

            if item.isRest && item.minutes == 0 {
                column.bar.backgroundColor = .clear
                column.bar.layer.borderWidth = 1
                column.bar.layer.borderColor = Palette.strokeHi.withAlphaComponent(0.7).cgColor
            } else {
                column.bar.layer.borderWidth = 0
                column.bar.backgroundColor = item.minutes == 0
                    ? Palette.strokeHi.withAlphaComponent(0.3)
                    : (isToday ? accent : accent.withAlphaComponent(0.45))
            }
            column.bar.alpha = isFuture ? 0.35 : 1

            column.marker.isHidden = item.planned == 0
            column.marker.backgroundColor = isToday
                ? Palette.text
                : Palette.text.withAlphaComponent(0.4)

            column.column.layer.borderWidth = isToday ? 1.5 : 0
            column.column.layer.borderColor = accent.withAlphaComponent(0.55).cgColor
            column.column.layer.cornerRadius = 12
            column.column.layer.cornerCurve = .continuous
            column.column.backgroundColor = isToday ? accent.withAlphaComponent(0.06) : .clear

            // The marker rides on top of the bar, so its offset is the bar's own
            // height plus whatever the goal asked for beyond it.
            column.marker.transform = CGAffineTransform(translationX: 0, y: -markerOffset(item.planned))
        }

        guard animate else {
            for (index, item) in items.enumerated() where index < columns.count {
                columns[index].barHeight.constant = barHeight(item.minutes)
            }
            return
        }

        for column in columns { column.barHeight.constant = 6 }
        layoutIfNeeded()
        UIView.animate(withDuration: 0.55, delay: 0.04, options: [.curveEaseOut]) {
            for (index, item) in items.enumerated() where index < self.columns.count {
                self.columns[index].barHeight.constant = barHeight(item.minutes)
            }
            self.layoutIfNeeded()
        }
    }
}
