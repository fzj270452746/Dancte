import UIKit

// MARK: - Session row

final class SessionRowView: RowControl {

    var onTap: (() -> Void)?

    init(session: PracticeSession, showsDate: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.5)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.withAlphaComponent(0.7).cgColor

        let tile = UIView()
        tile.translatesAutoresizingMaskIntoConstraints = false
        tile.backgroundColor = session.style.accent.withAlphaComponent(0.18)
        tile.layer.cornerRadius = 14
        tile.layer.cornerCurve = .continuous

        let icon = UIImageView(image: UIImage(systemName: session.style.symbol, withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)))
        icon.tintColor = session.style.accent
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubviews(icon)

        let title = UILabel()
        title.text = showsDate
            ? "\(session.style.title) · \(session.date.dayLabel)"
            : session.style.title
        title.font = .dancte(15.5, .bold)
        title.textColor = Palette.text

        let drills = session.drills.isEmpty
            ? (session.notes.isEmpty ? "No drills recorded" : session.notes)
            : session.drills.joined(separator: " · ")
        let detail = UILabel()
        detail.text = drills
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 1

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let minutes = UILabel()
        minutes.text = Format.minutes(session.minutes)
        minutes.font = .dancteMono(14, .black)
        minutes.textColor = session.style.accent
        minutes.setContentHuggingPriority(.required, for: .horizontal)
        minutes.textAlignment = .right

        let moodIcon = UIImageView(image: UIImage(systemName: session.mood.symbol, withConfiguration:
                                                    UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
        moodIcon.tintColor = session.mood.accent
        moodIcon.setContentHuggingPriority(.required, for: .horizontal)
        moodIcon.translatesAutoresizingMaskIntoConstraints = false
        moodIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let trailing = UIStackView(arrangedSubviews: [minutes, moodIcon])
        trailing.axis = .horizontal
        trailing.spacing = 8
        trailing.alignment = .center

        addSubviews(tile, text, trailing)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
            tile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            tile.centerYAnchor.constraint(equalTo: centerYAnchor),
            tile.widthAnchor.constraint(equalToConstant: 40),
            tile.heightAnchor.constraint(equalToConstant: 40),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 12),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            trailing.leadingAnchor.constraint(greaterThanOrEqualTo: text.trailingAnchor, constant: 8),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            trailing.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onTap?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
            }
        }
    }
}

// MARK: - Plan card

final class PlanProgressCard: RowControl {

    var onTap: (() -> Void)?

    init(plan: PracticePlan) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let progress = store.planProgress(plan)
        let minuteRatio = min(1, CGFloat(progress.minutes) / CGFloat(max(plan.weeklyMinuteTarget, 1)))
        let sessionRatio = min(1, CGFloat(progress.sessions) / CGFloat(max(plan.weeklySessionTarget, 1)))
        let overall = (minuteRatio + sessionRatio) / 2

        let card = SurfaceCard(colors: [plan.style.accent.withAlphaComponent(0.16), Palette.surface],
                               radius: 26, border: plan.style.accent.withAlphaComponent(0.4))
        addSubviews(card)
        card.pinEdges(to: self)

        let ring = ProgressRingView(size: 76, lineWidth: 9, accent: plan.style.accent)
        let percent = UILabel()
        percent.text = "\(Int(overall * 100))%"
        percent.font = .dancte(17, .black)
        percent.adjustsFontSizeToFitWidth = true
        percent.minimumScaleFactor = 0.6
        percent.textColor = Palette.text
        percent.textAlignment = .center
        ring.setCenter(percent)
        ring.setProgress(overall)

        let title = UILabel()
        title.text = plan.title
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text

        let style = UILabel()
        style.attributedText = NSAttributedString(
            string: "\(plan.style.title.uppercased()) · ENDS \(plan.endDate.dayLabel.uppercased())",
            attributes: [.kern: 1.1, .font: UIFont.dancte(9.5, .bold), .foregroundColor: plan.style.accent]
        )

