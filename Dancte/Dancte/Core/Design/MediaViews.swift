import UIKit

// MARK: - Artwork

/// Renders a resource key: the file from the art pack when it is installed,
/// and nothing at all when it is not, so the interface never invents imagery.
final class ArtworkView: UIView {

    private let imageView = UIImageView()
    private let scrim = CAGradientLayer()
    private var videoLayer: CALayer?
    private(set) var seed: String = ""

    var showsScrim: Bool = false {
        didSet { scrim.isHidden = !showsScrim }
    }

    init(cornerRadius: CGFloat = 0, contentMode: UIView.ContentMode = .scaleAspectFill) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        backgroundColor = Palette.surface

        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        imageView.pinEdges(to: self)

        scrim.colors = [UIColor.black.withAlphaComponent(0).cgColor,
                        UIColor.black.withAlphaComponent(0.12).cgColor,
                        UIColor.black.withAlphaComponent(0.78).cgColor]
        scrim.locations = [0, 0.45, 1]
        scrim.isHidden = true
        layer.addSublayer(scrim)

        if cornerRadius > 0 { roundCorners(cornerRadius) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scrim.frame = bounds
        videoLayer?.frame = bounds
        CATransaction.commit()
        bringScrimToFront()
    }

    private func bringScrimToFront() {
        guard scrim.superlayer === layer else { return }
        // The scrim sits above whatever is showing, so overlay text keeps its
        // contrast whether the surface is a still or a running clip.
        layer.insertSublayer(scrim, above: videoLayer ?? imageView.layer)
    }

    func setArtwork(assetName: String, seed: String) {
        self.seed = seed
        imageView.image = Assets.image(assetName)
    }

    /// Fills the view for a post's media. A clip with no delivered still falls
    /// back to a frame of the clip itself once it has been read off disk.
    func setMediaArtwork(_ item: MediaItem) {
        setArtwork(assetName: item.assetName, seed: item.id)
        guard imageView.image == nil, item.kind == .video else { return }
        VideoPoster.frame(forVideoNamed: item.assetName) { [weak self] image in
            self?.setImage(image)
        }
    }

    // MARK: - Clip surface

    /// Hosts a clip's picture above the still and beneath the scrim.
    func attachVideoLayer(_ layer: CALayer) {
        videoLayer?.removeFromSuperlayer()
        videoLayer = layer
        self.layer.insertSublayer(layer, above: imageView.layer)
        setNeedsLayout()
    }

    func detachVideoLayer() {
        videoLayer?.removeFromSuperlayer()
        videoLayer = nil
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
    }

    var image: UIImage? { imageView.image }
}

// MARK: - Gift artwork

/// The tile a gift is drawn in: the illustration from the art pack when the
/// file is installed, and the tier glyph on a solid accent tile when it is not,
/// so a gift whose art has not shipped still reads as a gift rather than as a
/// hole in the grid.
final class GiftArtView: UIView {

    private let imageView = UIImageView()
    private let glyph = UIImageView()

    /// - Parameters:
    ///   - tile: side of the tile. The illustration is inset inside it so
    ///     packed art never touches the rounded edge.
    ///   - glyphPointSize: weight of the fallback glyph, which stands in for
    ///     the illustration at whatever size the caller's tile allows.
    init(gift: Gift, tile: CGFloat = 56, glyphPointSize: CGFloat = 24) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = tile * 0.32
        layer.cornerCurve = .continuous
        layer.shadowColor = gift.accent.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        glyph.contentMode = .center
        glyph.translatesAutoresizingMaskIntoConstraints = false

        addSubviews(imageView, glyph)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: tile),
            heightAnchor.constraint(equalToConstant: tile),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: tile * 0.82),
            imageView.heightAnchor.constraint(equalToConstant: tile * 0.82),
            glyph.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        imageView.image = Assets.image(gift.assetName)
        let hasArt = imageView.image != nil
        imageView.isHidden = !hasArt
        glyph.isHidden = hasArt

        // Delivered art brings its own palette, so the tile only tints it with
        // the tier colour; the glyph needs the tile painted in full to read.
        backgroundColor = hasArt ? gift.accent.withAlphaComponent(0.16) : gift.accent
        layer.borderWidth = hasArt ? 1 : 0
        layer.borderColor = gift.accent.withAlphaComponent(0.45).cgColor

        glyph.image = UIImage(systemName: gift.symbol, withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .bold))
        glyph.tintColor = Palette.ink
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Duration badge

final class DurationBadge: UIView {

    private let label = UILabel()

    init(duration: Double) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous

