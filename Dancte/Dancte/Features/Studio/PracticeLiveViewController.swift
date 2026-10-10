import UIKit

/// A timed training session. You pick the drills you are running and how long
/// each one gets; the screen then runs the rotation against the clock, rests
/// between drills, and hands the finished session straight to the log editor so
/// nothing has to be typed in twice.
final class PracticeLiveViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    /// Called when the dancer finishes. The draft carries the elapsed minutes,
    /// the style and every drill that was actually run.
    var onFinish: ((PracticeDraft) -> Void)?

    private enum Phase {
        case work(Int)      // index into `drills`
        case rest(Int)      // index of the drill coming up next
        case done
    }

    // MARK: State

    private var style: DanceStyle = .hipHop
    private var drills: [String] = []
    private var minutesPerDrill = 5
    private var restSeconds = 30

    private var phase: Phase = .work(0)
    private var remaining: Double = 0
    private var elapsed: Double = 0
    private var isRunning = false
    private var timer: Timer?

    // MARK: Views

    private let navBar = UIView()
    private let closeButton = IconButton(symbol: "xmark", size: 40, background: .glass, pointSize: 15)

    private let setupScroll = ContentColumn(spacing: 20, gutter: 0)
    private let runContainer = UIView()

    private let styleStack = UIStackView(axis: .horizontal, spacing: 8)
    private let styleScroller = UIScrollView()
    private let drillFlow = TagFlowView(accent: Palette.lime)
    private let drillField = FieldInput(label: nil, placeholder: "Add a drill to rotate", symbol: "plus")
    private var customDrills: Set<String> = []
    private let drillStepper = MinuteStepper(minutes: 5, tint: Palette.cyan)
    private let restStack = UIStackView(axis: .horizontal, spacing: 8)
    private let planCard = UIView()

    private let ring = ProgressRingView(size: 236, lineWidth: 16, accent: Palette.lime)
    private let ringValue = UILabel()
    private let ringCaption = UILabel()
    private let drillLabel = UILabel()
    private let roundLabel = UILabel()
    private let elapsedLabel = UILabel()
    private let toggleButton = PillButton("Pause", symbol: "pause.fill", style: .primary, height: 52)
    private let skipButton = PillButton("Skip", symbol: "forward.fill", style: .outline, height: 52)
    private let phaseChip = ChipView(text: "", symbol: "figure.walk", accent: Palette.lime)

    private var planID: String?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        buildNav()
        buildSetup()
        buildRunner()

        let plan = store.activePlans.first
        style = plan?.style ?? store.goals.focusStyle
        planID = plan?.id
        minutesPerDrill = 5
        refreshStyleChips()
        refreshDrills()
        refreshPlanCard()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Chrome

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)

        let title = UILabel()
        title.text = "Training Session"
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

        closeButton.onTap = { [weak self] in self?.attemptClose() }
    }

    // MARK: - Setup

    private func buildSetup() {
        setupScroll.setTopPadding(10)
        setupScroll.setBottomPadding(40)
        view.addSubviews(setupScroll)
        NSLayoutConstraint.activate([
            setupScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            setupScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            setupScroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            setupScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let intro = UILabel()
        intro.text = "Pick the drills you're running and how long each one gets. The clock keeps you honest; the rest timer keeps you moving."
        intro.font = Typo.body
        intro.textColor = Palette.textMuted
        intro.numberOfLines = 0
        setupScroll.add(intro.gutterPadded())

        setupScroll.add(section(eyebrow: "What you're training", title: "Style",
                                hint: "The session is logged against this style.").gutterPadded())

        styleStack.translatesAutoresizingMaskIntoConstraints = false
        styleScroller.translatesAutoresizingMaskIntoConstraints = false
        styleScroller.showsHorizontalScrollIndicator = false
        styleScroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        styleScroller.addSubviews(styleStack)
        NSLayoutConstraint.activate([
            styleStack.leadingAnchor.constraint(equalTo: styleScroller.contentLayoutGuide.leadingAnchor),
            styleStack.trailingAnchor.constraint(equalTo: styleScroller.contentLayoutGuide.trailingAnchor),
            styleStack.topAnchor.constraint(equalTo: styleScroller.contentLayoutGuide.topAnchor),
            styleStack.bottomAnchor.constraint(equalTo: styleScroller.contentLayoutGuide.bottomAnchor),
            styleStack.heightAnchor.constraint(equalTo: styleScroller.frameLayoutGuide.heightAnchor),
            styleScroller.heightAnchor.constraint(equalToConstant: 40)
        ])
        setupScroll.add(styleScroller)

        setupScroll.add(section(eyebrow: "The rotation", title: "Drills",
                                hint: "These run in order until you stop. Anything you log counts a rep against your skill tree.").gutterPadded())

        drillField.onReturn = { [weak self] in self?.addCustomDrill() }
        drillFlow.onToggle = { [weak self] _ in
            guard let self else { return }
            self.drills = self.orderedSelection()
            self.refreshRunnerHeader()
        }
        let drillColumn = UIStackView(arrangedSubviews: [drillField, drillFlow])
        drillColumn.axis = .vertical
        drillColumn.spacing = 12
        setupScroll.add(drillColumn.gutterPadded())

        setupScroll.add(section(eyebrow: "Each drill gets", title: "Time per drill").gutterPadded())
        drillStepper.onChange = { [weak self] value in
            self?.minutesPerDrill = value
            self?.refreshRunnerHeader()
        }
        setupScroll.add(drillStepper.gutterPadded())

        setupScroll.add(section(eyebrow: "Between drills", title: "Rest",
                                hint: "Set it to zero to run straight through.").gutterPadded())
        restStack.translatesAutoresizingMaskIntoConstraints = false
        for option in [0, 15, 30, 45, 60, 90] {
            let chip = ChipView(text: option == 0 ? "None" : "\(option)s", accent: Palette.cyan)
            chip.isOn = option == restSeconds
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.restSeconds = option
                self.refreshRestChips()
            }
            restStack.addArrangedSubview(chip)
        }
        let restScroller = UIScrollView()
        restScroller.translatesAutoresizingMaskIntoConstraints = false
        restScroller.showsHorizontalScrollIndicator = false
        restScroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        restScroller.addSubviews(restStack)
        NSLayoutConstraint.activate([
            restStack.leadingAnchor.constraint(equalTo: restScroller.contentLayoutGuide.leadingAnchor),
            restStack.trailingAnchor.constraint(equalTo: restScroller.contentLayoutGuide.trailingAnchor),
            restStack.topAnchor.constraint(equalTo: restScroller.contentLayoutGuide.topAnchor),
            restStack.bottomAnchor.constraint(equalTo: restScroller.contentLayoutGuide.bottomAnchor),
            restStack.heightAnchor.constraint(equalTo: restScroller.frameLayoutGuide.heightAnchor),
            restScroller.heightAnchor.constraint(equalToConstant: 40)
        ])
        setupScroll.add(restScroller)

        planCard.translatesAutoresizingMaskIntoConstraints = false
        setupScroll.add(planCard.gutterPadded())

        let start = PillButton("Start the Clock", symbol: "play.fill", style: .primary)
        start.onTap = { [weak self] in self?.beginSession() }
        setupScroll.add(start.gutterPadded())
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

    private func refreshStyleChips() {
        styleStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for candidate in DanceStyle.allCases {
            let chip = ChipView(text: candidate.title, symbol: candidate.symbol, accent: candidate.accent)
            chip.isOn = candidate == style
            chip.onTap = { [weak self] in
                guard let self else { return }
                self.style = candidate
                self.customDrills.removeAll()
                self.refreshStyleChips()
                self.refreshDrills()
            }
            styleStack.addArrangedSubview(chip)
        }
    }

    private func refreshRestChips() {
        for (index, option) in [0, 15, 30, 45, 60, 90].enumerated() {
            (restStack.arrangedSubviews[safe: index] as? ChipView)?.isOn = option == restSeconds
        }
    }

    private func refreshDrills() {
        let suggestions = style.commonDrills
        let tags = suggestions + Array(customDrills).sorted()
        let selected = Set(drills.isEmpty ? Array(suggestions.prefix(4)) : drills)
        drillFlow.setAccent(style.accent)
        drillFlow.apply(tags: tags, selected: selected)
        drills = orderedSelection()
        refreshRunnerHeader()
    }

    /// Keeps the rotation in the order the style lists its moves — which runs
    /// groundwork first — rather than whatever order a Set happens to hand back.
    private func orderedSelection() -> [String] {
        let picked = drillFlow.selected
        let suggested = style.commonDrills.filter { picked.contains($0) }
        let custom = picked.subtracting(suggested).sorted()
        return suggested + custom
    }

    private func addCustomDrill() {
        let value = drillField.text.trimmed
        guard !value.isEmpty else { return }
        customDrills.insert(value)
        drills.append(value)
        drillField.text = ""
        refreshDrills()
        drillFlow.setSelection(Set(drills))
    }

    private func refreshPlanCard() {
        planCard.subviews.forEach { $0.removeFromSuperview() }
        guard let plan = store.activePlans.first else { return }

        let card = SurfaceCard(colors: [plan.style.accent.withAlphaComponent(0.14), Palette.surface],
                               radius: 22, border: plan.style.accent.withAlphaComponent(0.35))
        planCard.addSubviews(card)
        card.pinEdges(to: planCard)

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: "THIS SESSION FEEDS", attributes: [
            .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: plan.style.accent
        ])
        let title = UILabel()
        title.text = plan.title
        title.font = .dancte(16, .bold)
        title.textColor = Palette.text
        let detail = UILabel()
        detail.text = plan.focus
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let column = UIStackView(arrangedSubviews: [eyebrow, title, detail])
        column.axis = .vertical
        column.spacing = 4
        column.setCustomSpacing(8, after: eyebrow)

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
    }

    // MARK: - Runner

    private func buildRunner() {
        runContainer.translatesAutoresizingMaskIntoConstraints = false
        runContainer.isHidden = true
        view.addSubviews(runContainer)
        NSLayoutConstraint.activate([
            runContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            runContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            runContainer.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            runContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        ringValue.font = .dancteMono(52, .black)
        ringValue.textColor = Palette.text
        ringValue.textAlignment = .center
        ringValue.adjustsFontSizeToFitWidth = true
        ringValue.minimumScaleFactor = 0.5

        ringCaption.attributedText = NSAttributedString(string: "REMAINING", attributes: [
            .kern: 1.6, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint
        ])
        ringCaption.textAlignment = .center

        let ringStack = UIStackView(arrangedSubviews: [ringValue, ringCaption])
        ringStack.axis = .vertical
        ringStack.spacing = 0
        ringStack.alignment = .center
        ring.setCenter(ringStack)

        drillLabel.font = .dancte(28, .black)
        drillLabel.textColor = Palette.text
        drillLabel.textAlignment = .center
        drillLabel.numberOfLines = 2
        drillLabel.adjustsFontSizeToFitWidth = true
        drillLabel.minimumScaleFactor = 0.6

        roundLabel.font = Typo.caption
        roundLabel.textColor = Palette.textMuted
        roundLabel.textAlignment = .center

        elapsedLabel.font = .dancteMono(13, .bold)
        elapsedLabel.textColor = Palette.textFaint
        elapsedLabel.textAlignment = .center

        toggleButton.onTap = { [weak self] in self?.toggleRunning() }
        skipButton.onTap = { [weak self] in self?.skipPhase() }

        let buttons = UIStackView(arrangedSubviews: [toggleButton, skipButton])
        buttons.axis = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually

        let finish = PillButton("Finish & Log", symbol: "checkmark", style: .outline, height: 48)
        finish.onTap = { [weak self] in self?.finish() }

        let column = UIStackView(arrangedSubviews: [phaseChip, ring, drillLabel, roundLabel, elapsedLabel, buttons, finish])
        column.axis = .vertical
        column.spacing = 14
        column.alignment = .center
        column.setCustomSpacing(22, after: ring)
        column.setCustomSpacing(24, after: elapsedLabel)

        runContainer.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: runContainer.leadingAnchor, constant: Metric.gutter),
            column.trailingAnchor.constraint(equalTo: runContainer.trailingAnchor, constant: -Metric.gutter),
            column.centerYAnchor.constraint(equalTo: runContainer.centerYAnchor),
            buttons.widthAnchor.constraint(equalTo: column.widthAnchor),
            finish.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
    }

    private func refreshRunnerHeader() {
        guard case let .work(index) = phase else { return }
        let name = drills[safe: index] ?? "Free round"
        drillLabel.text = name
        roundLabel.text = "Drill \(min(index + 1, max(drills.count, 1))) of \(max(drills.count, 1)) · \(minutesPerDrill) min each"
    }

    // MARK: - Session control

    private func beginSession() {
        guard !drills.isEmpty else {
            Toast.warning("Pick at least one drill", detail: "The rotation needs something to run.")
            return
        }
        phase = .work(0)
        remaining = Double(minutesPerDrill * 60)
        elapsed = 0
        setupScroll.isHidden = true
        runContainer.isHidden = false
        ring.setAccent(style.accent)
        phaseChip.setText("WORK")
        refreshRunnerHeader()
        elapsedLabel.text = "Elapsed 0:00"
        startTimer()
        UIApplication.shared.isIdleTimerDisabled = true
        Haptics.thump()
    }

    private func startTimer() {
        isRunning = true
        toggleButton.title = "Pause"
        toggleButton.setSymbol("pause.fill")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick(0.25)
        }
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func toggleRunning() {
        if isRunning {
            stopTimer()
            toggleButton.title = "Resume"
            toggleButton.setSymbol("play.fill")
            Haptics.tap()
        } else {
            startTimer()
            Haptics.tap()
        }
    }

    private func tick(_ delta: Double) {
        remaining -= delta
        elapsed += delta
        if remaining <= 0 {
            advance()
        }
        render()
    }

    private func render() {
        let total: Double
        switch phase {
        case .work: total = Double(minutesPerDrill * 60)
        case .rest: total = Double(max(restSeconds, 1))
        case .done: total = 1
        }
        ringValue.text = Format.duration(max(0, remaining))
        ring.setProgress(CGFloat(max(0, min(1, remaining / max(total, 1)))), animated: false)
        elapsedLabel.text = "Elapsed \(Format.duration(elapsed))"
    }

    private func advance() {
        switch phase {
        case let .work(index):
            let next = index + 1
            if restSeconds > 0, next < drills.count {
                phase = .rest(next)
                remaining = Double(restSeconds)
                ring.setAccent(Palette.cyan)
                phaseChip.setText("REST")
                drillLabel.text = "Rest"
                roundLabel.text = "Next up · \(drills[safe: next] ?? "")"
                Haptics.tap()
            } else if next < drills.count {
                phase = .work(next)
                remaining = Double(minutesPerDrill * 60)
                ring.setAccent(style.accent)
                phaseChip.setText("WORK")
                refreshRunnerHeader()
                Haptics.thump()
            } else {
                finish()
            }
        case let .rest(index):
            phase = .work(index)
            remaining = Double(minutesPerDrill * 60)
            ring.setAccent(style.accent)
            phaseChip.setText("WORK")
            refreshRunnerHeader()
            Haptics.thump()
        case .done:
            break
        }
    }

    private func skipPhase() {
        Haptics.tap()
        advance()
        render()
    }

    private func finish() {
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        let minutes = max(1, Int((elapsed / 60).rounded()))
        let draft = PracticeDraft(date: Date(),
                                  minutes: minutes,
                                  style: style,
                                  drills: drills,
                                  planID: planID)
        Haptics.success()
        dismiss(animated: true) { [onFinish] in
            onFinish?(draft)
        }
    }

    private func attemptClose() {
        guard !runContainer.isHidden, elapsed > 5 else {
            dismiss(animated: true)
            return
        }
        confirm(title: "Leave this session?",
                message: "The clock has been running for \(Format.duration(elapsed)). Leaving discards it.",
                confirmTitle: "Discard Session") { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}
