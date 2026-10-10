import UIKit

/// The single moderation screen. It is reachable from a post, a comment, a
/// conversation, a profile and a clip, and it always offers the same four
/// choices — except for a clip, where the platform's own footage has no account
/// to block and the choice would do nothing.
///
/// Reporting removes the reported object locally: a reported post disappears
/// from the feed, a reported comment is deleted on the spot, and a reported
/// dancer is removed along with everything they posted. A reported clip is
/// recorded and left in place, so the module it belongs to keeps its shape.
final class ReportViewController: UIViewController {

    enum Target {
        case post(String)
        case comment(String)
        case user(String)
        case conversation(String)
        case video(String)
    }

    /// Called after the report is filed. `returnsToRoot` asks the presenter to
    /// unwind to the first-level screen it came from.
    var onFinish: ((_ returnsToRoot: Bool) -> Void)?

    private let target: Target
    private var selected: ReportReason?

    /// Clips are the platform's own footage, so blocking an account has nothing
    /// to act on and the choice is left out of the list.
    private var isVideo: Bool {
        if case .video = target { return true }
        return false
    }

    private var reasons: [ReportReason] {
        isVideo ? ReportReason.allCases.filter { $0 != .blockUser } : ReportReason.allCases
    }

    private let submitButton = PillButton("Submit Report", symbol: "flag.fill", style: .primary)
    private let closeButton = IconButton(symbol: "xmark", size: 38, background: .glass, pointSize: 14)
    private let detailField = FieldInput(label: "What happened?", placeholder: "Add any detail that helps us review this", symbol: "text.alignleft")
    private let detailContainer = UIView()
    private var optionRows: [(ReportReason, UIControl, UIImageView)] = []

    init(target: Target) {
        self.target = target
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)

        let scroll = ContentColumn(spacing: 20)
        scroll.setTopPadding(16)
        scroll.setBottomPadding(40)
        view.addSubviews(scroll)
        scroll.pinEdges(to: view)
        scroll.column.isLayoutMarginsRelativeArrangement = true

        scroll.add(makeHeader())
        scroll.add(makeTargetCard())
        scroll.add(makeOptions())
        scroll.add(makeDetailSection())
        scroll.add(submitButton)

        submitButton.isEnabled = false
        submitButton.onTap = { [weak self] in self?.submit() }
        detailField.onChange = { [weak self] _ in self?.refreshSubmitState() }