        label.text = Format.duration(duration)
        label.font = .dancteMono(11, .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Corrections arrive once the clip's file reports its own length.
    func setDuration(_ seconds: Double) {
        label.text = Format.duration(seconds)
    }
}

// MARK: - Scrub bar

/// Interactive timeline used by the hero clip, the full-screen player and the
/// practice timer. Reports a 0…1 position while dragging.
final class ScrubBar: UIControl {

    var onScrub: ((CGFloat) -> Void)?
    var onScrubEnd: ((CGFloat) -> Void)?

    private let track = UIView()
    private let fill = UIView()
    private let thumb = UIView()
    private let buffered = UIView()
    private var height: CGFloat

    private(set) var isDragging = false

    var progress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    var bufferProgress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    var accent: UIColor = Palette.lime {
        didSet { fill.backgroundColor = accent; thumb.backgroundColor = accent }
    }

    init(height: CGFloat = 6) {
        self.height = height
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        track.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        buffered.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        fill.backgroundColor = accent
        thumb.backgroundColor = accent
        thumb.layer.shadowColor = accent.cgColor
        thumb.layer.shadowOpacity = 0.6
        thumb.layer.shadowRadius = 6
        thumb.layer.shadowOffset = .zero

        // The bar is the touch surface; the rails drawn on it must not take the
        // touch, or a scrub that starts on the thumb never reaches the control.
        [buffered, track, fill, thumb].forEach {
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([heightAnchor.constraint(equalToConstant: max(height, 22))])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = bounds.height / 2
        let radius = height / 2
        track.frame = CGRect(x: 0, y: midY - radius, width: bounds.width, height: height)
        track.layer.cornerRadius = radius
        buffered.frame = CGRect(x: 0, y: midY - radius, width: bounds.width * bufferProgress, height: height)
        buffered.layer.cornerRadius = radius
        let thumbSize: CGFloat = 14
        let usable = bounds.width - thumbSize
        let originX = usable * min(max(progress, 0), 1)
        fill.frame = CGRect(x: 0, y: midY - radius, width: originX + thumbSize / 2, height: height)
        fill.layer.cornerRadius = radius
        thumb.frame = CGRect(x: originX, y: midY - thumbSize / 2, width: thumbSize, height: thumbSize)
        thumb.layer.cornerRadius = thumbSize / 2
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        isDragging = true
        setProgress(from: touch)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        setProgress(from: touch)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isDragging = false
        onScrubEnd?(progress)
    }

    override func cancelTracking(with event: UIEvent?) {
        isDragging = false
        onScrubEnd?(progress)
    }

    /// Grows the hit area so a 6pt bar is still comfortably draggable.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -12, dy: -14).contains(point)
    }

    private func setProgress(from touch: UITouch) {
        let x = touch.location(in: self).x
        let thumbSize: CGFloat = 14
        let usable = max(1, bounds.width - thumbSize)
        let value = min(max((x - thumbSize / 2) / usable, 0), 1)
        progress = CGFloat(value)
        Haptics.selection()
        onScrub?(progress)
    }
}

// MARK: - Clip controls

/// Transport controls shared by the hero card and the full-screen player.
final class ClipControlBar: UIView {

    private let playButton = IconButton(symbol: "play.fill", size: 46, background: .gradient(Grad.lime), pointSize: 17)
    private let backButton = IconButton(symbol: "gobackward.10", size: 38, background: .glass, tint: .white, pointSize: 14)
    private let forwardButton = IconButton(symbol: "goforward.10", size: 38, background: .glass, tint: .white, pointSize: 14)
    private let timeLabel = UILabel()
    private let scrub = ScrubBar(height: 5)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private var duration: Double = 0
    private var lastTime: Double = 0
    private var lastPlaying = false

