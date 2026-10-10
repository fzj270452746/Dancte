import AVFoundation
import UIKit

/// Playback engine for every clip surface in the app.
///
/// When the real video file for a resource key is present in the bundle the
/// player drives an `AVPlayer`; when it is not, the same transport controls
/// drive an internal clock of identical length. Either way the timeline, the
/// scrubber, the skip buttons and the timecode behave exactly the same, so the
/// interface is complete before the footage arrives.
final class ClipPlayer {

    enum Source {
        case asset(URL)
        case timeline
    }

    let assetName: String
    /// The clip's length. It starts as the caller's estimate and is replaced by
    /// the real length of the file as soon as that is known, so the timeline and
    /// every timecode follow the footage rather than the guess.
    private(set) var duration: Double
    private let source: Source

    private var avPlayer: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserver: Any?
    private var ticker: Timer?
    private var lastTickStamp: CFTimeInterval = 0

    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false

    /// Called on the main thread roughly ten times a second while the clip runs.
    var onUpdate: ((Double, Bool) -> Void)?
    var onFinish: (() -> Void)?
    /// Called once the file reports its own length, so a surface that printed a
    /// total from the estimate can correct it.
    var onDurationReady: ((Double) -> Void)?

    private(set) weak var hostView: UIView?

    init(assetName: String, duration: Double, hostView: UIView? = nil) {
        self.assetName = assetName
        self.duration = max(1, duration)
        self.hostView = hostView

        if let url = Assets.videoURL(assetName) {
            source = .asset(url)
        } else {
            source = .timeline
        }

        if case let .asset(url) = source {
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.actionAtItemEnd = .pause
            avPlayer = player
            observe(player)
            attachPicture(player)
        }

        VideoDuration.resolve(assetName) { [weak self] seconds in
            self?.adopt(seconds)
        }
    }

    /// Swaps the estimate for the length the file itself reports.
    private func adopt(_ seconds: Double) {
        guard seconds > 0, abs(seconds - duration) > 0.01 else { return }
        duration = seconds
        if currentTime > duration { currentTime = duration }
        // Deferred so a surface that wires its callbacks up right after this
        // player was created still hears about the corrected length.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onUpdate?(self.currentTime, self.isPlaying)
            self.onDurationReady?(self.duration)
        }
    }

    deinit {
        if let avPlayer, let timeObserver {
            avPlayer.removeTimeObserver(timeObserver)
        }
        ticker?.invalidate()
        playerLayer?.removeFromSuperlayer()
    }

    /// Puts the clip's picture into the host view. The layer outlives playback
    /// so a paused clip keeps showing its last frame.
    private func attachPicture(_ player: AVPlayer) {
        guard let hostView else { return }
        if let playerLayer {
            playerLayer.player = player
            return
        }
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        playerLayer = layer
        if let artwork = hostView as? ArtworkView {
            artwork.attachVideoLayer(layer)
        } else {
            layer.frame = hostView.bounds
            hostView.layer.addSublayer(layer)
        }
    }

    var hasRealFootage: Bool {
        if case .asset = source { return true }
        return false
    }

    // MARK: - Transport

    func play() {
        guard !isPlaying else { return }
        if currentTime >= duration - 0.05 { currentTime = 0 }
        isPlaying = true
        PlaybackCenter.shared.activate(self)

        switch source {
        case let .asset(url):
            if avPlayer?.currentItem == nil || avPlayer?.currentItem?.asset as? AVURLAsset != AVURLAsset(url: url) {
                avPlayer = AVPlayer(url: url)
                observe(avPlayer!)
                attachPicture(avPlayer!)
            }
            configureAudioSession()
            avPlayer?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
            avPlayer?.play()
        case .timeline:
            lastTickStamp = CACurrentMediaTime()
            startTicker()
        }
        onUpdate?(currentTime, true)
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        avPlayer?.pause()
        stopTicker()
        onUpdate?(currentTime, false)
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    /// Used by the playback centre to stop a clip that lost focus.
    func stopFromCenter() {
        guard isPlaying else { return }
        isPlaying = false
        avPlayer?.pause()
        stopTicker()
        onUpdate?(currentTime, false)
    }

    func seek(to time: Double) {
        currentTime = min(max(0, time), duration)
        switch source {
        case .asset:
            avPlayer?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600),
                           toleranceBefore: .zero, toleranceAfter: .zero)
        case .timeline:
            lastTickStamp = CACurrentMediaTime()
        }
        onUpdate?(currentTime, isPlaying)
    }

    func skip(_ delta: Double) {
        seek(to: currentTime + delta)
    }

    func reset() {
        pause()
        seek(to: 0)
    }

    var progress: Double { duration <= 0 ? 0 : currentTime / duration }

    // MARK: - Internals

    private func observe(_ player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.isPlaying else { return }
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            self.currentTime = min(seconds, self.duration)
            self.onUpdate?(self.currentTime, true)
            if self.currentTime >= self.duration - 0.05 { self.finish() }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleItemEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player.currentItem)
    }

    @objc private func handleItemEnd() { finish() }

    private func finish() {
        isPlaying = false
        stopTicker()
        currentTime = duration
        onUpdate?(currentTime, false)
        onFinish?()
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            let now = CACurrentMediaTime()
            let delta = now - self.lastTickStamp
            self.lastTickStamp = now
            self.currentTime = min(self.duration, self.currentTime + delta)
            self.onUpdate?(self.currentTime, true)
            if self.currentTime >= self.duration { self.finish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func configureAudioSession() {
        #if !targetEnvironment(simulator)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }
}

/// Guarantees only one clip plays at a time.
final class PlaybackCenter {

    static let shared = PlaybackCenter()
    private weak var active: ClipPlayer?

    private init() {}

    func activate(_ player: ClipPlayer) {
        if let active, active !== player, active.isPlaying {
            active.stopFromCenter()
        }
        active = player
    }

    func pauseAll() {
        active?.stopFromCenter()
        active = nil
    }
}
