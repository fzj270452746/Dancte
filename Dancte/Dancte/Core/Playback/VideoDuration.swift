import AVFoundation
import Foundation

/// The real length of a delivered clip, read off the file rather than assumed.
///
/// Every surface that prints a timecode asks here, so the interface always
/// agrees with the footage that actually shipped. A key with no file behind it
/// never calls back and the caller keeps its own estimate, which is what drives
/// the transport when a clip plays as a bare timeline.
enum VideoDuration {

    private static let cache = NSCache<NSString, NSNumber>()
    /// A player item only loads its asset once it belongs to a player, so each
    /// probe parks one here until the item has reported its length.
    private static var probes: [String: AVPlayer] = [:]
    private static var observers: [String: NSKeyValueObservation] = [:]
    private static var waiting: [String: [(Double) -> Void]] = [:]

    /// The length once it has been read off disk, or nil while it is unknown.
    static func known(_ name: String) -> Double? {
        cache.object(forKey: name as NSString)?.doubleValue
    }

    /// Reads the clip's own length. The callback runs on the main thread, and a
    /// file that cannot be opened simply never answers.
    static func resolve(_ name: String, then: @escaping (Double) -> Void) {
        guard !name.isEmpty else { return }
        if let known = known(name) {
            then(known)
            return
        }
        guard let url = Assets.videoURL(name) else { return }

        waiting[name, default: []].append(then)
        guard probes[name] == nil else { return }

        let item = AVPlayerItem(url: url)
        probes[name] = AVPlayer(playerItem: item)
        observers[name] = item.observe(\.status, options: [.initial, .new]) { item, _ in
            guard item.status == .readyToPlay else { return }
            let seconds = CMTimeGetSeconds(item.duration)
            DispatchQueue.main.async { adopt(name, seconds) }
        }
    }

    private static func adopt(_ name: String, _ seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        probes[name] = nil
        observers[name] = nil
        cache.setObject(NSNumber(value: seconds), forKey: name as NSString)
        let callbacks = waiting.removeValue(forKey: name) ?? []
        callbacks.forEach { $0(seconds) }
    }
}