    init(showsTitles: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .dancteMono(11.5, .bold)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .right

        titleLabel.font = .dancte(17, .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1

        subtitleLabel.font = Typo.caption
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.numberOfLines = 1

        let transport = UIStackView(axis: .horizontal, spacing: 12, alignment: .center)
        transport.addArrangedSubview(backButton)
        transport.addArrangedSubview(playButton)
        transport.addArrangedSubview(forwardButton)
        transport.addArrangedSubview(UIView())
        transport.addArrangedSubview(timeLabel)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let column = UIStackView(axis: .vertical, spacing: 10)
        if showsTitles {
            column.addArrangedSubview(titleLabel)
            column.addArrangedSubview(subtitleLabel)
            column.setCustomSpacing(14, after: subtitleLabel)
        }
        column.addArrangedSubview(scrub)
        column.addArrangedSubview(transport)
        addSubview(column)
        column.pinEdges(to: self)

        scrub.onScrub = { [weak self] value in
            self?.onScrub?(Double(value))
        }
        scrub.onScrubEnd = { [weak self] value in
            self?.onScrubEnd?(Double(value))
        }
        playButton.onTap = { [weak self] in self?.onTogglePlay?() }
        backButton.onTap = { [weak self] in self?.onSkip?(-10) }
        forwardButton.onTap = { [weak self] in self?.onSkip?(10) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var onTogglePlay: (() -> Void)?
    var onSkip: ((Double) -> Void)?
    var onScrub: ((Double) -> Void)?
    var onScrubEnd: ((Double) -> Void)?

    func configure(title: String, subtitle: String, duration: Double) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        self.duration = duration
        update(time: 0, playing: false)
    }

    func update(time: Double, playing: Bool) {
        lastTime = time
        lastPlaying = playing
        timeLabel.text = "\(Format.duration(time)) / \(Format.duration(duration))"
        if !scrub.isDragging {
            scrub.progress = duration > 0 ? CGFloat(time / duration) : 0
        }
        let symbol = playing ? "pause.fill" : "play.fill"
        playButton.setSymbol(symbol, weight: .bold)
    }

    /// Replaces the estimated length with the one the clip's file reports.
    func setDuration(_ seconds: Double) {
        guard seconds > 0 else { return }
        duration = seconds
        update(time: min(lastTime, seconds), playing: lastPlaying)
    }

    func setAccent(_ color: UIColor) {
        scrub.accent = color
        playButton.setBackground(.gradient(Grad.forColor(color)))
    }
}

// MARK: - Full screen clip player

final class ClipPlayerViewController: UIViewController {

    /// Asks the presenter to file a report about this clip. Hidden when the
    /// presenter has nowhere to send it.
    var onReport: (() -> Void)?

    private let video: DanceVideo
    private var player: ClipPlayer!
    private let stage = ArtworkView(cornerRadius: 0)
    private let controls = ClipControlBar(showsTitles: true)
    private let closeButton = IconButton(symbol: "xmark", size: 42, background: .glass, tint: .white, pointSize: 15)
    private let reportButton = IconButton(symbol: "flag", size: 42, background: .glass, tint: .white, pointSize: 15)
    private let centerPlay = IconButton(symbol: "play.fill", size: 76, background: .gradient(Grad.lime), pointSize: 30)

    init(video: DanceVideo) {
        self.video = video
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let coach = store.user(video.coachID)

        stage.setArtwork(assetName: video.posterName, seed: video.id)
        stage.showsScrim = false
        view.addSubviews(stage, closeButton, reportButton, centerPlay)

        controls.configure(title: video.title,
                           subtitle: "\(video.style.title) · \(video.level.title) · \(store.authorName(of: video.coachID))",
                           duration: VideoDuration.known(video.assetName) ?? video.duration)
        controls.setAccent(video.style.accent)
        view.addSubviews(controls)

        _ = coach

        reportButton.isHidden = onReport == nil
        reportButton.onTap = { [weak self] in
            guard let self else { return }
            self.player.pause()
            self.onReport?()
        }

        player = ClipPlayer(assetName: video.assetName, duration: video.duration, hostView: stage)
        player.onUpdate = { [weak self] time, playing in
            self?.controls.update(time: time, playing: playing)
            self?.centerPlay.isHidden = playing
        }
        player.onFinish = { [weak self] in
            self?.centerPlay.isHidden = false
        }
        player.onDurationReady = { [weak self] seconds in
            self?.controls.setDuration(seconds)
        }

        controls.onTogglePlay = { [weak self] in self?.player.toggle() }
        controls.onSkip = { [weak self] delta in self?.player.skip(delta) }
        controls.onScrub = { [weak self] value in self?.player.seek(to: value) }
        controls.onScrubEnd = { [weak self] value in self?.player.seek(to: value) }
        centerPlay.onTap = { [weak self] in self?.player.play() }
        closeButton.onTap = { [weak self] in
            self?.player.pause()
            self?.dismiss(animated: true)
        }

        // Tap the stage to toggle, exactly like the compact cards.
        let tap = UITapGestureRecognizer(target: self, action: #selector(togglePlay))
        stage.addGestureRecognizer(tap)
        stage.isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            stage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stage.topAnchor.constraint(equalTo: view.topAnchor),
            stage.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metric.gutter),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            reportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metric.gutter),
            reportButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            centerPlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerPlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metric.gutter),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metric.gutter),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
    }

    @objc private func togglePlay() {
        player.toggle()
        centerPlay.isHidden = player.isPlaying
    }
}
