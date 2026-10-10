import AVFoundation
import UIKit

/// Lifts a still out of a clip. Used wherever a video has no delivered poster
/// of its own, so a tile shows a real frame of the footage rather than a blank
/// surface — the frame is the material, not something drawn in its place.
enum VideoPoster {

    private static let cache = NSCache<NSString, UIImage>()

    static func frame(forVideoNamed name: String,
                      at seconds: Double = 1,
                      then: @escaping (UIImage?) -> Void) {
        guard let url = Assets.videoURL(name) else {
            then(nil)
            return
        }

        let key = "\(name)|\(seconds)" as NSString
        if let cached = cache.object(forKey: key) {
            then(cached)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1400, height: 1400)
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity

            // Clips shorter than the requested offset start from the top.
            let image = [seconds, 0].lazy
                .compactMap { try? generator.copyCGImage(at: CMTime(seconds: $0, preferredTimescale: 600),
                                                         actualTime: nil) }
                .first
                .map { UIImage(cgImage: $0) }

            if let image { cache.setObject(image, forKey: key) }
            DispatchQueue.main.async { then(image) }
        }
    }
}
