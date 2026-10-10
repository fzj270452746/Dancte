import UIKit

/// A weekly practice plan: how long, how often, in which style, and what the
/// dancer is actually chasing. Progress against it appears on the dashboard.
final class PracticePlanEditorViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }

    private let existing: PracticePlan?
    private let scroll = ContentColumn(spacing: 20, gutter: 0)
    private let navBar = UIView()
    private let titleField = FieldInput(label: "Plan name", placeholder: "e.g. Windmill to Freeze", symbol: "target")
    private let styleStack = UIStackView(axis: .horizontal, spacing: 8)
    private let styleScroller = UIScrollView()
    private let stepper = MinuteStepper(minutes: 240, tint: Palette.lime)
    private let sessionStack = UIStackView(axis: .horizontal, spacing: 8, distribution: .fillEqually)
    private let focusCard = SurfaceCard(colors: [Palette.surfaceHi.withAlphaComponent(0.7), Palette.surface.withAlphaComponent(0.7)],
                                        radius: 22, border: Palette.stroke)
    private let focusView = UITextView()
    private let startPicker = UIDatePicker()
    private let endPicker = UIDatePicker()
    private let saveButton = PillButton("Save Plan", symbol: "checkmark", style: .primary)

    private var style: DanceStyle
    private var sessionTarget: Int

    init(plan: PracticePlan?) {
        self.existing = plan
        self.style = plan?.style ?? .breaking
        self.sessionTarget = plan?.weeklySessionTarget ?? 4
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        buildNav()
        scroll.setTopPadding(12)
        scroll.setBottomPadding(50)
        scroll.keyboardDismissMode = .interactive
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        titleField.text = existing?.title ?? ""
        scroll.add(titleField.gutterPadded())
        buildTemplateEntry()
        buildStylePicker()
        buildSessionTarget()
        buildMinuteTarget()
        buildFocus()
        buildDates()

        saveButton.onTap = { [weak self] in self?.save() }
        scroll.add(saveButton.gutterPadded())

        installKeyboardDismissOnTap()
        observeKeyboard()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)

        let title = UILabel()
        title.text = existing == nil ? "New Plan" : "Edit Plan"
        title.font = .dancte(17, .bold)
        title.textColor = Palette.text
        title.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubviews(title)

        let close = IconButton(symbol: "xmark", size: 40, background: .glass, pointSize: 14)
        close.onTap = { [weak self] in self?.dismiss(animated: true) }
        navBar.addSubviews(close)

        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 52),
            close.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: Metric.gutter),
            close.bottomAnchor.constraint(equalTo: navBar.bottomAnchor, constant: -4),
            title.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: close.centerYAnchor)
        ])

        guard existing != nil else { return }
        let delete = IconButton(symbol: "trash", size: 40, background: .glass, tint: Palette.magenta, pointSize: 15)
        delete.onTap = { [weak self] in self?.confirmDelete() }
        navBar.addSubviews(delete)
        NSLayoutConstraint.activate([
            delete.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -Metric.gutter),
            delete.centerYAnchor.constraint(equalTo: close.centerYAnchor)
        ])
    }

    /// Writing a plan from scratch is the slow path — most dancers would rather
    /// start from something that already works.
    private func buildTemplateEntry() {
        guard existing == nil else { return }

        let card = SurfaceCard(colors: [Palette.violet.withAlphaComponent(0.16), Palette.surface],
                               radius: 22, border: Palette.violet.withAlphaComponent(0.35))

        let icon = UIImageView(image: UIImage(systemName: "square.stack.3d.up.fill", withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)))
        icon.tintColor = Palette.violet
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = UILabel()
        title.text = "Start from a programme"
        title.font = .dancte(15.5, .bold)
        title.textColor = Palette.text

        let detail = UILabel()
        detail.text = "Six preset plans with the drills, targets and weeks already worked out."
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, text])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let tap = ClosureControl { [weak self] in
            guard let self, let nav = self.navigationController else { return }
            nav.pushViewController(PlanTemplatesViewController(), animated: true)
        }
        card.addSubviews(tap)
        tap.pinEdges(to: card)

        scroll.add(card.gutterPadded())
    }

    private func label(_ text: String) -> UILabel {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])
        return label
    }

    private func buildStylePicker() {
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
        rebuildStyles()

        let column = UIStackView(arrangedSubviews: [label("STYLE THIS PLAN TRACKS"), styleScroller])
        column.axis = .vertical
        column.spacing = 12
        scroll.add(column)
    }

    private func rebuildStyles() {
        styleStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for candidate in DanceStyle.allCases {
            let chip = ChipView(text: candidate.title, symbol: candidate.symbol, accent: candidate.accent)
            chip.isOn = candidate == style
            chip.onTap = { [weak self] in
                self?.style = candidate
                self?.rebuildStyles()
            }
            styleStack.addArrangedSubview(chip)
        }
    }

    private func buildSessionTarget() {
        let column = UIStackView(axis: .vertical, spacing: 12)
        column.addArrangedSubview(label("SESSIONS PER WEEK"))

        for index in 1...7 {
            let chip = ChipView(text: "\(index)", accent: style.accent, horizontalPadding: 0, fontSize: 15)
            chip.isOn = index == sessionTarget
            chip.onTap = { [weak self] in
                self?.sessionTarget = index
                self?.refreshSessionTargets()
            }
            sessionStack.addArrangedSubview(chip)
        }
        column.addArrangedSubview(sessionStack)
        scroll.add(column.gutterPadded())
    }

    private func refreshSessionTargets() {
        for (index, chip) in sessionStack.arrangedSubviews.compactMap({ $0 as? ChipView }).enumerated() {
            chip.isOn = index + 1 == sessionTarget
        }
    }

    private func buildMinuteTarget() {
        let column = UIStackView(axis: .vertical, spacing: 14)
        column.addArrangedSubview(label("MINUTES PER WEEK"))
        scroll.add(column.gutterPadded())

        stepper.setTint(style.accent)
        scroll.add(stepper.gutterPadded())
    }

    private func buildFocus() {
        let column = UIStackView(axis: .vertical, spacing: 12)
        column.addArrangedSubview(label("WHAT YOU'RE CHASING"))

        focusView.backgroundColor = .clear
        focusView.font = .dancte(15, .regular)
        focusView.textColor = Palette.text
        focusView.tintColor = Palette.lime
        focusView.isScrollEnabled = false
        focusView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        focusView.translatesAutoresizingMaskIntoConstraints = false
        focusCard.addSubviews(focusView)
        NSLayoutConstraint.activate([
            focusCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 118),
            focusView.leadingAnchor.constraint(equalTo: focusCard.leadingAnchor, constant: 6),
            focusView.trailingAnchor.constraint(equalTo: focusCard.trailingAnchor, constant: -6),
            focusView.topAnchor.constraint(equalTo: focusCard.topAnchor, constant: 4),
            focusView.bottomAnchor.constraint(equalTo: focusCard.bottomAnchor, constant: -4)
        ])
        column.addArrangedSubview(focusCard)
        scroll.add(column.gutterPadded())

        focusView.text = existing?.focus ?? ""
    }

    private func buildDates() {
        let start = existing?.startDate ?? Date()
        let end = existing?.endDate ?? Date().adding(days: 30)

        for picker in [startPicker, endPicker] {
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .compact
            picker.tintColor = Palette.lime
            picker.overrideUserInterfaceStyle = .dark
            picker.translatesAutoresizingMaskIntoConstraints = false
        }
        startPicker.date = start
        endPicker.date = end
        endPicker.minimumDate = start

        let card = SurfaceCard(colors: Grad.card, radius: 22, border: Palette.stroke)
        let startLabel = label("START")
        let endLabel = label("TARGET DATE")

        let startRow = UIStackView(arrangedSubviews: [startLabel, UIView(), startPicker])
        startRow.axis = .horizontal
        startRow.spacing = 10
        startRow.alignment = .center

        let endRow = UIStackView(arrangedSubviews: [endLabel, UIView(), endPicker])
        endRow.axis = .horizontal
        endRow.spacing = 10
        endRow.alignment = .center

        let column = UIStackView(arrangedSubviews: [startRow, endRow])
        column.axis = .vertical
        column.spacing = 14
        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        scroll.add(card.gutterPadded())
    }

    private func save() {
        view.endEditing(true)
        let name = titleField.text.trimmed
        guard !name.isEmpty else {
            titleField.showError("Give the plan a name you'll recognise.")
            return
        }

        let plan = PracticePlan(
            id: existing?.id ?? "pl_\(UUID().uuidString.prefix(8))",
            title: name,
            style: style,
            weeklyMinuteTarget: stepper.minutes,
            weeklySessionTarget: sessionTarget,
            focus: focusView.text.trimmed.isEmpty ? "Show up and put the work in." : focusView.text.trimmed,
            startDate: startPicker.date,
            endDate: max(endPicker.date, startPicker.date.adding(days: 1)),
            accentIndex: style.accentIndex
        )
        store.savePlan(plan)
        Haptics.success()
        dismiss(animated: true) {
            Toast.success(self.existing == nil ? "Plan created" : "Plan updated")
        }
    }

    private func confirmDelete() {
        guard let existing else { return }
        confirm(title: "Delete this plan?",
                message: "Your logged sessions stay — only the weekly target is removed.",
                confirmTitle: "Delete Plan") {
            store.deletePlan(existing.id)
            Toast.show("Plan removed")
            self.dismiss(animated: true)
        }
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        scroll.contentInset.bottom = overlap
        scroll.verticalScrollIndicatorInsets.bottom = overlap
    }
}