        let focus = UILabel()
        focus.text = plan.focus
        focus.font = Typo.caption
        focus.textColor = Palette.textMuted
        focus.numberOfLines = 2

        let metrics = UILabel()
        metrics.attributedText = NSAttributedString(
            string: "\(Format.minutes(progress.minutes)) of \(Format.minutes(plan.weeklyMinuteTarget)) · \(progress.sessions)/\(plan.weeklySessionTarget) sessions",
            attributes: [.font: UIFont.dancteMono(11.5, .semibold), .foregroundColor: Palette.textFaint]
        )
        metrics.numberOfLines = 1

        let text = UIStackView(arrangedSubviews: [style, title, focus, metrics])
        text.axis = .vertical
        text.spacing = 3
        text.setCustomSpacing(8, after: focus)

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

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onTap?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Move row

final class MoveRowView: RowControl {

    var onOpen: (() -> Void)?
    var onAdvance: (() -> Void)?
    var onEdit: (() -> Void)?

    init(move: MoveSkill, showsAdvance: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Palette.surfaceHi.withAlphaComponent(0.5)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Palette.stroke.withAlphaComponent(0.7).cgColor

        let name = UILabel()
        name.text = move.name
        name.font = .dancte(15.5, .bold)
        name.textColor = Palette.text

        let detail = UILabel()
        detail.text = "\(move.style.title) · \(move.reps) rep\(move.reps == 1 ? "" : "s")"
        detail.font = Typo.caption
        detail.textColor = Palette.textFaint

        let text = UIStackView(arrangedSubviews: [name, detail])
        text.axis = .vertical
        text.spacing = 2

        let stageChip = ChipView(text: move.stage.title, accent: move.style.accent, horizontalPadding: 10, fontSize: 10.5)
        stageChip.isOn = move.stage == .battleReady
        stageChip.setContentHuggingPriority(.required, for: .horizontal)

        let tracker = MoveStageTrack(stage: move.stage, accent: move.style.accent)

        let advance = IconButton(symbol: "arrow.up.right", size: 32,
                                 background: move.stage.next == nil ? .glass : .gradient(Grad.forColor(move.style.accent)),
                                 pointSize: 12)
        advance.isHidden = !showsAdvance || move.stage.next == nil
        advance.onTap = { [weak self] in self?.onAdvance?() }

        let more = IconButton(symbol: "ellipsis", size: 32, background: .clear, tint: Palette.textFaint, pointSize: 13)
        more.onTap = { [weak self] in self?.onEdit?() }

        let trackerRow = UIStackView(arrangedSubviews: [tracker, stageChip])
        trackerRow.axis = .horizontal
        trackerRow.spacing = 10
        trackerRow.alignment = .center
        tracker.translatesAutoresizingMaskIntoConstraints = false
        tracker.widthAnchor.constraint(equalToConstant: 78).isActive = true

        let right = UIStackView(arrangedSubviews: [advance, more])
        right.axis = .horizontal
        right.spacing = 6
        right.alignment = .center
        right.setContentHuggingPriority(.required, for: .horizontal)

        addSubviews(text, trackerRow, right)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 66),
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            trackerRow.leadingAnchor.constraint(greaterThanOrEqualTo: text.trailingAnchor, constant: 10),
            trackerRow.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.leadingAnchor.constraint(equalTo: trackerRow.trailingAnchor, constant: 10),
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            right.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onOpen?()
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Four-segment progress meter used by the skill tree.
final class MoveStageTrack: UIView {

    init(stage: MoveStage, accent: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(axis: .horizontal, spacing: 3, distribution: .fillEqually)
        addSubviews(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 8)
        ])

