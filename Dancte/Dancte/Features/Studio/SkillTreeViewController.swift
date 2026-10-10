import UIKit

/// The move library. Every move a dancer is working on moves through four
/// stages — Discovered, Drilling, Clean, Battle Ready — and logging a drill
/// pushes its rep count up.
final class SkillTreeViewController: UIViewController {

    private let scroll = ContentColumn(spacing: 20, gutter: 0)
    private let filterScroller = UIScrollView()
    private let filterStack = UIStackView(axis: .horizontal, spacing: 8)
    private let listStack = UIStackView(axis: .vertical, spacing: 10)
    private let stageCard = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
    private let stageStack = UIStackView(axis: .vertical, spacing: 12)
    private let addButton = PillButton("Add a move", symbol: "plus", style: .primary)

    private var styleFilter: DanceStyle?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink
        installBrandBackButton()
        styleNavigationBar(title: "Skill Tree", subtitle: "Move by move")

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

        let intro = UILabel()
        intro.text = "Move a skill forward as it lands. Anything you drill in a practice session counts a rep automatically."
        intro.font = Typo.body
        intro.textColor = Palette.textMuted
        intro.numberOfLines = 0
        scroll.add(intro.gutterPadded())

        buildStageCard()
        scroll.add(stageCard.gutterPadded())
        buildFilters()
        scroll.add(listStack.gutterPadded())

        addButton.onTap = { [weak self] in self?.presentMoveEditor(nil) }
        scroll.add(addButton.gutterPadded())

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .danctePractice, object: nil)
        reload()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Sections

    private func buildStageCard() {
        stageCard.subviews.forEach { $0.removeFromSuperview() }
        stageCard.addSubviews(stageStack)
        NSLayoutConstraint.activate([
            stageStack.leadingAnchor.constraint(equalTo: stageCard.leadingAnchor, constant: 18),
            stageStack.trailingAnchor.constraint(equalTo: stageCard.trailingAnchor, constant: -18),
            stageStack.topAnchor.constraint(equalTo: stageCard.topAnchor, constant: 18),
            stageStack.bottomAnchor.constraint(equalTo: stageCard.bottomAnchor, constant: -18)
        ])
    }

    private func buildFilters() {
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        filterScroller.translatesAutoresizingMaskIntoConstraints = false
        filterScroller.showsHorizontalScrollIndicator = false
        filterScroller.contentInset = UIEdgeInsets(top: 0, left: Metric.gutter, bottom: 0, right: Metric.gutter)
        filterScroller.addSubviews(filterStack)
        NSLayoutConstraint.activate([
            filterStack.leadingAnchor.constraint(equalTo: filterScroller.contentLayoutGuide.leadingAnchor),
            filterStack.trailingAnchor.constraint(equalTo: filterScroller.contentLayoutGuide.trailingAnchor),
            filterStack.topAnchor.constraint(equalTo: filterScroller.contentLayoutGuide.topAnchor),
            filterStack.bottomAnchor.constraint(equalTo: filterScroller.contentLayoutGuide.bottomAnchor),
            filterStack.heightAnchor.constraint(equalTo: filterScroller.frameLayoutGuide.heightAnchor),
            filterScroller.heightAnchor.constraint(equalToConstant: 40)
        ])
        scroll.add(filterScroller)
        scroll.setCustomSpacing(14, after: filterScroller)
    }

    private func rebuildFilters() {
        filterStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let all = ChipView(text: "All moves", accent: Palette.lime)
        all.isOn = styleFilter == nil
        all.onTap = { [weak self] in
            self?.styleFilter = nil
            self?.reload()
        }
        filterStack.addArrangedSubview(all)

        let present = DanceStyle.allCases.filter { style in store.moves.contains { $0.style == style } }
        for style in present {
            let chip = ChipView(text: style.title, symbol: style.symbol, accent: style.accent)
            chip.isOn = styleFilter == style
            chip.onTap = { [weak self] in
                self?.styleFilter = style
                self?.reload()
            }
            filterStack.addArrangedSubview(chip)
        }
    }

    // MARK: - Render

    @objc private func reload() {
        rebuildFilters()
        buildStages()

        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let moves = store.moves(for: styleFilter)

        guard !moves.isEmpty else {
            let empty = EmptyStateView(symbol: "list.bullet.rectangle",
                                       title: styleFilter == nil ? "No moves yet" : "Nothing tracked here yet",
                                       message: styleFilter == nil
                                        ? "Add the moves you're working on and watch them climb from Discovered to Battle Ready."
                                        : "You haven't added a \(styleFilter?.title ?? "") move yet.",
                                       actionTitle: "Add a move",
                                       compact: true)
            empty.onAction = { [weak self] in self?.presentMoveEditor(nil) }
            listStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 300).isActive = true
            return
        }

        for move in moves {
            let row = MoveRowView(move: move)
            row.onOpen = { [weak self] in self?.openMove(move) }
            row.onAdvance = { [weak self] in
                store.advance(move.id)
                Haptics.success()
                if let next = move.stage.next { Toast.success("\(move.name) → \(next.title)") }
                self?.reload()
            }
            row.onEdit = { [weak self] in self?.presentMoveEditor(move) }
            listStack.addArrangedSubview(row)
        }
    }

    private func buildStages() {
        stageStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let moves = styleFilter == nil ? store.moves : store.moves.filter { $0.style == styleFilter }
        let total = max(moves.count, 1)

        let header = UILabel()
        header.attributedText = NSAttributedString(string: "PROGRESS", attributes: [
            .kern: 2, .font: UIFont.dancte(10, .black), .foregroundColor: Palette.textFaint
        ])
        stageStack.addArrangedSubview(header)

        for stage in MoveStage.allCases {
            let count = moves.filter { $0.stage == stage }.count
            let row = RatioBarRow(caption: stage.title, value: "\(count)", accent: stage.accent, captionWidth: 108)
            row.configure(caption: stage.title,
                          value: "\(count)",
                          ratio: CGFloat(count) / CGFloat(total),
                          accent: stage.accent)
            stageStack.addArrangedSubview(row)
        }
    }

    private func openMove(_ move: MoveSkill) {
        navigationController?.pushViewController(MoveDetailViewController(moveID: move.id), animated: true)
    }

    // MARK: - Editor

    private func presentMoveEditor(_ move: MoveSkill?) {
        let editor = MoveEditorViewController(move: move, defaultStyle: styleFilter)
        editor.onSave = { [weak self] in self?.reload() }
        presentSheet(editor)
    }
}

