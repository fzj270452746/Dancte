import UIKit

/// The full record: a calendar heatmap of every training day, the month's
/// numbers, how the hours split across styles, and every session in order.
final class PracticeHistoryViewController: UIViewController {

    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let heatmap = HeatmapView(weeks: 12, accent: Palette.lime)
    private let monthsStack = UIStackView(axis: .vertical, spacing: 16)
    private let distribution = DistributionBarView()
    private let monthLabel = UILabel()
    private let summaryRow = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
    private var anchorMonth: Date = Date().startOfDay

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        installBrandBackButton()
        styleNavigationBar(title: "History", subtitle: "Every session, every day")

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.setTopPadding(10)
        scroll.setBottomPadding(70)
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scroll.add(makeHeatmapSection().gutterPadded())
        scroll.add(makeMonthSection().gutterPadded())
        scroll.add(makeDistributionSection().gutterPadded())
        scroll.add(monthsStack.gutterPadded())

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .danctePractice, object: nil)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Sections

    private func makeHeatmapSection() -> UIView {
        let header = SectionHeader(eyebrow: "Consistency", title: "Training calendar")
        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))

        let legend = UIStackView(axis: .horizontal, spacing: 6, alignment: .center)
        let less = UILabel()
        less.text = "LESS"
        less.attributedText = NSAttributedString(string: "LESS", attributes: [
            .kern: 1, .font: UIFont.dancte(8.5, .bold), .foregroundColor: Palette.textFaint
        ])
        legend.addArrangedSubview(less)
        for alpha in [0.22, 0.45, 0.68, 1.0] {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = Palette.lime.withAlphaComponent(alpha)
            dot.layer.cornerRadius = 4
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            legend.addArrangedSubview(dot)
        }
        let more = UILabel()
        more.attributedText = NSAttributedString(string: "MORE", attributes: [
            .kern: 1, .font: UIFont.dancte(8.5, .bold), .foregroundColor: Palette.textFaint
        ])
        legend.addArrangedSubview(more)

        let column = UIStackView(arrangedSubviews: [legend, heatmap])
        column.axis = .vertical
        column.spacing = 14

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        let stack = UIStackView(arrangedSubviews: [header, card])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }

    private func makeMonthSection() -> UIView {
        let previous = IconButton(symbol: "chevron.left", size: 38, background: .glass, pointSize: 14)
        let next = IconButton(symbol: "chevron.right", size: 38, background: .glass, pointSize: 14)
        previous.onTap = { [weak self] in self?.shiftMonth(-1) }
        next.onTap = { [weak self] in self?.shiftMonth(1) }

        monthLabel.font = .dancte(22, .black)
        monthLabel.textColor = Palette.text
        monthLabel.textAlignment = .center

        let row = UIStackView(arrangedSubviews: [previous, monthLabel, next])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        monthLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let column = UIStackView(arrangedSubviews: [row, summaryRow])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    private func makeDistributionSection() -> UIView {
        let header = SectionHeader(eyebrow: "Where the hours go", title: "By style")
        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        card.addSubviews(distribution)
        NSLayoutConstraint.activate([
            distribution.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            distribution.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            distribution.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            distribution.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        let stack = UIStackView(arrangedSubviews: [header, card])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }

    // MARK: - Data

    private func shiftMonth(_ delta: Int) {
        guard let shifted = Calendar.current.date(byAdding: .month, value: delta, to: anchorMonth) else { return }
        // Never navigate past the current month.
        guard shifted <= Date() else { return }
        anchorMonth = shifted
        Haptics.selection()
        reload()
    }

    @objc private func reload() {
        let calendar = Calendar.current
        let allSessions = store.sessions
        heatmap.setData(store.minuteSeries(days: 12 * 7))

        monthLabel.text = anchorMonth.monthLabel

        let monthSessions = allSessions.filter {
            calendar.isDate($0.date, equalTo: anchorMonth, toGranularity: .month)
        }
        let minutes = monthSessions.reduce(0) { $0 + $1.minutes }
        let days = Set(monthSessions.map { $0.date.startOfDay }).count

        summaryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryRow.addArrangedSubview(StatTile(value: Format.minutes(minutes), caption: "Minutes", accent: Palette.lime, compact: true))
        summaryRow.addArrangedSubview(StatTile(value: "\(monthSessions.count)", caption: "Sessions", accent: Palette.cyan, compact: true))
        summaryRow.addArrangedSubview(StatTile(value: "\(days)", caption: "Active days", accent: Palette.violet, compact: true))

        let styleMinutes = Dictionary(grouping: allSessions, by: \.style)
            .map { (style: $0.key, minutes: $0.value.reduce(0) { $0 + $1.minutes }) }
            .sorted { $0.minutes > $1.minutes }
        distribution.setData(styleMinutes, total: allSessions.reduce(0) { $0 + $1.minutes })

        buildSessionList(monthSessions)
    }

    private func buildSessionList(_ sessions: [PracticeSession]) {
        monthsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !sessions.isEmpty else {
            let empty = EmptyStateView(symbol: "calendar",
                                       title: "Nothing logged this month",
                                       message: anchorMonth.monthLabel == Date().monthLabel
                                        ? "Log a session and it appears here straight away."
                                        : "No sessions were recorded in \(anchorMonth.monthLabel).",
                                       actionTitle: anchorMonth.monthLabel == Date().monthLabel ? "Log a session" : nil,
                                       compact: true)
            empty.onAction = { [weak self] in
                self?.presentSheet(PracticeLogEditorViewController(session: nil))
            }
            monthsStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 300).isActive = true
            return
        }

        let grouped = Dictionary(grouping: sessions) { $0.date.startOfDay }
        let days = grouped.keys.sorted(by: >)

        for day in days {
            guard let items = grouped[day] else { continue }
            let dayMinutes = items.reduce(0) { $0 + $1.minutes }

            let label = UILabel()
            label.text = day.dayLabel
            label.font = .dancte(15, .bold)
            label.textColor = Palette.text

            let total = UILabel()
            total.text = Format.minutes(dayMinutes)
            total.font = .dancteMono(12.5, .bold)
            total.textColor = Palette.lime
            total.textAlignment = .right

            let header = UIStackView(arrangedSubviews: [label, UIView(), total])
            header.axis = .horizontal
            header.spacing = 10

            let column = UIStackView(arrangedSubviews: [header])
            column.axis = .vertical
            column.spacing = 8

            for session in items.sorted(by: { $0.date > $1.date }) {
                let row = SessionRowView(session: session)
                row.onTap = { [weak self] in
                    self?.navigationController?.pushViewController(SessionDetailViewController(sessionID: session.id), animated: true)
                }
                column.addArrangedSubview(row)
            }
            monthsStack.addArrangedSubview(column)
        }
    }
}
