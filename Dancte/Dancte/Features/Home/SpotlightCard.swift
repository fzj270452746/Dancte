import UIKit

// MARK: - Mini transport

/// Compact playback readout for the small spotlight cards: a play/pause glyph,
/// a live progress line and a timecode. The enclosing card owns the gestures
/// (tap to toggle, double-tap a side to skip).
final class MiniTransportView: UIView {

    private let glyph = UIImageView()
    private let glyphBacking = UIView()
    private let timeLabel = UILabel()
    private let progress = UIView()
    private let track = UIView()
    private let accent: UIColor
    private var duration: Double = 0
    private var lastTime: Double = 0
    private var lastPlaying = false

    init(accent: UIColor, showsGlyph: Bool = true, showsTime: Bool = true) {
        self.accent = accent
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false

        track.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        track.translatesAutoresizingMaskIntoConstraints = false
        track.layer.cornerRadius = 1.5
        progress.backgroundColor = accent
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.layer.cornerRadius = 1.5
        addSubviews(track, progress)

        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            track.heightAnchor.constraint(equalToConstant: 3),
            progress.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            progress.centerYAnchor.constraint(equalTo: track.centerYAnchor),
            progress.heightAnchor.constraint(equalToConstant: 3)
        ])
        progressWidth = progress.widthAnchor.constraint(equalToConstant: 0)
        progressWidth.isActive = true

        timeLabel.font = .dancteMono(10.5, .bold)
        timeLabel.textColor = .white
        timeLabel.isHidden = !showsTime
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubviews(timeLabel)
        // The glyph owns the leading corner when there is one, so the timecode
        // takes the opposite end rather than sitting behind it.
        NSLayoutConstraint.activate([
            showsGlyph ? timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
                       : timeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: track.topAnchor, constant: -4)
        ])

        guard showsGlyph else { return }
        glyphBacking.backgroundColor = accent.withAlphaComponent(0.94)
        glyphBacking.layer.cornerRadius = 20
        glyphBacking.translatesAutoresizingMaskIntoConstraints = false
        addSubviews(glyphBacking)
        glyph.image = UIImage(systemName: "play.fill", withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        glyph.tintColor = Palette.ink
        glyph.contentMode = .center
        glyph.translatesAutoresizingMaskIntoConstraints = false
        glyphBacking.addSubviews(glyph)
        NSLayoutConstraint.activate([
            glyphBacking.leadingAnchor.constraint(equalTo: leadingAnchor),
            glyphBacking.bottomAnchor.constraint(equalTo: track.topAnchor, constant: -8),
            glyphBacking.widthAnchor.constraint(equalToConstant: 40),
            glyphBacking.heightAnchor.constraint(equalToConstant: 40),
            glyph.centerXAnchor.constraint(equalTo: glyphBacking.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: glyphBacking.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var progressWidth: NSLayoutConstraint!

    func attach(to player: ClipPlayer) {
        duration = player.duration
        apply(time: player.currentTime, playing: player.isPlaying)
    }

    /// Replaces the estimated length with the one the clip's file reports.
    func setDuration(_ seconds: Double) {
        guard seconds > 0 else { return }
        duration = seconds
        apply(time: min(lastTime, seconds), playing: lastPlaying)
    }

    func apply(time: Double, playing: Bool) {
        lastTime = time
        lastPlaying = playing
        timeLabel.text = "\(Format.duration(time)) · \(Format.duration(duration))"
        let ratio = duration > 0 ? CGFloat(time / duration) : 0
        progressWidth.isActive = false
        progressWidth = progress.widthAnchor.constraint(equalTo: track.widthAnchor,
                                                        multiplier: max(0.002, ratio))
        progressWidth.isActive = true
        let symbol = playing ? "pause.fill" : "play.fill"
        glyph.image = UIImage(systemName: symbol, withConfiguration:
                                UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        UIView.animate(withDuration: 0.18) {
            self.glyphBacking.transform = playing ? CGAffineTransform(scaleX: 0.82, y: 0.82) : .identity
            self.glyphBacking.alpha = playing ? 0.5 : 1
        }
    }
}

// MARK: - Spotlight card

/// One of the five featured clips. Each card gets a different layout so the
/// spotlight reads as a wall of work rather than a list of rows.
final class SpotlightCard: UIControl {

    enum Treatment {
        case hero       // full transport, big poster
        case tall       // staggered two-up
        case wide       // horizontal poster + copy
        case reel       // letterboxed cinema strip
    }

    var onOpenFull: ((DanceVideo) -> Void)?

    private let video: DanceVideo
    private let treatment: Treatment
    private let badgeIndex: Int

    private let artwork = ArtworkView(cornerRadius: 26)
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let levelChip = ChipView(text: "", accent: Palette.lime, horizontalPadding: 10, fontSize: 10.5)
    private let expandButton = IconButton(symbol: "arrow.up.left.and.arrow.down.right", size: 32,
                                          background: .glass, tint: .white, pointSize: 12)
    private let skipFlash = UILabel()

    private var transport: MiniTransportView?
    private var controlBar: ClipControlBar?
    private var player: ClipPlayer?
    private var metaLabel: UILabel?

    init(video: DanceVideo, treatment: Treatment, index: Int) {
        self.video = video
        self.treatment = treatment
        self.badgeIndex = index
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous

        artwork.setArtwork(assetName: video.posterName, seed: video.id)
        artwork.showsScrim = true
        artwork.roundCorners(26)
        artwork.isUserInteractionEnabled = false
        addSubviews(artwork)
        artwork.pinEdges(to: self)

        configureCopy()

        switch treatment {
        case .hero: buildHero()
        case .tall: buildTall()
        case .wide: buildWide()
        case .reel: buildReel()
        }

        // Added last so the affordance always sits above the artwork.
        addSubviews(expandButton)
        NSLayoutConstraint.activate([
            expandButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            expandButton.topAnchor.constraint(equalTo: topAnchor, constant: 14)
        ])
        expandButton.onTap = { [weak self] in self?.openFull() }

        // The card prints a running time before anything is played, so it asks
        // the file for the length straight away rather than waiting for a tap.
        VideoDuration.resolve(video.assetName) { [weak self] seconds in
            guard let self else { return }
            self.controlBar?.setDuration(seconds)
            self.transport?.setDuration(seconds)
            self.applyMeta(duration: seconds)
        }

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        // The transport bar sits inside the card: its buttons keep their taps.
        singleTap.delegate = ControlExemptTapDelegate.exclusive
        doubleTap.delegate = ControlExemptTapDelegate.exclusive
        addGestureRecognizer(singleTap)
        addGestureRecognizer(doubleTap)

        skipFlash.font = .dancteMono(16, .black)
        skipFlash.textColor = Palette.ink
        skipFlash.backgroundColor = Palette.lime.withAlphaComponent(0.94)
        skipFlash.textAlignment = .center
        skipFlash.layer.cornerRadius = 17
        skipFlash.clipsToBounds = true
        skipFlash.alpha = 0
        skipFlash.translatesAutoresizingMaskIntoConstraints = false
        addSubviews(skipFlash)
        NSLayoutConstraint.activate([
            skipFlash.centerXAnchor.constraint(equalTo: centerXAnchor),
            skipFlash.centerYAnchor.constraint(equalTo: centerYAnchor),
            skipFlash.widthAnchor.constraint(equalToConstant: 66),
            skipFlash.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layout builders

    private func configureCopy() {
        eyebrow.attributedText = NSAttributedString(
            string: String(format: "%02d", badgeIndex + 1),
            attributes: [.kern: 1.4, .font: UIFont.dancte(10.5, .black), .foregroundColor: video.style.accent]
        )
        titleLabel.text = video.title
        subtitleLabel.text = video.subtitle
        levelChip.setText(video.level.title)
    }

    private func buildHero() {
        artwork.roundCorners(30)
        layer.cornerRadius = 30

        let sport = UILabel()
        sport.attributedText = NSAttributedString(string: "SPOTLIGHT", attributes: [
            .kern: 2.4, .font: UIFont.dancte(10.5, .black), .foregroundColor: Palette.lime
        ])
        let coach = UILabel()
        coach.text = "with \(store.authorName(of: video.coachID))"
        coach.font = .dancte(12.5, .semibold)
        coach.textColor = UIColor.white.withAlphaComponent(0.8)

        let header = UIStackView(arrangedSubviews: [sport, coach])
        header.axis = .vertical
        header.spacing = 1

        let bar = ClipControlBar(showsTitles: true)
        bar.configure(title: video.title,
                      subtitle: "\(video.style.title) · \(video.level.title)",
                      duration: VideoDuration.known(video.assetName) ?? video.duration)
        bar.setAccent(video.style.accent)
        controlBar = bar

        addSubviews(header, bar)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1.16),

            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 18),

            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])

        titleLabel.isHidden = true
        subtitleLabel.isHidden = true
        levelChip.isHidden = true
        eyebrow.isHidden = true
    }

    private func buildTall() {
        titleLabel.font = .dancte(17, .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        subtitleLabel.font = .dancte(11.5, .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        subtitleLabel.numberOfLines = 2

        let transport = MiniTransportView(accent: video.style.accent, showsGlyph: true, showsTime: true)
        self.transport = transport

        addSubviews(eyebrow, titleLabel, subtitleLabel, levelChip, transport)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: heightAnchor, multiplier: 0.68),

            eyebrow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            eyebrow.topAnchor.constraint(equalTo: topAnchor, constant: 16),

            // The corner is the full-screen affordance on every card, so the
            // level sits under the card's number instead of claiming it.
            levelChip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            levelChip.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 6),

            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -4),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: transport.topAnchor, constant: -12),

            transport.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            transport.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            transport.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            transport.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    private func buildWide() {
        let poster = ArtworkView(cornerRadius: 20)
        poster.setArtwork(assetName: video.posterName, seed: video.id + "-wide")
        poster.isUserInteractionEnabled = false

        titleLabel.font = .dancte(18, .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        subtitleLabel.font = .dancte(12, .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitleLabel.numberOfLines = 2

        let meta = UILabel()
        metaLabel = meta
        applyMeta(duration: VideoDuration.known(video.assetName) ?? video.duration)

        let copy = UIStackView(arrangedSubviews: [meta, titleLabel, subtitleLabel])
        copy.axis = .vertical
        copy.spacing = 5
        copy.setCustomSpacing(9, after: meta)

        let transport = MiniTransportView(accent: video.style.accent, showsGlyph: true, showsTime: false)
        self.transport = transport

        addSubviews(poster, copy, transport)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 150),

            poster.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            poster.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            poster.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            poster.widthAnchor.constraint(equalTo: poster.heightAnchor),

            copy.leadingAnchor.constraint(equalTo: poster.trailingAnchor, constant: 16),
            copy.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            copy.centerYAnchor.constraint(equalTo: centerYAnchor),

            transport.leadingAnchor.constraint(equalTo: poster.trailingAnchor, constant: 16),
            transport.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            transport.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            transport.heightAnchor.constraint(equalToConstant: 44)
        ])
        eyebrow.isHidden = true
        levelChip.isHidden = true
    }

    /// The wide card wears the clip's stats as a kicker above its title, so the
    /// running time there has to follow the footage too.
    private func applyMeta(duration: Double) {
        metaLabel?.attributedText = NSAttributedString(
            string: "\(video.style.title.uppercased()) · \(Format.duration(duration)) · \(Format.compact(video.viewCount)) VIEWS",
            attributes: [.kern: 1.1, .font: UIFont.dancte(9.5, .bold), .foregroundColor: video.style.accent]
        )
    }

    private func buildReel() {
        titleLabel.font = .dancte(21, .black)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        let tag = UILabel()
        tag.attributedText = NSAttributedString(
            string: "LONG FORM · \(video.style.title.uppercased())",
            attributes: [.kern: 1.6, .font: UIFont.dancte(9.5, .bold), .foregroundColor: Palette.lime]
        )

        let transport = MiniTransportView(accent: Palette.lime, showsGlyph: true, showsTime: true)
        transport.backgroundColor = .clear
        self.transport = transport

        let copy = UIStackView(arrangedSubviews: [tag, titleLabel])
        copy.axis = .vertical
        copy.spacing = 4

        addSubviews(copy, transport)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.62),

            copy.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            copy.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -90),
            copy.bottomAnchor.constraint(equalTo: transport.topAnchor, constant: -12),

            transport.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            transport.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            transport.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            transport.heightAnchor.constraint(equalToConstant: 34)
        ])
        eyebrow.isHidden = true
        levelChip.isHidden = true
        subtitleLabel.isHidden = true
    }

    // MARK: Playback

    private var hasStarted = false

    private func ensurePlayer() -> ClipPlayer {
        if let player { return player }
        let created = ClipPlayer(assetName: video.assetName, duration: video.duration, hostView: artwork)
        created.onUpdate = { [weak self] time, playing in
            guard let self else { return }
            self.controlBar?.update(time: time, playing: playing)
            self.transport?.apply(time: time, playing: playing)
        }
        created.onFinish = { [weak self] in
            guard let self, let player = self.player else { return }
            self.controlBar?.update(time: player.duration, playing: false)
            self.transport?.apply(time: player.duration, playing: false)
        }
        created.onDurationReady = { [weak self] seconds in
            guard let self else { return }
            self.controlBar?.setDuration(seconds)
            self.transport?.setDuration(seconds)
            self.applyMeta(duration: seconds)
        }
        player = created

        if let controlBar {
            controlBar.onTogglePlay = { [weak created] in created?.toggle() }
            controlBar.onSkip = { [weak created] delta in created?.skip(delta) }
            controlBar.onScrub = { [weak created] value in created?.seek(to: value) }
            controlBar.onScrubEnd = { [weak created] value in created?.seek(to: value) }
        }
        transport?.attach(to: created)
        return created
    }

    @objc private func handleSingleTap() { toggle() }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let x = recognizer.location(in: self).x
        if x < bounds.midX {
            skip(-10, flash: "−10s")
        } else {
            skip(10, flash: "+10s")
        }
    }

    private func toggle() {
        let player = ensurePlayer()
        hasStarted = true
        player.toggle()
        artwork.pulse(1.012, duration: 0.12)
    }

    private func skip(_ delta: Double, flash: String) {
        let player = ensurePlayer()
        guard player.currentTime > 0 || player.isPlaying else {
            Haptics.warning()
            return
        }
        player.skip(delta)
        skipFlash.text = flash
        skipFlash.alpha = 1
        skipFlash.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.18) { self.skipFlash.transform = .identity }
        UIView.animate(withDuration: 0.3, delay: 0.42, animations: { self.skipFlash.alpha = 0 })
    }

    private func openFull() {
        Haptics.thump()
        onOpenFull?(video)
    }

    func stop() {
        player?.pause()
    }
}