// MARK: - Move editor

final class MoveEditorViewController: UIViewController, OwnsNavigationBar {

    var prefersOwnHeader: Bool { true }
    var onSave: (() -> Void)?

    private let existing: MoveSkill?
    private let scroll = ContentColumn(spacing: 18, gutter: 0)
    private let navBar = UIView()
    private let nameField = FieldInput(label: "Move", placeholder: "e.g. Windmill", symbol: "figure.walk")
    private let styleStack = UIStackView(axis: .horizontal, spacing: 8)
    private let styleScroller = UIScrollView()
    private let stageStack = UIStackView(axis: .vertical, spacing: 10)
    private let repsCard = SurfaceCard(colors: Grad.card, radius: 22, border: Palette.stroke)
    private let repsLabel = UILabel()
    private let repsStepper = UIStepper()
    private let saveButton = PillButton("Save Move", symbol: "checkmark", style: .primary)

    private var style: DanceStyle
    private var stage: MoveStage
    private var reps: Int
    private var stageRows: [(MoveStage, UIControl)] = []

    init(move: MoveSkill?, defaultStyle: DanceStyle?) {
        self.existing = move
        self.style = move?.style ?? defaultStyle ?? .hipHop
        self.stage = move?.stage ?? .discovered
        self.reps = move?.reps ?? 0
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
        view.addSubviews(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        nameField.text = existing?.name ?? ""
        scroll.add(nameField.gutterPadded())
        buildStylePicker()
        buildStagePicker()
        buildReps()
        saveButton.onTap = { [weak self] in self?.save() }
        scroll.add(saveButton.gutterPadded())
        installKeyboardDismissOnTap()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildNav() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubviews(navBar)

        let title = UILabel()
        title.text = existing == nil ? "Add a Move" : "Edit Move"
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
    }

    private func buildStylePicker() {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "STYLE", attributes: [
            .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])

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

        let column = UIStackView(arrangedSubviews: [label, styleScroller])
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

    private func buildStagePicker() {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "STAGE", attributes: [
            .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])
        scroll.add(label.gutterPadded())

        stageStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stageRows.removeAll()

        for candidate in MoveStage.allCases {
            let control = UIControl()
            control.translatesAutoresizingMaskIntoConstraints = false
            control.layer.cornerRadius = 18
            control.layer.cornerCurve = .continuous
            control.layer.borderWidth = 1
            control.accessibilityLabel = candidate.title

            let name = UILabel()
            name.text = candidate.title
            name.font = .dancte(15, .bold)
            name.translatesAutoresizingMaskIntoConstraints = false
            name.isUserInteractionEnabled = false

            let detail = UILabel()
            detail.text = candidate.next == nil ? "Ready to battle" : "Next: \(candidate.next?.title ?? "")"
            detail.font = .dancte(11, .medium)
            detail.translatesAutoresizingMaskIntoConstraints = false
            detail.isUserInteractionEnabled = false

            let text = UIStackView(arrangedSubviews: [name, detail])
            text.axis = .vertical
            text.spacing = 1
            text.translatesAutoresizingMaskIntoConstraints = false
            text.isUserInteractionEnabled = false

            let check = UIImageView(image: UIImage(systemName: "circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)))
            check.translatesAutoresizingMaskIntoConstraints = false
            check.isUserInteractionEnabled = false
            check.setContentHuggingPriority(.required, for: .horizontal)

            control.addSubviews(text, check)
            NSLayoutConstraint.activate([
                control.heightAnchor.constraint(equalToConstant: 62),
                text.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 16),
                text.centerYAnchor.constraint(equalTo: control.centerYAnchor),
                check.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -16),
                check.centerYAnchor.constraint(equalTo: control.centerYAnchor)
            ])

            control.addAction(UIAction { [weak self] _ in
                Haptics.selection()
                self?.stage = candidate
                self?.refreshStages()
            }, for: .touchUpInside)

            stageRows.append((candidate, control))
            stageStack.addArrangedSubview(control)
        }
        refreshStages()
    }

