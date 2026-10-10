import UIKit

/// One move, everything about it: where it sits on the ladder, what it still
/// needs, and every session it has come up in.
final class MoveDetailViewController: UIViewController, UITextViewDelegate {

    private let moveID: String
    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let headerContainer = UIView()
    private let ladderStack = UIStackView(axis: .vertical, spacing: 12)
    private let historyStack = UIStackView(axis: .vertical, spacing: 10)
    private let notesView = UITextView()
    private var notesCard: SurfaceCard?

    init(moveID: String) {
        self.moveID = moveID
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
        styleNavigationBar(title: store.move(moveID)?.name ?? "Move")

        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                   style: .plain, target: self, action: #selector(presentActions))
        more.tintColor = Palette.text
        navigationItem.rightBarButtonItem = more

        scroll.setTopPadding(12)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        scroll.add(headerContainer.gutterPadded())
        scroll.add(section(eyebrow: "The ladder", title: "Where it stands", stack: ladderStack))
        scroll.add(buildTargetCard().gutterPadded())
        scroll.add(buildNotesCard().gutterPadded())
        scroll.add(section(eyebrow: "Every time it came up", title: "Practice history", stack: historyStack))

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

    // MARK: - Cards

    private func buildTargetCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        container.addSubviews(card)
        card.pinEdges(to: container)

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: "REP TARGET", attributes: [
            .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint
        ])

