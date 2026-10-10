import UIKit

/// One plan in full: how the current week is going, how every week so far went,
/// which moves it is built around, and the shortest path to logging against it.
final class PlanDetailViewController: UIViewController {

    private let planID: String
    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let headerContainer = UIView()
    private let adherenceContainer = UIView()
    private let weeksStack = UIStackView(axis: .vertical, spacing: 12)
    private let movesStack = UIStackView(axis: .vertical, spacing: 10)

    init(planID: String) {
        self.planID = planID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        installBrandBackButton()
        styleNavigationBar(title: store.plan(planID)?.title ?? "Plan")

        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                   style: .plain, target: self, action: #selector(presentActions))
        more.tintColor = Palette.text
        navigationItem.rightBarButtonItem = more

        scroll.setTopPadding(12)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        scroll.add(headerContainer.gutterPadded())
        scroll.add(adherenceContainer.gutterPadded())
        scroll.add(section(eyebrow: "Week by week", title: "How it's going", stack: weeksStack))
        scroll.add(section(eyebrow: "Built around", title: "Focus moves", stack: movesStack))

        let log = PillButton("Log a Session", symbol: "plus", style: .primary)
        log.onTap = { [weak self] in self?.presentLogEditor() }
        scroll.add(log.gutterPadded())

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .danctePractice, object: nil)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func section(eyebrow: String, title: String, stack: UIStackView) -> UIView {
        let header = SectionHeader(eyebrow: eyebrow, title: title)
        let column = UIStackView(arrangedSubviews: [header, stack])
        column.axis = .vertical
        column.spacing = 14
        return column.gutterPadded()
    }

    // MARK: - Render

    @objc private func reload() {
        guard let plan = store.plan(planID) else {
            navigationController?.popViewController(animated: true)
            return
        }
        buildHeader(plan)
        buildAdherence(plan)
        buildWeeks(plan)
        buildMoves(plan)
    }

