import UIKit

/// The weekly targets the training board measures against, plus the days you
/// have decided not to train on.
final class GoalEditorViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let scroll = ContentColumn(spacing: 20, gutter: 0)
    private let navBar = UIView()
    private let closeButton = IconButton(symbol: "xmark", size: 40, background: .glass, pointSize: 15)

    private let minuteStepper = MinuteStepper(minutes: 240, tint: Palette.lime)
    private let sessionStack = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
    private let styleStack = UIStackView(axis: .horizontal, spacing: 8)
    private let restStack = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)

    private var sessionTarget = 4
    private var focusStyle: DanceStyle = .freestyle
    private var restDays: Set<Int> = []

    private static let weekdayNames = ["S", "M", "T", "W", "T", "F", "S"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        let current = store.goals
        sessionTarget = current.weeklySessionTarget
        focusStyle = current.focusStyle
        restDays = current.restDays
        minuteStepper.setValue(current.weeklyMinuteTarget)

        buildNav()
        scroll.setTopPadding(14)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        buildMinuteTarget()
        buildSessionTarget()
        buildFocusStyle()
        buildRestDays()
        buildSave()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)

        let title = UILabel()
        title.text = "Weekly Goals"
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text

        navBar.addSubviews(title, closeButton)
        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 52),

            closeButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: Metric.gutter),
            closeButton.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -4),

            title.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
        ])
        closeButton.onTap = { [weak self] in self?.dismiss(animated: true) }
    }

    private func section(eyebrow: String, title: String, hint: String? = nil) -> UIView {
        let header = SectionHeader(eyebrow: eyebrow, title: title)
        guard let hint else { return header }
        let label = UILabel()
        label.text = hint
        label.font = Typo.caption
        label.textColor = Palette.textFaint
        label.numberOfLines = 3
        let column = UIStackView(arrangedSubviews: [header, label])
        column.axis = .vertical
        column.spacing = 6
        return column
    }

    private func buildMinuteTarget() {
        scroll.add(section(eyebrow: "How much", title: "Minutes a week").gutterPadded())
        scroll.add(minuteStepper.gutterPadded())
    }

    private func buildSessionTarget() {
        scroll.add(section(eyebrow: "How often", title: "Sessions a week",
                           hint: "The board counts these against what you actually log.").gutterPadded())
        rebuildSessionChips()
        scroll.add(sessionStack.gutterPadded())
    }

    private func rebuildSessionChips() {
        sessionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for value in 1...7 {
            let chip = ChipView(text: "\(value)", accent: Palette.cyan, horizontalPadding: 0, fontSize: 15)
            chip.isOn = value == sessionTarget
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.sessionTarget = value
                self.rebuildSessionChips()
            }
            sessionStack.addArrangedSubview(chip)
        }
    }

    private func buildFocusStyle() {
        scroll.add(section(eyebrow: "What you're chasing", title: "Focus style",
                           hint: "Used for the style breakdown on the training board.").gutterPadded())
        rebuildStyleChips()

        let scroller = UIScrollView()
        scroller.translatesAutoresizingMaskIntoConstraints = false
        scroller.showsHorizontalScrollIndicator = false
        scroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        scroller.addSubviews(styleStack)
        NSLayoutConstraint.activate([
            styleStack.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            styleStack.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            styleStack.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
            styleStack.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
            styleStack.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
            scroller.heightAnchor.constraint(equalToConstant: 40)
        ])
        scroll.add(scroller)
    }

    private func rebuildStyleChips() {
        styleStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for candidate in DanceStyle.allCases {
            let chip = ChipView(text: candidate.title, symbol: candidate.symbol, accent: candidate.accent)
            chip.isOn = candidate == focusStyle
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.focusStyle = candidate
                self.rebuildStyleChips()
            }
            styleStack.addArrangedSubview(chip)
        }
    }

    private func buildRestDays() {
        scroll.add(section(eyebrow: "Days off", title: "Rest days",
                           hint: "Rest days are drawn hollow on the board and don't count against your weekly minutes.").gutterPadded())
        rebuildRestChips()
        scroll.add(restStack.gutterPadded())
    }

    private func rebuildRestChips() {
        restStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for weekday in 1...7 {
            let chip = ChipView(text: Self.weekdayNames[weekday - 1], accent: Palette.violet,
                                horizontalPadding: 0, fontSize: 15)
            chip.isOn = restDays.contains(weekday)
            chip.onTap = { [weak self] in
                guard let self else { return }
                if self.restDays.contains(weekday) {
                    self.restDays.remove(weekday)
                } else if self.restDays.count < 6 {
                    self.restDays.insert(weekday)
                } else {
                    Toast.warning("Leave at least one training day")
                    return
                }
                self.rebuildRestChips()
            }
            restStack.addArrangedSubview(chip)
        }
    }

    private func buildSave() {
        let save = PillButton("Save Goals", symbol: "checkmark", style: .primary)
        save.onTap = { [weak self] in
            guard let self else { return }
            let goals = PracticeGoals(weeklyMinuteTarget: self.minuteStepper.minutes,
                                      weeklySessionTarget: self.sessionTarget,
                                      focusStyle: self.focusStyle,
                                      restDays: self.restDays)
            store.saveGoals(goals)
            Haptics.success()
            Toast.success("Goals updated",
                          detail: "\(Format.minutes(goals.weeklyMinuteTarget)) · \(goals.weeklySessionTarget) sessions a week")
            self.dismiss(animated: true)
        }
        scroll.add(save.gutterPadded())
    }
}