        let stepper = UIStepper()
        stepper.minimumValue = 0
        stepper.maximumValue = 999
        stepper.stepValue = 10
        stepper.tintColor = Palette.lime
        stepper.value = Double(store.move(moveID)?.targetReps ?? 0)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self, var move = store.move(self.moveID) else { return }
            move.targetReps = Int(stepper.value)
            store.saveMove(move)
            self.reload()
        }, for: .valueChanged)

        let value = UILabel()
        value.font = .dancteMono(20, .black)
        value.textColor = Palette.lime
        value.text = "\(store.move(moveID)?.targetReps ?? 0)"

        let row = UIStackView(arrangedSubviews: [eyebrow, UIView(), value, stepper])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        value.setContentHuggingPriority(.required, for: .horizontal)
        stepper.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return container
    }

    private func buildNotesCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = SurfaceCard(colors: [Palette.surfaceHi.withAlphaComponent(0.7), Palette.surface.withAlphaComponent(0.7)],
                               radius: 22, border: Palette.stroke)
        notesCard = card
        container.addSubviews(card)
        card.pinEdges(to: container)

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: "WHAT IT STILL NEEDS", attributes: [
            .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint
        ])

        notesView.backgroundColor = .clear
        notesView.font = Typo.body
        notesView.textColor = Palette.text
        notesView.tintColor = Palette.lime
        notesView.delegate = self
        notesView.isScrollEnabled = false
        notesView.textContainerInset = .zero
        notesView.textContainer.lineFragmentPadding = 0

        let column = UIStackView(arrangedSubviews: [eyebrow, notesView])
        column.axis = .vertical
        column.spacing = 8

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            notesView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
        return container
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard var move = store.move(moveID) else { return }
        let value = textView.text.trimmed
        move.notes = value.isEmpty ? nil : value
        store.saveMove(move)
    }

    // MARK: - Render

    @objc private func reload() {
        guard let move = store.move(moveID) else {
            navigationController?.popViewController(animated: true)
            return
        }
        buildHeader(move)
        buildLadder(move)
        buildHistory(move)
        if notesView.text != (move.notes ?? "") {
            notesView.text = move.notes ?? ""
        }
    }

    private func buildHeader(_ move: MoveSkill) {
        headerContainer.subviews.forEach { $0.removeFromSuperview() }

        let accent = move.style.accent
        let card = SurfaceCard(colors: [accent.withAlphaComponent(0.18), Palette.surface],
                               radius: 28, border: accent.withAlphaComponent(0.4))
        headerContainer.addSubviews(card)
        card.pinEdges(to: headerContainer)

        let name = UILabel()
        name.text = move.name
        name.font = .dancte(28, .black)
        name.textColor = Palette.text
        name.numberOfLines = 2

        let styleChip = ChipView(text: move.style.title, symbol: move.style.symbol, accent: accent,
                                 horizontalPadding: 12, fontSize: 12)
        styleChip.setContentHuggingPriority(.required, for: .horizontal)

        let stageChip = ChipView(text: move.stage.title, accent: move.stage.accent,
                                 horizontalPadding: 12, fontSize: 12)
        stageChip.isOn = move.stage == .battleReady
        stageChip.setContentHuggingPriority(.required, for: .horizontal)

        let chips = UIStackView(arrangedSubviews: [styleChip, stageChip, UIView()])
        chips.axis = .horizontal
        chips.spacing = 8

        let tracker = MoveStageTrack(stage: move.stage, accent: accent)
        tracker.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let reps = UILabel()
        reps.attributedText = NSAttributedString(
            string: "\(move.reps) REPS LOGGED · UPDATED \(move.updatedAt.dayLabel.uppercased())",
            attributes: [.kern: 1.2, .font: UIFont.dancte(10, .bold), .foregroundColor: Palette.textFaint]
        )

        let column = UIStackView(arrangedSubviews: [chips, name, tracker, reps])
        column.axis = .vertical
        column.spacing = 12

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    private func buildLadder(_ move: MoveSkill) {
        ladderStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let reached = MoveStage.allCases.firstIndex(of: move.stage) ?? 0

        for (index, stage) in MoveStage.allCases.enumerated() {
            let isCurrent = index == reached
            let isDone = index < reached

            let card = SurfaceCard(colors: isCurrent
                                    ? [stage.accent.withAlphaComponent(0.18), Palette.surface]
                                    : Grad.card,
                                   radius: 20,
                                   border: isCurrent ? stage.accent.withAlphaComponent(0.5) : Palette.stroke.withAlphaComponent(0.7))

            let dot = UIView()
            dot.backgroundColor = isDone || isCurrent ? stage.accent : Palette.strokeHi.withAlphaComponent(0.5)
            dot.layer.cornerRadius = 7
            dot.translatesAutoresizingMaskIntoConstraints = false

            let title = UILabel()
            title.text = stage.title
            title.font = .dancte(15.5, .bold)
            title.textColor = isCurrent ? Palette.text : Palette.textMuted

            let blurb = UILabel()
            blurb.text = stage.blurb
            blurb.font = Typo.caption
            blurb.textColor = Palette.textFaint
            blurb.numberOfLines = 2

            let text = UIStackView(arrangedSubviews: [title, blurb])
            text.axis = .vertical
            text.spacing = 2

            let row = UIStackView(arrangedSubviews: [dot, text])
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .top

            card.addSubviews(row)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 14),
                dot.heightAnchor.constraint(equalToConstant: 14),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
                row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
            ])
            ladderStack.addArrangedSubview(card)
        }

        if let next = move.stage.next {
            let advance = PillButton("Advance to \(next.title)", symbol: "arrow.up.right", style: .primary, height: 50)
            advance.onTap = { [weak self] in
                store.advance(move.id)
                Haptics.success()
                Toast.success("\(move.name) → \(next.title)")
                self?.reload()
            }
            ladderStack.addArrangedSubview(advance)
        } else {
            let done = UILabel()
            done.text = "This one is battle ready. Keep it sharp."
            done.font = Typo.caption
            done.textColor = Palette.lime
            done.textAlignment = .center
            ladderStack.addArrangedSubview(done)
        }
    }

    private func buildHistory(_ move: MoveSkill) {
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let sessions = store.sessions(drilling: move.name)
        guard !sessions.isEmpty else {
            let empty = EmptyStateView(symbol: "clock.arrow.circlepath",
                                       title: "No sessions yet",
                                       message: "Log a session that includes \(move.name) and it will show up here with the date and how long you ran.",
                                       compact: true)
            historyStack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 240).isActive = true
            return
        }

        for session in sessions.prefix(8) {
            let row = SessionRowView(session: session, showsDate: true)
            row.onTap = { [weak self] in
                self?.navigationController?.pushViewController(SessionDetailViewController(sessionID: session.id), animated: true)
            }
            historyStack.addArrangedSubview(row)
        }

        if sessions.count > 8 {
            let more = UILabel()
            more.text = "\(sessions.count - 8) earlier session\(sessions.count - 8 == 1 ? "" : "s") in your history."
            more.font = Typo.caption
            more.textColor = Palette.textFaint
            more.textAlignment = .center
            historyStack.addArrangedSubview(more)
        }
    }

    // MARK: - Actions

    @objc private func presentActions() {
        guard let move = store.move(moveID) else { return }
        let sheet = UIAlertController(title: move.name, message: "\(move.style.title) · \(move.stage.title)", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Edit Move", style: .default) { [weak self] _ in
            guard let self else { return }
            let editor = MoveEditorViewController(move: move, defaultStyle: move.style)
            editor.onSave = { [weak self] in self?.reload() }
            self.presentSheet(editor)
        })
        sheet.addAction(UIAlertAction(title: "Delete Move", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.confirm(title: "Delete this move?",
                         message: "It disappears from your skill tree. The sessions you logged stay exactly where they are.",
                         confirmTitle: "Delete Move") {
                store.deleteMove(move.id)
                Toast.show("Move removed")
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