    private func buildHeader(_ plan: PracticePlan) {
        headerContainer.subviews.forEach { $0.removeFromSuperview() }

        let accent = plan.style.accent
        let card = SurfaceCard(colors: [accent.withAlphaComponent(0.18), Palette.surface],
                               radius: 28, border: accent.withAlphaComponent(0.4))
        headerContainer.addSubviews(card)
        card.pinEdges(to: headerContainer)

        let chip = ChipView(text: plan.style.title, symbol: plan.style.symbol, accent: accent,
                            horizontalPadding: 12, fontSize: 12)
        chip.isOn = true
        chip.setContentHuggingPriority(.required, for: .horizontal)

        let status = ChipView(text: plan.isFinished ? "Finished" : "Week \(plan.currentWeek) of \(plan.totalWeeks)",
                              accent: plan.isFinished ? Palette.textFaint : Palette.lime,
                              horizontalPadding: 12, fontSize: 12)
        status.setContentHuggingPriority(.required, for: .horizontal)

        let chips = UIStackView(arrangedSubviews: [chip, status, UIView()])
        chips.axis = .horizontal
        chips.spacing = 8

        let title = UILabel()
        title.text = plan.title
        title.font = .dancte(26, .black)
        title.textColor = Palette.text
        title.numberOfLines = 2

        let focus = UILabel()
        focus.text = plan.focus
        focus.font = Typo.body
        focus.textColor = Palette.textMuted
        focus.numberOfLines = 0

        let dates = UILabel()
        dates.attributedText = NSAttributedString(
            string: "\(plan.startDate.dayLabel.uppercased()) → \(plan.endDate.dayLabel.uppercased()) · \(plan.isFinished ? "COMPLETE" : "\(plan.daysRemaining) DAYS LEFT")",
            attributes: [.kern: 1.1, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint]
        )

        let column = UIStackView(arrangedSubviews: [chips, title, focus, dates])
        column.axis = .vertical
        column.spacing = 10
        column.setCustomSpacing(14, after: chips)

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    private func buildAdherence(_ plan: PracticePlan) {
        adherenceContainer.subviews.forEach { $0.removeFromSuperview() }

        let progress = store.planProgress(plan)
        let minuteRatio = min(1, CGFloat(progress.minutes) / CGFloat(max(plan.weeklyMinuteTarget, 1)))
        let sessionRatio = min(1, CGFloat(progress.sessions) / CGFloat(max(plan.weeklySessionTarget, 1)))
        let overall = (minuteRatio + sessionRatio) / 2
        let adherence = store.adherence(for: plan)

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        adherenceContainer.addSubviews(card)
        card.pinEdges(to: adherenceContainer)

        let ring = ProgressRingView(size: 96, lineWidth: 10, accent: plan.style.accent)
        let percent = UILabel()
        percent.text = "\(Int(overall * 100))%"
        percent.font = .dancte(21, .black)
        percent.textColor = Palette.text
        percent.textAlignment = .center
        percent.adjustsFontSizeToFitWidth = true
        percent.minimumScaleFactor = 0.6
        ring.setCenter(percent)
        ring.setProgress(overall)

        let thisWeek = UILabel()
        thisWeek.text = "This week"
        thisWeek.font = .dancte(17, .bold)
        thisWeek.textColor = Palette.text

        let detail = UILabel()
        detail.text = "\(Format.minutes(progress.minutes)) of \(Format.minutes(plan.weeklyMinuteTarget)) · \(progress.sessions) of \(plan.weeklySessionTarget) sessions"
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let history = UILabel()
        history.attributedText = NSAttributedString(
            string: "WEEKS THAT HIT THE TARGET · \(Int(adherence * 100))%",
            attributes: [.kern: 1.2, .font: UIFont.dancte(9.5, .bold), .foregroundColor: plan.style.accent]
        )

        let text = UIStackView(arrangedSubviews: [thisWeek, detail, history])
        text.axis = .vertical
        text.spacing = 4
        text.setCustomSpacing(12, after: detail)

        let row = UIStackView(arrangedSubviews: [ring, text])
        row.axis = .horizontal
        row.spacing = 16
        row.alignment = .center
        ring.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
    }

    private func buildWeeks(_ plan: PracticePlan) {
        weeksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let weeks = store.weeklyBreakdown(for: plan)
        guard !weeks.isEmpty else {
            let label = UILabel()
            label.text = "This plan hasn't started yet."
            label.font = Typo.caption
            label.textColor = Palette.textFaint
            weeksStack.addArrangedSubview(label)
            return
        }

        let currentWeekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start

        for week in weeks.reversed() {
            let isCurrent = week.weekStart == currentWeekStart
            let isFuture = week.weekStart > Date().startOfDay
            let ratio = min(1, CGFloat(week.minutes) / CGFloat(max(week.target, 1)))
            let accent = week.minutes >= week.target ? Palette.lime : plan.style.accent

            let row = RatioBarRow(caption: "Week of \(Self.weekLabel(week.weekStart))",
                                  value: "\(week.minutes)/\(week.target)",
                                  accent: accent,
                                  captionWidth: 108)
            row.configure(caption: "Week of \(Self.weekLabel(week.weekStart))",
                          value: "\(week.minutes)/\(week.target)",
                          ratio: isFuture ? 0 : ratio,
                          accent: accent)

            let status = UILabel()
            status.font = .dancte(10.5, .bold)
            if isFuture {
                status.text = "UPCOMING"
                status.textColor = Palette.textFaint
            } else if isCurrent {
                status.text = "IN PROGRESS"
                status.textColor = Palette.cyan
            } else if week.minutes >= week.target {
                status.text = "HIT"
                status.textColor = Palette.lime
            } else {
                status.text = "SHORT"
                status.textColor = Palette.blaze
            }

            let column = UIStackView(arrangedSubviews: [row, status])
            column.axis = .vertical
            column.spacing = 2
            column.alignment = .leading
            weeksStack.addArrangedSubview(column)
        }
    }

    private static func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func buildMoves(_ plan: PracticePlan) {
        movesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let moves = store.moves(for: plan.style)
        guard !moves.isEmpty else {
            let empty = EmptyStateView(symbol: "list.bullet.rectangle",
                                       title: "No \(plan.style.title) moves tracked",
                                       message: "Add the moves this plan is about and they'll show up here with their stage.",
                                       actionTitle: "Open skill tree",
                                       compact: true)
            empty.onAction = { [weak self] in
                self?.navigationController?.pushViewController(SkillTreeViewController(), animated: true)
            }
            movesStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 250).isActive = true
            return
        }

        for move in moves.prefix(5) {
            let row = MoveRowView(move: move, showsAdvance: false)
            row.onOpen = { [weak self] in
                self?.navigationController?.pushViewController(MoveDetailViewController(moveID: move.id), animated: true)
            }
            row.onEdit = { [weak self] in self?.presentMoveEditor(move) }
            movesStack.addArrangedSubview(row)
        }
    }

    // MARK: - Actions

    private func presentLogEditor() {
        guard let plan = store.plan(planID) else { return }
        let draft = PracticeDraft(date: Date(),
                                  minutes: plan.weeklyMinuteTarget / max(plan.weeklySessionTarget, 1),
                                  style: plan.style,
                                  drills: Array(plan.style.commonDrills.prefix(3)),
                                  planID: plan.id)
        presentSheet(PracticeLogEditorViewController(prefill: draft))
    }

    private func presentMoveEditor(_ move: MoveSkill) {
        let editor = MoveEditorViewController(move: move, defaultStyle: move.style)
        editor.onSave = { [weak self] in self?.reload() }
        presentSheet(editor)
    }

    @objc private func presentActions() {
        guard let plan = store.plan(planID) else { return }
        let sheet = UIAlertController(title: plan.title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Edit Plan", style: .default) { [weak self] _ in
            self?.presentSheet(PracticePlanEditorViewController(plan: plan))
        })
        sheet.addAction(UIAlertAction(title: "Delete Plan", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.confirm(title: "Delete this plan?",
                         message: "The sessions you already logged stay in your history — they just stop counting towards this plan.",
                         confirmTitle: "Delete Plan") {
                store.deletePlan(plan.id)
                Toast.show("Plan deleted")
                self.navigationController?.popViewController(animated: true)
            }
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }
}