    private func refreshStages() {
        for (candidate, control) in stageRows {
            let isOn = candidate == stage
            control.backgroundColor = isOn ? style.accent.withAlphaComponent(0.14) : Palette.surfaceHi.withAlphaComponent(0.55)
            control.layer.borderColor = (isOn ? style.accent : Palette.stroke).cgColor
            guard let check = control.subviews.compactMap({ $0 as? UIImageView }).first,
                  let text = control.subviews.compactMap({ $0 as? UIStackView }).first,
                  let name = text.arrangedSubviews.first as? UILabel,
                  let detail = text.arrangedSubviews.last as? UILabel else { continue }
            check.image = UIImage(systemName: isOn ? "largecircle.fill.circle" : "circle",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
            check.tintColor = isOn ? style.accent : Palette.strokeHi
            name.textColor = isOn ? Palette.text : Palette.textMuted
            detail.textColor = isOn ? Palette.textMuted : Palette.textFaint
        }
    }

    private func buildReps() {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "REPS LOGGED", attributes: [
            .kern: 1.3, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint
        ])

        repsLabel.text = "\(reps)"
        repsLabel.font = .dancteMono(30, .black)
        repsLabel.textColor = Palette.text

        repsStepper.minimumValue = 0
        repsStepper.maximumValue = 999
        repsStepper.stepValue = 1
        repsStepper.value = Double(reps)
        repsStepper.tintColor = Palette.lime
        repsStepper.addTarget(self, action: #selector(repsChanged), for: .valueChanged)
        repsStepper.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [repsLabel, UIView(), repsStepper])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        let column = UIStackView(arrangedSubviews: [label, row])
        column.axis = .vertical
        column.spacing = 8

        repsCard.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: repsCard.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: repsCard.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: repsCard.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: repsCard.bottomAnchor, constant: -16)
        ])
        scroll.add(repsCard.gutterPadded())
    }

    @objc private func repsChanged() {
        reps = Int(repsStepper.value)
        repsLabel.text = "\(reps)"
    }

    private func save() {
        view.endEditing(true)
        let name = nameField.text.trimmed
        guard !name.isEmpty else {
            nameField.showError("Name the move so you can track it.")
            return
        }

        let move = MoveSkill(id: existing?.id ?? "mv_\(UUID().uuidString.prefix(10))",
                             name: name,
                             style: style,
                             stage: stage,
                             reps: reps,
                             updatedAt: Date())
        store.saveMove(move)
        Haptics.success()
        onSave?()
        dismiss(animated: true) {
            Toast.success(self.existing == nil ? "Move added to your skill tree" : "Move updated")
        }
    }
}
