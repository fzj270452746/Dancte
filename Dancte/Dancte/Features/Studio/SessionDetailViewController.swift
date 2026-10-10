import UIKit

/// A single logged session, read back in full — including the cover photo the
/// dancer attached and the plan it counted towards.
final class SessionDetailViewController: UIViewController {

    private let sessionID: String
    private let scroll = ContentColumn(spacing: 22, gutter: 0)
    private let heroContainer = UIView()
    private let factsStack = UIStackView(axis: .vertical, spacing: 10)
    private let drillsStack = UIStackView(axis: .vertical, spacing: 12)

    init(sessionID: String) {
        self.sessionID = sessionID
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
        styleNavigationBar(title: "Session")

        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                   style: .plain, target: self, action: #selector(presentActions))
        more.tintColor = Palette.text
        navigationItem.rightBarButtonItem = more

        scroll.setTopPadding(12)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)

        scroll.add(heroContainer.gutterPadded())
        scroll.add(buildFactsCard().gutterPadded())
        scroll.add(buildNotesCard().gutterPadded())
        scroll.add(section(eyebrow: "On the floor", title: "Drills run", stack: drillsStack))

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

    private func buildFactsCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = SurfaceCard(colors: Grad.card, radius: 26, border: Palette.stroke.withAlphaComponent(0.8))
        container.addSubviews(card)
        card.pinEdges(to: container)

        let column = UIStackView(arrangedSubviews: [factsStack])
        column.axis = .vertical
        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return container
    }

    private func buildNotesCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = SurfaceCard(colors: [Palette.surfaceHi.withAlphaComponent(0.7), Palette.surface.withAlphaComponent(0.7)],
                               radius: 22, border: Palette.stroke)
        container.addSubviews(card)
        card.pinEdges(to: container)

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: "NOTES", attributes: [
            .kern: 1.4, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.textFaint
        ])

        let body = UILabel()
        body.tag = 991
        body.font = Typo.body
        body.textColor = Palette.text
        body.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [eyebrow, body])
        column.axis = .vertical
        column.spacing = 8

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return container
    }

    // MARK: - Render

    @objc private func reload() {
        guard let session = store.session(sessionID) else {
            navigationController?.popViewController(animated: true)
            return
        }
        buildHero(session)
        buildFacts(session)
        buildDrills(session)
        if let body = view.viewWithTag(991) as? UILabel {
            body.text = session.notes.isEmpty ? "Nothing written down for this one." : session.notes
            body.textColor = session.notes.isEmpty ? Palette.textFaint : Palette.text
        }
    }

    private func buildHero(_ session: PracticeSession) {
        heroContainer.subviews.forEach { $0.removeFromSuperview() }

        let accent = session.style.accent
        let card = SurfaceCard(colors: [accent.withAlphaComponent(0.18), Palette.surface],
                               radius: 28, border: accent.withAlphaComponent(0.4))
        heroContainer.addSubviews(card)
        card.pinEdges(to: heroContainer)

        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(string: session.date.dayLabel.uppercased(), attributes: [
            .kern: 1.6, .font: UIFont.dancte(10, .bold), .foregroundColor: accent
        ])

        let minutes = UILabel()
        minutes.text = Format.minutes(session.minutes)
        minutes.font = .dancte(40, .black)
        minutes.textColor = Palette.text
        minutes.setContentCompressionResistancePriority(.required, for: .horizontal)

        let style = UILabel()
        style.text = "\(session.style.title) · logged at \(session.createdAt.clockLabel)"
        style.font = Typo.caption
        style.textColor = Palette.textMuted

        let text = UIStackView(arrangedSubviews: [eyebrow, minutes, style])
        text.axis = .vertical
        text.spacing = 4

        let moodChip = ChipView(text: session.mood.title, symbol: session.mood.symbol,
                                accent: session.mood.accent, horizontalPadding: 12, fontSize: 12)
        moodChip.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [text, moodChip])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        var rows: [UIView] = [row]

        if let mediaName = session.mediaName, let image = Assets.image(mediaName) {
            let artwork = ArtworkView(cornerRadius: 20)
            artwork.setImage(image)
            artwork.translatesAutoresizingMaskIntoConstraints = false
            artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor, multiplier: 0.68).isActive = true
            rows.append(artwork)
        }

        let column = UIStackView(arrangedSubviews: rows)
        column.axis = .vertical
        column.spacing = 16

        card.addSubviews(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    private func buildFacts(_ session: PracticeSession) {
        factsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Intensity as five lit segments so the number reads at a glance.
        let intensityRow = UIStackView(axis: .horizontal, spacing: 5)
        for step in 1...5 {
            let segment = UIView()
            segment.translatesAutoresizingMaskIntoConstraints = false
            segment.layer.cornerRadius = 3
            segment.backgroundColor = step <= session.intensity
                ? Palette.blaze
                : Palette.strokeHi.withAlphaComponent(0.4)
            segment.heightAnchor.constraint(equalToConstant: 8).isActive = true
            segment.widthAnchor.constraint(equalToConstant: 22).isActive = true
            intensityRow.addArrangedSubview(segment)
        }

        factsStack.addArrangedSubview(factRow(title: "Intensity", detail: intensityDetail(session.intensity), trailing: intensityRow))

        if let planID = session.planID, let plan = store.plan(planID) {
            let chip = ChipView(text: plan.title, symbol: "target", accent: plan.style.accent,
                                horizontalPadding: 10, fontSize: 10.5)
            chip.isOn = true
            factsStack.addArrangedSubview(factRow(title: "Counted towards", detail: plan.style.title, trailing: chip))
        }
    }

    private func intensityDetail(_ value: Int) -> String {
        switch value {
        case 1:  return "Light and technical"
        case 2:  return "Easy — kept it loose"
        case 3:  return "Solid working pace"
        case 4:  return "Hard — pushed the whole way"
        default: return "Everything you had"
        }
    }

    private func factRow(title: String, detail: String, trailing: UIView) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .dancte(14.5, .bold)
        titleLabel.textColor = Palette.text

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = Typo.caption
        detailLabel.textColor = Palette.textFaint

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [text, UIView(), trailing])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func buildDrills(_ session: PracticeSession) {
        drillsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !session.drills.isEmpty else {
            let label = UILabel()
            label.text = "No drills recorded for this session."
            label.font = Typo.caption
            label.textColor = Palette.textFaint
            drillsStack.addArrangedSubview(label)
            return
        }

        let flow = TagFlowView(tags: session.drills, selected: Set(session.drills), accent: session.style.accent)
        flow.onToggle = { _ in }
        drillsStack.addArrangedSubview(flow)

        let hint = UILabel()
        hint.text = "Each of these counted a rep against your skill tree."
        hint.font = Typo.caption
        hint.textColor = Palette.textFaint
        drillsStack.addArrangedSubview(hint)
    }

    // MARK: - Actions

    @objc private func presentActions() {
        guard let session = store.session(sessionID) else { return }
        let sheet = UIAlertController(title: Format.minutes(session.minutes),
                                      message: session.date.dayLabel,
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Edit Session", style: .default) { [weak self] _ in
            self?.presentSheet(PracticeLogEditorViewController(session: session))
        })
        sheet.addAction(UIAlertAction(title: "Delete Session", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.confirm(title: "Delete this session?",
                         message: "It disappears from your history, your streak and your weekly totals.",
                         confirmTitle: "Delete Session") {
                store.deleteSession(session.id)
                Toast.show("Session deleted")
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