        installKeyboardDismissOnTap()
    }

    // MARK: - Sections

    private func makeHeader() -> UIView {
        let title = UILabel()
        title.text = "Report"
        title.font = .dancte(30, .black)
        title.textColor = Palette.text

        let subtitle = UILabel()
        subtitle.text = isVideo
            ? "Reports are reviewed by the Dancte team."
            : "Reports are reviewed by the Dancte team. You can also block this account to remove their content from your feed immediately."
        subtitle.font = Typo.body
        subtitle.textColor = Palette.textMuted
        subtitle.numberOfLines = 0

        closeButton.onTap = { [weak self] in self?.dismiss(animated: true) }

        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 8

        let row = UIStackView(arrangedSubviews: [text, closeButton])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func makeTargetCard() -> UIView {
        let card = SurfaceCard(colors: Grad.card, radius: 22, border: Palette.stroke)
        let icon = UIImageView()
        icon.tintColor = Palette.blaze
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true

        let title = UILabel()
        title.font = .dancte(15, .bold)
        title.textColor = Palette.text
        title.numberOfLines = 2

        let detail = UILabel()
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 3

        switch target {
        case let .post(id):
            icon.image = UIImage(systemName: "rectangle.stack.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))
            title.text = "Reporting a post"
            detail.text = store.post(id).map { "\u{201C}\($0.text.truncated(120))\u{201D}" } ?? "This post is no longer available."
        case let .comment(id):
            icon.image = UIImage(systemName: "bubble.left.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))
            title.text = "Reporting a comment"
            detail.text = store.comments.first { $0.id == id }.map { "\u{201C}\($0.text.truncated(120))\u{201D}" } ?? "This comment is no longer available."
        case let .user(id):
            icon.image = UIImage(systemName: "person.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))
            title.text = "Reporting @\(store.authorHandle(of: id))"
            detail.text = store.user(id)?.displayName ?? "This account is no longer available."
        case let .conversation(id):
            icon.image = UIImage(systemName: "bubble.left.and.bubble.right.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))
            title.text = "Reporting a conversation"
            detail.text = store.conversation(with: id).map { "Conversation with @\(store.authorHandle(of: $0.peerID))" } ?? "This conversation is no longer available."
        case let .video(id):
            icon.image = UIImage(systemName: "play.rectangle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))
            title.text = "Reporting a video"
            detail.text = store.spotlight.first { $0.id == id }
                .map { "\($0.title) · with \(store.authorName(of: $0.coachID))" }
                ?? "This video is no longer available."
        }

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 3

        let row = UIStackView(arrangedSubviews: [icon, text])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top

        card.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeOptions() -> UIView {
        let column = UIStackView(axis: .vertical, spacing: 10)
        for reason in reasons {
            let row = makeOptionRow(reason)
            column.addArrangedSubview(row)
        }
        return column
    }

    private func makeOptionRow(_ reason: ReportReason) -> UIControl {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.backgroundColor = Palette.surfaceHi.withAlphaComponent(0.6)
        control.layer.cornerRadius = 20
        control.layer.cornerCurve = .continuous
        control.layer.borderWidth = 1
        control.layer.borderColor = Palette.stroke.cgColor
        control.accessibilityLabel = reason.title

        let icon = UIImageView(image: UIImage(systemName: reason.symbol, withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)))
        icon.tintColor = reason == .blockUser ? Palette.magenta : Palette.textMuted
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.isUserInteractionEnabled = false

        let title = UILabel()
        title.text = reason.title
        title.font = .dancte(15, .bold)
        title.textColor = Palette.text

        let detail = UILabel()
        detail.text = reason.detail
        detail.font = Typo.caption
        detail.textColor = Palette.textMuted
        detail.numberOfLines = 2

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2
        text.isUserInteractionEnabled = false

        let check = UIImageView(image: UIImage(systemName: "circle", withConfiguration:
                                                UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)))
        check.tintColor = Palette.strokeHi
        check.contentMode = .center
        check.translatesAutoresizingMaskIntoConstraints = false
        check.isUserInteractionEnabled = false
        check.setContentHuggingPriority(.required, for: .horizontal)

        control.addSubviews(icon, text, check)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 16),
            icon.topAnchor.constraint(equalTo: control.topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 24),

            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: check.leadingAnchor, constant: -10),
            text.topAnchor.constraint(equalTo: control.topAnchor, constant: 15),
            text.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -15),

            check.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -16),
            check.centerYAnchor.constraint(equalTo: control.centerYAnchor)
        ])

        control.addAction(UIAction { [weak self] _ in
            Haptics.selection()
            self?.select(reason)
        }, for: .touchUpInside)

        optionRows.append((reason, control, check))
        return control
    }

    private func makeDetailSection() -> UIView {
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubviews(detailField)
        detailField.pinEdges(to: detailContainer)
        detailContainer.isHidden = true
        detailContainer.alpha = 0
        return detailContainer
    }

    // MARK: - Selection

    private func select(_ reason: ReportReason) {
        selected = reason
        for (candidate, control, check) in optionRows {
            let isOn = candidate == reason
            control.layer.borderColor = (isOn ? Palette.lime : Palette.stroke).cgColor
            control.backgroundColor = isOn ? Palette.lime.withAlphaComponent(0.12) : Palette.surfaceHi.withAlphaComponent(0.6)
            check.image = UIImage(systemName: isOn ? "largecircle.fill.circle" : "circle",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
            check.tintColor = isOn ? Palette.lime : Palette.strokeHi
        }

        let needsDetail = reason == .other
        if needsDetail != !detailContainer.isHidden {
            detailContainer.isHidden = false
            UIView.animate(withDuration: 0.24) {
                self.detailContainer.alpha = needsDetail ? 1 : 0
            } completion: { _ in
                self.detailContainer.isHidden = !needsDetail
            }
            if needsDetail { detailField.becomeFirstResponder() }
        }
        refreshSubmitState()
    }

    private func refreshSubmitState() {
        guard let selected else {
            submitButton.isEnabled = false
            return
        }
        submitButton.isEnabled = selected != .other || !detailField.text.isBlank
    }

    // MARK: - Submit

    private func submit() {
        guard let selected else { return }
        view.endEditing(true)

        let blocksUser = selected == .blockUser
        let returnsToRoot: Bool

        switch target {
        case let .post(id):
            if let post = store.post(id) {
                if blocksUser { store.purgeUser(post.authorID) } else { store.deletePost(id) }
            }
            returnsToRoot = true

        case let .comment(id):
            store.deleteComment(id)
            returnsToRoot = false

        case let .user(id):
            store.purgeUser(id)
            returnsToRoot = true

        case let .conversation(peerID):
            if blocksUser {
                store.purgeUser(peerID)
                returnsToRoot = true
            } else {
                // The transcript is kept; only the report is recorded.
                returnsToRoot = false
            }

        case .video:
            // The clip stays where it is — the report is what matters, and the
            // spotlight wall needs its five clips to keep its shape.
            returnsToRoot = false
        }

        Haptics.success()
        let message: String
        switch selected {
        case .blockUser: message = "Account blocked and removed"
        case .illegalContent, .inappropriateContent: message = "Report received. We'll review this."
        case .other: message = "Report received. Thank you."
        }

        let finish = onFinish
        dismiss(animated: true) {
            Toast.success(message)
            finish?(returnsToRoot)
        }
    }
}