        let reached = MoveStage.allCases.firstIndex(of: stage) ?? 0
        for index in 0..<MoveStage.allCases.count {
            let segment = UIView()
            segment.translatesAutoresizingMaskIntoConstraints = false
            segment.layer.cornerRadius = 3
            segment.backgroundColor = index <= reached ? accent : Palette.strokeHi.withAlphaComponent(0.4)
            stack.addArrangedSubview(segment)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Studio dashboard

/// The cockpit the whole app is built around: what you did today, how the week
/// is tracking against your goals, which plan is running, which moves are
/// closing in on Battle Ready, and where the hours have gone.
final class StudioViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let signedOutCard = UIView()
    private let heroContainer = UIView()
    private let todayContainer = UIView()
    private let boardContainer = UIView()
    private let plansStack = UIStackView(axis: .vertical, spacing: 12)
    private let stagesStack = UIStackView(axis: .vertical, spacing: 10)
    private let movesStack = UIStackView(axis: .vertical, spacing: 10)
    private let sessionsStack = UIStackView(axis: .vertical, spacing: 10)

    private var tiles: (UIStackView, UIStackView)?
    private var weekBoard: WeekBoardView!
    private var weekTotal: UILabel!
    private var weekDetail: UILabel!
    private var sparkline: SparklineView!
    private weak var headerSubtitle: UILabel?

    /// Sections that only make sense once somebody is signed in, and the single
    /// one that replaces them all when nobody is.
    private var signedInSections: [UIView] = []
    private var signedOutSections: [UIView] = []

    private static let bottomInset = MainTabBarController.contentBottomInset + 24

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        scroll.setTopPadding(8)
        scroll.setBottomPadding(Self.bottomInset)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        buildHeader()
        buildSignedOut()

        addSignedIn(heroContainer.gutterPadded())
        addSignedIn(makeTodaySection().gutterPadded())
        addSignedIn(makeBoardSection().gutterPadded())
        addSignedIn(makePlansSection().gutterPadded())
        addSignedIn(makeSkillSection().gutterPadded())
        addSignedIn(makeInsightsSection().gutterPadded())
        addSignedIn(makeSessionsSection().gutterPadded())

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .danctePractice, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .dancteAuth, object: nil)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Build

    private func addSignedIn(_ view: UIView) {
        scroll.add(view)
        signedInSections.append(view)
    }

    private func buildHeader() {
        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: "YOUR PRACTICE", attributes: [
            .kern: 2.2, .font: UIFont.dancte(10.5, .black), .foregroundColor: Palette.lime
        ])

        let title = UILabel()
        title.text = "Studio"
        title.font = .dancte(34, .black)
        title.textColor = Palette.text

        let subtitle = UILabel()
        subtitle.font = Typo.caption
        subtitle.textColor = Palette.textMuted
        subtitle.numberOfLines = 2
        headerSubtitle = subtitle

        let column = UIStackView(arrangedSubviews: [eyebrow, title, subtitle])
        column.axis = .vertical
        column.spacing = 4
        column.setCustomSpacing(8, after: eyebrow)
        column.setCustomSpacing(6, after: title)
        scroll.add(column.gutterPadded())
    }

