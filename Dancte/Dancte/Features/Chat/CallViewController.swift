import UIKit

/// A one-to-one video call.
///
/// The screen connects, then resolves into a declined state — the other dancer
/// is not available — and the call closes itself. The outcome is written back
/// into the conversation transcript.
final class CallViewController: UIViewController {

    /// Called with a short human-readable outcome once the call screen closes.
    var onFinish: ((String) -> Void)?

    private let peer: User?
    private let remoteArt = ArtworkView(cornerRadius: 0)
    private let avatar = AvatarView(size: 118)
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let timerLabel = UILabel()
    private let endButton = IconButton(symbol: "phone.down.fill", size: 66, background: .solid(Palette.magenta), tint: .white, pointSize: 24)
    private let muteButton = IconButton(symbol: "mic.slash.fill", size: 54, background: .glass, tint: .white, pointSize: 19)
    private let flipButton = IconButton(symbol: "camera.rotate.fill", size: 54, background: .glass, tint: .white, pointSize: 19)
    private let ringOne = CAShapeLayer()
    private let ringTwo = CAShapeLayer()
    private let avatarContainer = UIView()

    private var tickTimer: Timer?
    private var elapsed: Double = 0
    private var finished = false

    init(peer: User?) {
        self.peer = peer
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.ink

        buildStage()
        buildControls()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startRings()
        startTicking()
        Haptics.thump()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tickTimer?.invalidate()
    }

    // MARK: - Build

    private func buildStage() {
        remoteArt.setArtwork(assetName: "call_backdrop_\(peer?.id ?? "peer")",
                             seed: (peer?.id ?? "peer") + "-call")
        remoteArt.showsScrim = false
        remoteArt.alpha = 0.5
        view.addSubviews(remoteArt)
        remoteArt.pinEdges(to: view)

        let veil = UIView()
        veil.backgroundColor = Palette.ink.withAlphaComponent(0.55)
        view.addSubviews(veil)
        veil.pinEdges(to: view)

        avatar.configure(user: peer)
        avatar.layer.borderWidth = 3
        avatar.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.backgroundColor = .clear
        for ring in [ringOne, ringTwo] {
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = (peer?.styles.first?.accent ?? Palette.lime).cgColor
            ring.lineWidth = 2
            avatarContainer.layer.addSublayer(ring)
        }
        avatarContainer.addSubviews(avatar)

        let nameLabel = UILabel()
        nameLabel.text = peer?.displayName ?? "Dancte Dancer"
        nameLabel.font = .dancte(30, .black)
        nameLabel.textColor = Palette.text

        statusLabel.font = .dancte(15, .semibold)
        statusLabel.textColor = Palette.lime
        statusLabel.textAlignment = .center

        detailLabel.font = Typo.body
        detailLabel.textColor = Palette.textMuted
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 2

        timerLabel.font = .dancteMono(13, .bold)
        timerLabel.textColor = Palette.textFaint
        timerLabel.textAlignment = .center

        let column = UIStackView(arrangedSubviews: [avatarContainer, nameLabel, statusLabel, detailLabel, timerLabel])
        column.axis = .vertical
        column.spacing = 10
        column.alignment = .center
        column.setCustomSpacing(22, after: avatarContainer)
        column.setCustomSpacing(16, after: detailLabel)

        view.addSubviews(column)
        NSLayoutConstraint.activate([
            avatarContainer.widthAnchor.constraint(equalToConstant: 200),
            avatarContainer.heightAnchor.constraint(equalToConstant: 200),
            avatar.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),

            column.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            column.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            column.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            column.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30)
        ])
    }

    private func buildControls() {
        let row = UIStackView(arrangedSubviews: [muteButton, endButton, flipButton])
        row.axis = .horizontal
        row.spacing = 30
        row.alignment = .center

        view.addSubviews(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            row.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])

        muteButton.isActive = false
        muteButton.onTap = { [weak self] in
            guard let self else { return }
            self.muteButton.isActive.toggle()
            self.muteButton.setSymbol(self.muteButton.isActive ? "mic.fill" : "mic.slash.fill")
            Toast.show(self.muteButton.isActive ? "Microphone on" : "Microphone muted")
        }
        flipButton.onTap = {
            Haptics.tap()
            Toast.show("Camera flipped")
        }
        endButton.onTap = { [weak self] in self?.end(outcome: "Ended") }
    }

    // MARK: - Behaviour

    private func startRings() {
        guard avatarContainer.bounds.width > 0 else {
            DispatchQueue.main.async { self.startRings() }
            return
        }
        for (index, ring) in [ringOne, ringTwo].enumerated() {
            let inset: CGFloat = 26 + CGFloat(index) * 18
            let rect = avatarContainer.bounds.insetBy(dx: inset, dy: inset)
            ring.path = UIBezierPath(ovalIn: rect).cgPath
            ring.frame = avatarContainer.bounds

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.86
            scale.toValue = 1.16
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.85
            fade.toValue = 0

            let group = CAAnimationGroup()
            group.animations = [scale, fade]
            group.duration = 2.0
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.55
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ring.add(group, forKey: "pulse")
        }
    }

    private func startTicking() {
        statusLabel.text = "Calling…"
        detailLabel.text = "Waiting for \(peer?.displayName ?? "them") to answer."

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed += 0.1
            self.timerLabel.text = Format.duration(self.elapsed)
            if self.elapsed >= 5.0 { self.decline() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func decline() {
        guard !finished else { return }
        finished = true
        tickTimer?.invalidate()
        Haptics.warning()

        statusLabel.text = "Call Declined"
        statusLabel.textColor = Palette.magenta
        detailLabel.text = "\(peer?.displayName ?? "They") can't take your call right now."
        timerLabel.text = nil

        UIView.animate(withDuration: 0.2) {
            self.endButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [weak self] in
            self?.finish(outcome: "Declined")
        }
    }

    private func end(outcome: String) {
        guard !finished else { return }
        finished = true
        finish(outcome: outcome)
    }

    private func finish(outcome: String) {
        tickTimer?.invalidate()
        let handler = onFinish
        dismiss(animated: true) {
            Toast.show(outcome == "Declined" ? "Call declined" : "Call ended",
                       kind: outcome == "Declined" ? .warning : .info)
            handler?(outcome)
        }
    }
}
