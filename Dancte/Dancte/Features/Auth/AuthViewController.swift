import AuthenticationServices
import UIKit

// MARK: - Why a dancer is being asked to sign in

struct AuthReason {
    let title: String
    let message: String
    let symbol: String
    let accent: UIColor

    static let like = AuthReason(title: "Save what you love",
                                 message: "Sign in to like, save and comment on posts.",
                                 symbol: "heart.fill", accent: Palette.magenta)

    static let comment = AuthReason(title: "Join the conversation",
                                    message: "Sign in to leave a comment and support other dancers.",
                                    symbol: "bubble.left.fill", accent: Palette.cyan)

    static let publish = AuthReason(title: "Share your work",
                                    message: "Sign in to publish posts, clips and practice updates.",
                                    symbol: "paperplane.fill", accent: Palette.lime)

    static let chat = AuthReason(title: "Your crew is waiting",
                                 message: "Sign in to see your conversations and the dancers you train with.",
                                 symbol: "bubble.left.and.bubble.right.fill", accent: Palette.violet)

    static let profile = AuthReason(title: "Your studio",
                                    message: "Sign in to manage your profile, your works and your training log.",
                                    symbol: "person.crop.circle.fill", accent: Palette.blaze)

    static let studio = AuthReason(title: "Keep your log",
                                   message: "Sign in to record practice sessions and keep your streak alive.",
                                   symbol: "flame.fill", accent: Palette.blaze)

    static let general = AuthReason(title: "Welcome to Dancte",
                                    message: "Sign in to unlock posting, messaging and your training log.",
                                    symbol: "sparkles", accent: Palette.lime)
}

// MARK: - Gate

enum AuthGate {

    /// Runs `then` when a dancer is signed in; otherwise presents the auth
    /// sheet and runs `then` after they successfully sign in.
    @discardableResult
    static func require(_ reason: AuthReason,
                        from controller: UIViewController,
                        then work: @escaping () -> Void) -> Bool {
        guard !store.isSignedIn else {
            work()
            return true
        }
        let host = controller.topMost
        let auth = AuthViewController(reason: reason)
        auth.onAuthenticated = work
        auth.modalPresentationStyle = .pageSheet
        host.present(auth, animated: true)
        return false
    }
}

// MARK: - Auth screen

final class AuthViewController: UIViewController {

    enum Mode: Int {
        case signIn, register

        var title: String { self == .signIn ? "Sign In" : "Create Account" }
        var action: String { self == .signIn ? "Sign In" : "Create Account" }
    }

    var onAuthenticated: (() -> Void)?

    private let reason: AuthReason?
    private var mode: Mode = .signIn

    private let scroll = UIScrollView()
    private let column = UIStackView(axis: .vertical, spacing: 16)
    private let modePills: SegmentedPills
    private let reasonCard = SurfaceCard(colors: Grad.card, radius: 22, border: Palette.stroke)
    private let reasonIcon = UIImageView()
    private let reasonTitle = UILabel()
    private let reasonMessage = UILabel()

    private let nameField = FieldInput(label: "Display name", placeholder: "How other dancers see you", symbol: "person.fill")
    private let handleField = FieldInput(label: "Username", placeholder: "Choose a username", symbol: "at")
    private let secretField = FieldInput(label: "Password", placeholder: "At least 6 characters", kind: .password, symbol: "lock.fill")
    // "lock.rotate" is not a real SF Symbol, so the field rendered with no icon at
    // all. "lock.rotation" is the shipped name for the same idea.
    private let confirmField = FieldInput(label: "Confirm password", placeholder: "Repeat your password", kind: .password, symbol: "lock.rotation")