    private func buildSignedOut() {
        let mark = BrandMarkView(size: 66)

        let title = UILabel()
        title.text = "Your training log lives here"
        title.font = .dancte(24, .black)
        title.textColor = Palette.text
        title.textAlignment = .center
        title.numberOfLines = 2

        let message = UILabel()
        message.text = "Record every session, run timed drills, hold a weekly plan and watch each move climb from Discovered to Battle Ready."
        message.font = Typo.body
        message.textColor = Palette.textMuted
        message.textAlignment = .center
        message.numberOfLines = 0

        let perks: [(String, String, String, UIColor)] = [
            ("timer", "Timed sessions", "Run drills against the clock and log the result in one tap.", Palette.lime),
            ("target", "Weekly plans", "Set the minutes and sessions you're chasing, then hold yourself to them.", Palette.blaze),
            ("list.bullet.rectangle.fill", "Skill tree", "Track every move you're drilling and what it still needs.", Palette.violet),
            ("chart.bar.fill", "Honest numbers", "Streaks, style splits and the days you actually showed up.", Palette.cyan)
        ]

        let perkStack = UIStackView(arrangedSubviews: perks.map {
            makePerkRow(symbol: $0.0, headline: $0.1, detail: $0.2, accent: $0.3)
        })
        perkStack.axis = .vertical
        perkStack.spacing = 14

        let signIn = PillButton("Sign In", symbol: "arrow.right", style: .primary)
        signIn.onTap = { [weak self] in
            guard let self else { return }
            AuthGate.require(.studio, from: self) { self.reload() }
        }

        let column = UIStackView(arrangedSubviews: [mark, title, message, perkStack, signIn])
        column.axis = .vertical
        column.spacing = 14
        column.alignment = .center
        column.setCustomSpacing(20, after: mark)
        column.setCustomSpacing(22, after: message)
        column.setCustomSpacing(26, after: perkStack)

        signedOutCard.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: signedOutCard.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: signedOutCard.trailingAnchor),
            column.topAnchor.constraint(equalTo: signedOutCard.topAnchor, constant: 24),
            column.bottomAnchor.constraint(equalTo: signedOutCard.bottomAnchor, constant: -12),
            signIn.widthAnchor.constraint(equalToConstant: 220)
        ])

        let wrapper = signedOutCard.gutterPadded()
        scroll.add(wrapper)
        signedOutSections = [wrapper]
    }

    private func makePerkRow(symbol: String, headline: String, detail: String, accent: UIColor) -> UIView {
        let tile = UIView()
        tile.backgroundColor = accent.withAlphaComponent(0.16)
        tile.layer.cornerRadius = 13
        tile.layer.cornerCurve = .continuous
        tile.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)))
        icon.tintColor = accent
        icon.contentMode = .center
        tile.addSubviews(icon)

        let title = UILabel()
        title.text = headline
        title.font = .dancte(14.5, .bold)
        title.textColor = Palette.text

        let caption = UILabel()
        caption.text = detail
        caption.font = Typo.caption
        caption.textColor = Palette.textMuted
        caption.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [title, caption])
        text.axis = .vertical
        text.spacing = 1

        let row = UIView()
        row.addSubviews(tile, text)
        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            tile.topAnchor.constraint(equalTo: row.topAnchor),
            tile.widthAnchor.constraint(equalToConstant: 38),
            tile.heightAnchor.constraint(equalToConstant: 38),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),

            text.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            text.topAnchor.constraint(equalTo: row.topAnchor),
            text.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
        return row
    }

    private func makeTodaySection() -> UIView {
        let header = SectionHeader(eyebrow: "Right now", title: "Today", actionTitle: "Log a session")
        header.onAction = { [weak self] in self?.presentLogEditor() }
        let column = UIStackView(arrangedSubviews: [header, todayContainer])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    private func makeBoardSection() -> UIView {
        let header = SectionHeader(eyebrow: "Planned against actual", title: "Training board",
                                   actionTitle: "Edit goal")
        header.onAction = { [weak self] in self?.presentGoalEditor() }

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        let column = UIStackView(axis: .vertical, spacing: 16)

        weekTotal = UILabel()
        weekTotal.font = .dancte(28, .black)
        weekTotal.textColor = Palette.text
        weekDetail = UILabel()
        weekDetail.font = Typo.caption
        weekDetail.textColor = Palette.textMuted
        weekDetail.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [weekTotal, weekDetail])
        text.axis = .vertical
        text.spacing = 2

        let top = UIStackView(arrangedSubviews: [text, UIView()])
        top.axis = .horizontal
        top.alignment = .top

        weekBoard = WeekBoardView(accent: Palette.lime)

        column.addArrangedSubview(top)
        column.addArrangedSubview(weekBoard)

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        let stack = UIStackView(arrangedSubviews: [header, card, boardContainer])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }

    private func makePlansSection() -> UIView {
        let header = SectionHeader(eyebrow: "Focused work", title: "Plans", actionTitle: "All plans")
        header.onAction = { [weak self] in
            self?.navigationController?.pushViewController(PlanCenterViewController(), animated: true)
        }
        let column = UIStackView(arrangedSubviews: [header, plansStack])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    private func makeSkillSection() -> UIView {
        let header = SectionHeader(eyebrow: "Move by move", title: "Skill tree", actionTitle: "See all")
        header.onAction = { [weak self] in
            self?.navigationController?.pushViewController(SkillTreeViewController(), animated: true)
        }

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        card.addSubviews(stagesStack)
        NSLayoutConstraint.activate([
            stagesStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stagesStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stagesStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stagesStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        let column = UIStackView(arrangedSubviews: [header, card, movesStack])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    private func makeInsightsSection() -> UIView {
        let header = SectionHeader(eyebrow: "All time", title: "Your numbers", actionTitle: "Insights")
        header.onAction = { [weak self] in
            self?.navigationController?.pushViewController(InsightsViewController(), animated: true)
        }

        let grid = UIStackView(axis: .vertical, spacing: 10)
        let row1 = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
        let row2 = UIStackView(axis: .horizontal, spacing: 10, distribution: .fillEqually)
        grid.addArrangedSubview(row1)
        grid.addArrangedSubview(row2)
        tiles = (row1, row2)

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        let trendTitle = UILabel()
        trendTitle.attributedText = NSAttributedString(string: "MINUTES PER WEEK · LAST 8 WEEKS", attributes: [
            .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint
        ])
        sparkline = SparklineView(accent: Palette.violet)
        sparkline.translatesAutoresizingMaskIntoConstraints = false
        sparkline.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let stack = UIStackView(arrangedSubviews: [trendTitle, sparkline])
        stack.axis = .vertical
        stack.spacing = 10
        card.addSubviews(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        let column = UIStackView(arrangedSubviews: [header, grid, card])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    private func makeSessionsSection() -> UIView {
        let header = SectionHeader(eyebrow: "Recent work", title: "Latest sessions", actionTitle: "History")
        header.onAction = { [weak self] in
            self?.navigationController?.pushViewController(PracticeHistoryViewController(), animated: true)
        }
        let column = UIStackView(arrangedSubviews: [header, sessionsStack])
        column.axis = .vertical
        column.spacing = 14
        return column
    }

    // MARK: - Render

    @objc private func reload() {
        let signedIn = store.isSignedIn
        signedOutSections.forEach { $0.isHidden = signedIn }
        signedInSections.forEach { $0.isHidden = !signedIn }
        guard signedIn else {
            headerSubtitle?.text = "Your sessions, plans and moves — all in one place."
            return
        }

        let stats = store.stats
        headerSubtitle?.text = stats.totalSessions == 0
            ? "Nothing logged yet. Start the clock and the rest fills in."
            : "\(stats.totalSessions) sessions · \(Format.longDuration(Double(stats.totalMinutes * 60))) on the floor."

        buildHero(stats)
        buildToday(stats)
        buildBoard(stats)
        buildPlans()
        buildSkill()
        buildInsights(stats)
        buildSessions()
    }

    private func buildHero(_ stats: PracticeStats) {
        heroContainer.subviews.forEach { $0.removeFromSuperview() }

        let card = SurfaceCard(colors: [Palette.blaze.withAlphaComponent(0.2), UIColor(hex: 0x12151D)],
                               radius: 30, border: Palette.blaze.withAlphaComponent(0.4), glow: Palette.blaze)
        heroContainer.addSubviews(card)
        card.pinEdges(to: heroContainer)

        let flame = UIImageView(image: UIImage(systemName: "flame.fill", withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)))
        flame.tintColor = Palette.blaze

        let streakValue = UILabel()
        streakValue.text = "\(stats.currentStreak)"
        streakValue.font = .dancte(54, .black)
        streakValue.textColor = Palette.text
        streakValue.adjustsFontSizeToFitWidth = true
        streakValue.minimumScaleFactor = 0.6

        let streakCaption = UILabel()
        streakCaption.attributedText = NSAttributedString(string: "DAY STREAK", attributes: [
            .kern: 2, .font: UIFont.dancte(10.5, .black), .foregroundColor: Palette.blaze
        ])

        let best = UILabel()
        best.text = stats.totalSessions == 0
            ? "Log your first session and your streak starts today."
            : "Best run \(stats.longestStreak) days · \(stats.activeDays) active days"
        best.font = Typo.caption
        best.textColor = Palette.textMuted
        best.numberOfLines = 2

        let left = UIStackView(arrangedSubviews: [flame, streakValue, streakCaption, best])
        left.axis = .vertical
        left.spacing = 0
        left.alignment = .leading
        left.setCustomSpacing(6, after: flame)
        left.setCustomSpacing(8, after: streakCaption)

        let goal = store.goals.weeklyMinuteTarget
        let ratio = min(1, CGFloat(stats.minutesThisWeek) / CGFloat(max(goal, 1)))
        let ring = ProgressRingView(size: 104, lineWidth: 11, accent: Palette.lime)
        let ringValue = UILabel()
        ringValue.text = "\(Int(ratio * 100))%"
        ringValue.font = .dancte(21, .black)
        ringValue.textColor = Palette.text
        ringValue.textAlignment = .center
        ringValue.adjustsFontSizeToFitWidth = true
        ringValue.minimumScaleFactor = 0.6
        let ringCaption = UILabel()
        ringCaption.attributedText = NSAttributedString(string: "OF WEEKLY GOAL", attributes: [
            .kern: 1, .font: UIFont.dancte(8, .bold), .foregroundColor: Palette.textFaint
        ])
        ringCaption.textAlignment = .center
        ringCaption.numberOfLines = 2
        let ringStack = UIStackView(arrangedSubviews: [ringCaption, ringValue])
        ringStack.axis = .vertical
        ringStack.spacing = 1
        ringStack.alignment = .center
        ring.setCenter(ringStack)
        ring.setProgress(stats.totalSessions == 0 ? 0 : ratio)

        let topRow = UIStackView(arrangedSubviews: [left, ring])
        topRow.axis = .horizontal
        topRow.spacing = 16
        topRow.alignment = .center
        ring.setContentHuggingPriority(.required, for: .horizontal)

        let start = PillButton("Start Training", symbol: "play.fill", style: .primary, height: 48)
        start.onTap = { [weak self] in self?.presentLiveTraining() }
        let log = PillButton("Log Session", symbol: "plus", style: .outline, height: 48)
        log.onTap = { [weak self] in self?.presentLogEditor() }

        let buttons = UIStackView(arrangedSubviews: [start, log])
        buttons.axis = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually

        let column = UIStackView(arrangedSubviews: [topRow, buttons])
        column.axis = .vertical
        column.spacing = 18

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22)
        ])
    }

    private func buildToday(_ stats: PracticeStats) {
        todayContainer.subviews.forEach { $0.removeFromSuperview() }

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        todayContainer.addSubviews(card)
        card.pinEdges(to: todayContainer)

        let logged = stats.loggedToday
        let accent = logged ? Palette.lime : Palette.textFaint

        let tile = UIView()
        tile.backgroundColor = accent.withAlphaComponent(0.16)
        tile.layer.cornerRadius = 14
        tile.layer.cornerCurve = .continuous
        tile.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: logged ? "checkmark.seal.fill" : "circle.dashed",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .bold)))
        icon.tintColor = accent
        icon.contentMode = .center
        tile.addSubviews(icon)

        let todaySessions = store.sessions(on: Date())

        let title = UILabel()
        title.text = logged ? "Logged · \(Format.minutes(stats.minutesToday))" : "Nothing logged today"
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text

        let detail = UILabel()
        if logged {
            let drills = Array(Set(todaySessions.flatMap(\.drills))).sorted()
            detail.text = drills.isEmpty
                ? "\(todaySessions.count) session\(todaySessions.count == 1 ? "" : "s") on the board."
                : drills.joined(separator: " · ")
        } else {
            detail.text = "The streak only counts days you actually train."
        }
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [tile, text])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 42),
            tile.heightAnchor.constraint(equalToConstant: 42),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
        ])

        var rows: [UIView] = [row]

        if let plan = store.activePlans.first {
            let focusEyebrow = UILabel()
            focusEyebrow.attributedText = NSAttributedString(string: "TODAY'S FOCUS · \(plan.title.uppercased())", attributes: [
                .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: plan.style.accent
            ])
            let focus = UILabel()
            focus.text = plan.focus
            focus.font = Typo.callout
            focus.textColor = Palette.textMuted
            focus.numberOfLines = 3

            let divider = SeamView(color: Palette.stroke.withAlphaComponent(0.7))
            let focusStack = UIStackView(arrangedSubviews: [divider, focusEyebrow, focus])
            focusStack.axis = .vertical
            focusStack.spacing = 6
            focusStack.setCustomSpacing(12, after: divider)
            rows.append(focusStack)
        }

        let column = UIStackView(arrangedSubviews: rows)
        column.axis = .vertical
        column.spacing = 14

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
    }

    private func buildBoard(_ stats: PracticeStats) {
        weekBoard.setData(store.weekBoard())

        let goal = store.goals
        weekTotal.text = Format.minutes(stats.minutesThisWeek)
        let hit = stats.sessionsThisWeek >= goal.weeklySessionTarget
        weekDetail.text = "\(stats.sessionsThisWeek) of \(goal.weeklySessionTarget) sessions · goal \(Format.minutes(goal.weeklyMinuteTarget))\(hit ? " · target hit" : "")"

        boardContainer.subviews.forEach { $0.removeFromSuperview() }

        let rest = goal.restDays.isEmpty
            ? "No rest days set"
            : "Rest days: \(goal.restDays.sorted().map(Self.weekdayName).joined(separator: ", "))"
        let caption = UILabel()
        caption.text = "\(rest) · focus \(goal.focusStyle.title)"
        caption.font = Typo.caption
        caption.textColor = Palette.textFaint
        caption.numberOfLines = 2

        boardContainer.addSubviews(caption)
        caption.pinEdges(to: boardContainer)
    }

    private static func weekdayName(_ weekday: Int) -> String {
        ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][safe: weekday] ?? "—"
    }

    private func buildPlans() {
        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let plans = Array(store.activePlans.prefix(2))

        guard !plans.isEmpty else {
            let empty = EmptyStateView(symbol: "target",
                                       title: "No plan running",
                                       message: "Start from a preset programme or write your own weekly target and hold yourself to it.",
                                       actionTitle: "Browse templates",
                                       compact: true)
            empty.onAction = { [weak self] in
                self?.navigationController?.pushViewController(PlanTemplatesViewController(), animated: true)
            }
            plansStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 280).isActive = true
            return
        }

        for plan in plans {
            let card = PlanProgressCard(plan: plan)
            card.onTap = { [weak self] in
                self?.navigationController?.pushViewController(PlanDetailViewController(planID: plan.id), animated: true)
            }
            plansStack.addArrangedSubview(card)
        }
    }

    private func buildSkill() {
        stagesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        movesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let moves = store.moves
        let total = max(moves.count, 1)
        for entry in store.stageCounts() {
            let accent = entry.stage.accent
            let row = RatioBarRow(caption: entry.stage.title, value: "\(entry.count)", accent: accent)
            row.configure(caption: entry.stage.title,
                          value: "\(entry.count)",
                          ratio: CGFloat(entry.count) / CGFloat(total),
                          accent: accent)
            stagesStack.addArrangedSubview(row)
        }

        let top = Array(moves.sorted { $0.reps > $1.reps }.prefix(3))
        guard !top.isEmpty else {
            let empty = EmptyStateView(symbol: "list.bullet.rectangle",
                                       title: "Your skill tree is empty",
                                       message: "Add the moves you're drilling and move them from Discovered to Battle Ready as they land.",
                                       actionTitle: "Open skill tree",
                                       compact: true)
            empty.onAction = { [weak self] in
                self?.navigationController?.pushViewController(SkillTreeViewController(), animated: true)
            }
            movesStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 260).isActive = true
            return
        }

        for move in top {
            let row = MoveRowView(move: move)
            row.onOpen = { [weak self] in
                self?.navigationController?.pushViewController(MoveDetailViewController(moveID: move.id), animated: true)
            }
            row.onAdvance = { [weak self] in
                store.advance(move.id)
                Haptics.success()
                if let next = move.stage.next {
                    Toast.success("\(move.name) → \(next.title)")
                }
                self?.reload()
            }
            row.onEdit = { [weak self] in self?.presentMoveActions(move) }
            movesStack.addArrangedSubview(row)
        }
    }

    private func buildInsights(_ stats: PracticeStats) {
        guard let tiles else { return }
        tiles.0.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tiles.1.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let first: [(String, String, UIColor, String)] = [
            (Format.longDuration(Double(stats.totalMinutes * 60)), "Total time", Palette.lime, "clock.fill"),
            ("\(stats.totalSessions)", "Sessions", Palette.cyan, "checkmark.circle.fill")
        ]
        let second: [(String, String, UIColor, String)] = [
            (Format.minutes(stats.averageMinutes), "Average", Palette.violet, "chart.bar.fill"),
            ("\(stats.activeDays)", "Active days", Palette.amber, "calendar")
        ]

        for item in first {
            tiles.0.addArrangedSubview(StatTile(value: item.0, caption: item.1, accent: item.2, symbol: item.3))
        }
        for item in second {
            tiles.1.addArrangedSubview(StatTile(value: item.0, caption: item.1, accent: item.2, symbol: item.3))
        }

        sparkline.setValues(store.weeklySeries(weeks: 8).map { CGFloat($0.minutes) })
    }

    private func buildSessions() {
        sessionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let sessions = Array(store.sessions.prefix(3))
        guard !sessions.isEmpty else {
            let empty = EmptyStateView(symbol: "plus.circle",
                                       title: "No sessions logged",
                                       message: "Every session you record feeds your streak, your weekly board and your style breakdown.",
                                       actionTitle: "Log a session",
                                       compact: true)
            empty.onAction = { [weak self] in self?.presentLogEditor() }
            sessionsStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 270).isActive = true
            return
        }
        for session in sessions {
            let row = SessionRowView(session: session, showsDate: true)
            row.onTap = { [weak self] in
                self?.navigationController?.pushViewController(SessionDetailViewController(sessionID: session.id), animated: true)
            }
            sessionsStack.addArrangedSubview(row)
        }
    }

    // MARK: - Actions

    private func presentLiveTraining() {
        presentSheet(PracticeLiveViewController())
    }

    private func presentLogEditor(editing session: PracticeSession? = nil) {
        presentSheet(PracticeLogEditorViewController(session: session))
    }

    private func presentGoalEditor() {
        presentSheet(GoalEditorViewController())
    }

    private func presentMoveActions(_ move: MoveSkill) {
        let sheet = UIAlertController(title: move.name, message: "\(move.style.title) · \(move.stage.title)", preferredStyle: .actionSheet)
        if let next = move.stage.next {
            sheet.addAction(UIAlertAction(title: "Move to \(next.title)", style: .default) { [weak self] _ in
                store.advance(move.id)
                Haptics.success()
                self?.reload()
            })
        }
        sheet.addAction(UIAlertAction(title: "Open move", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(MoveDetailViewController(moveID: move.id), animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Delete Move", style: .destructive) { [weak self] _ in
            store.deleteMove(move.id)
            Toast.show("Move removed")
            self?.reload()
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