    private let submitButton = PillButton("Sign In", symbol: "arrow.right", style: .primary)
    private let appleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .continue, authorizationButtonStyle: .white)
    private let closeButton = IconButton(symbol: "xmark", size: 40, background: .glass, pointSize: 14)
    private let footer = LegalConsentFooter()
    private let switchLabel = UILabel()

    private var isBusy = false

    init(reason: AuthReason? = nil) {
        self.reason = reason
        self.modePills = SegmentedPills(items: ["Sign In", "Create Account"], accent: Palette.lime)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        buildBackground()
        buildLayout()
        applyMode(.signIn, animated: false)
        installKeyboardDismissOnTap()
        observeKeyboard()

        submitButton.onTap = { [weak self] in self?.submit() }
        secretField.onReturn = { [weak self] in self?.submit() }
        confirmField.onReturn = { [weak self] in self?.submit() }
        handleField.onReturn = { [weak self] in
            self?.secretField.becomeFirstResponder()
        }
        modePills.onSelect = { [weak self] index in
            guard let mode = Mode(rawValue: index) else { return }
            self?.applyMode(mode)
        }
        closeButton.onTap = { [weak self] in self?.dismiss(animated: true) }
        appleButton.addTarget(self, action: #selector(startAppleSignIn), for: .touchUpInside)
        footer.onOpen = { [weak self] document in
            guard let self else { return }
            let controller = LegalDocumentViewController(document: document)
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .pageSheet
            self.present(nav, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if mode == .signIn, handleField.text.isEmpty, !isBusy {
            handleField.becomeFirstResponder()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Layout

    private func buildBackground() {
        let backdrop = StudioBackdropView()
        view.addSubviews(backdrop)
        backdrop.pinEdges(to: view)
    }

    private func buildLayout() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        scroll.keyboardDismissMode = .interactive
        scroll.contentInsetAdjustmentBehavior = .never
        // The footer has to be in the hierarchy before the scroll view's bottom
        // edge is tied to its top: NSLayoutConstraint.activate raises when the
        // two anchors share no common ancestor.
        view.addSubviews(scroll, closeButton, footer)

        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -10),

            // Dismiss lives in the top-right corner, mirroring the sheet's own
            // chrome instead of crowding the wordmark on the left.
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metric.gutter),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),

            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Metric.gutter),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Metric.gutter),
            // Clears the close button docked in the top-right corner.
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 56),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -Metric.gutter * 2)
        ])

        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metric.gutter),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metric.gutter),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])

        column.addArrangedSubview(makeHeader())
        column.setCustomSpacing(24, after: column.arrangedSubviews[0])

        column.addArrangedSubview(buildReasonCard())
        reasonCard.isHidden = reason == nil
        if reason == nil { column.setCustomSpacing(6, after: reasonCard) }

        column.addArrangedSubview(modePills)
        column.setCustomSpacing(20, after: modePills)

        let fields = UIStackView(arrangedSubviews: [nameField, handleField, secretField, confirmField])
        fields.axis = .vertical
        fields.spacing = 14
        column.addArrangedSubview(fields)

        column.setCustomSpacing(22, after: fields)
        column.addArrangedSubview(submitButton)

        let divider = makeDivider()
        column.addArrangedSubview(divider)

        let appleContainer = UIView()
        appleContainer.translatesAutoresizingMaskIntoConstraints = false
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.cornerRadius = 27
        appleContainer.addSubviews(appleButton)
        NSLayoutConstraint.activate([
            appleContainer.heightAnchor.constraint(equalToConstant: 54),
            appleButton.leadingAnchor.constraint(equalTo: appleContainer.leadingAnchor),
            appleButton.trailingAnchor.constraint(equalTo: appleContainer.trailingAnchor),
            appleButton.topAnchor.constraint(equalTo: appleContainer.topAnchor),
            appleButton.bottomAnchor.constraint(equalTo: appleContainer.bottomAnchor)
        ])
        column.addArrangedSubview(appleContainer)

        switchLabel.font = Typo.caption
        switchLabel.textColor = Palette.textMuted
        switchLabel.textAlignment = .center
        switchLabel.numberOfLines = 0
        switchLabel.isUserInteractionEnabled = true
        switchLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleMode)))
        column.addArrangedSubview(switchLabel)

        // Keeps the footer rule prominent on the sheet.
        column.setCustomSpacing(28, after: appleContainer)
    }

    private func makeHeader() -> UIView {
        let wordmark = UILabel()
        wordmark.attributedText = NSAttributedString(string: "DANCTE", attributes: [
            .kern: 6, .font: UIFont.dancte(30, .black), .foregroundColor: Palette.text
        ])
        let tagline = UILabel()
        tagline.text = "TRAIN · POST · CONNECT"
        tagline.attributedText = NSAttributedString(string: "TRAIN · POST · CONNECT", attributes: [
            .kern: 2.4, .font: UIFont.dancte(10.5, .bold), .foregroundColor: Palette.lime
        ])
        let blurb = UILabel()
        blurb.text = "A home for dancers: share your clips, log every session, and build a crew."
        blurb.font = Typo.body
        blurb.textColor = Palette.textMuted
        blurb.numberOfLines = 0

        // No brand tile up here: the wordmark alone anchors the sheet, which keeps
        // the header compact and leaves the top-right corner to the close button.
        let stack = UIStackView(arrangedSubviews: [wordmark, tagline, blurb])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.setCustomSpacing(2, after: wordmark)
        stack.setCustomSpacing(12, after: tagline)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func buildReasonCard() -> UIView {
        reasonIcon.contentMode = .center
        reasonTitle.font = .dancte(16, .bold)
        reasonTitle.textColor = Palette.text
        reasonMessage.font = Typo.caption
        reasonMessage.textColor = Palette.textMuted
        reasonMessage.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [reasonTitle, reasonMessage])
        text.axis = .vertical
        text.spacing = 3

        let row = UIStackView(arrangedSubviews: [reasonIcon, text])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        reasonIcon.setContentHuggingPriority(.required, for: .horizontal)
        reasonIcon.translatesAutoresizingMaskIntoConstraints = false
        reasonIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true

        reasonCard.addSubviews(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: reasonCard.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: reasonCard.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: reasonCard.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: reasonCard.bottomAnchor, constant: -16)
        ])

        if let reason {
            reasonIcon.image = UIImage(systemName: reason.symbol,
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold))
            reasonIcon.tintColor = reason.accent
            reasonTitle.text = reason.title
            reasonMessage.text = reason.message
            reasonCard.setBorderColor(reason.accent.withAlphaComponent(0.35))
            reasonCard.setColors([reason.accent.withAlphaComponent(0.16), Palette.surface])
        }
        return reasonCard
    }

    private func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = Palette.stroke
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let label = UILabel()
        label.text = "OR"
        label.font = .dancte(10.5, .bold)
        label.textColor = Palette.textFaint
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubviews(line, label)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 20),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        // Punch a gap around the label so the rule reads as two segments.
        let mask = UIView()
        mask.backgroundColor = Palette.ink
        mask.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(mask, aboveSubview: line)
        NSLayoutConstraint.activate([
            mask.centerXAnchor.constraint(equalTo: label.centerXAnchor),
            mask.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            mask.widthAnchor.constraint(equalToConstant: 44),
            mask.heightAnchor.constraint(equalToConstant: 18)
        ])
        container.bringSubviewToFront(label)
        return container
    }

    // MARK: - State

    private func applyMode(_ mode: Mode, animated: Bool = true) {
        self.mode = mode
        modePills.selectedIndex = mode.rawValue

        let changes = {
            self.nameField.isHidden = mode == .signIn
            self.nameField.alpha = mode == .signIn ? 0 : 1
            self.confirmField.isHidden = mode == .signIn
            self.confirmField.alpha = mode == .signIn ? 0 : 1
            self.submitButton.title = mode.action
            self.switchLabel.text = mode == .signIn
                ? "New to Dancte? Tap to create an account."
                : "Already training with us? Tap to sign in."
            self.nameField.showError(nil)
            self.handleField.showError(nil)
            self.secretField.showError(nil)
            self.confirmField.showError(nil)
        }

        if animated {
            UIView.animate(withDuration: 0.24, animations: changes)
        } else {
            changes()
        }
    }

    @objc private func toggleMode() {
        applyMode(mode == .signIn ? .register : .signIn)
    }

    // MARK: - Submission

    private func submit() {
        guard !isBusy else { return }
        view.endEditing(true)

        let handle = handleField.text.trimmed
        let secret = secretField.text

        switch mode {
        case .signIn:
            guard !handle.isBlank else { return handleField.showError("Enter your username.") }
            guard !secret.isBlank else { return secretField.showError("Enter your password.") }
            perform(message: "Signing in") {
                try store.signIn(handle: handle, secret: secret)
            }
        case .register:
            guard !handle.isBlank else { return handleField.showError("Choose a username.") }
            guard secret.count >= 6 else { return secretField.showError("Use at least 6 characters.") }
            guard secret == confirmField.text else { return confirmField.showError("Those passwords don't match.") }
            let displayName = nameField.text
            let confirmation = confirmField.text
            perform(message: "Creating your account") {
                let user = try store.register(handle: handle, secret: secret, confirmation: confirmation)
                if !displayName.isBlank {
                    store.updateProfile(displayName: displayName, handle: user.handle, bio: user.bio,
                                        city: user.city, crew: user.crew, styles: user.styles, avatarName: nil)
                }
            }
        }
    }

    private func perform(message: String, work: @escaping () throws -> Void) {
        isBusy = true
        submitButton.isEnabled = false
        runLoadingBeat(message) { [weak self] in
            guard let self else { return }
            do {
                try work()
                Haptics.success()
                self.complete()
            } catch {
                self.isBusy = false
                self.submitButton.isEnabled = true
                let text = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
                Toast.error(text)
                self.secretField.showError(text)
            }
        }
    }

    @objc private func startAppleSignIn() {
        guard !isBusy else { return }
        view.endEditing(true)
        isBusy = true
        appleButton.isEnabled = false

        AppleSignInService.shared.start(anchor: view.window ?? ASPresentationAnchor()) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(credential):
                self.runLoadingBeat("Signing you in") {
                    do {
                        try store.signInWithApple(userIdentifier: credential.userIdentifier,
                                                  displayName: credential.displayName,
                                                  email: credential.email)
                        Haptics.success()
                        self.complete()
                    } catch {
                        self.finishWithFailure((error as? LocalizedError)?.errorDescription ?? "Sign in failed.")
                    }
                }
            case let .failure(error):
                if let signInError = error as? AppleSignInService.SignInError,
                   case .cancelled = signInError {
                    self.isBusy = false
                    self.appleButton.isEnabled = true
                    return
                }
                self.finishWithFailure((error as? LocalizedError)?.errorDescription ?? "Sign in failed.")
            }
        }
    }

    private func finishWithFailure(_ message: String) {
        isBusy = false
        appleButton.isEnabled = true
        submitButton.isEnabled = true
        Toast.error(message)
    }

    private func complete() {
        isBusy = false
        submitButton.isEnabled = true
        appleButton.isEnabled = true
        Toast.success("Welcome to Dancte", detail: store.currentUser.map { "@\($0.handle)" })
        let work = onAuthenticated
        dismiss(animated: true) { work?() }
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        let inset = max(0, overlap - view.safeAreaInsets.bottom)
        scroll.contentInset.bottom = inset
        scroll.verticalScrollIndicatorInsets.bottom = inset
    }
}
