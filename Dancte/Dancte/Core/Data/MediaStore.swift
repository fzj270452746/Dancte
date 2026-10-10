import UIKit

/// Keeps media a dancer picks from their own library inside the app's own
/// container, so a published post still has its photos and clips after a
/// relaunch. Resolution order everywhere is: app container first, then the
/// bundled art pack.
enum MediaStore {

    static var directory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("Dancte/Media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func url(for name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        let direct = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        for ext in ["jpg", "jpeg", "png", "heic", "mp4", "mov"] {
            let candidate = directory.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    @discardableResult
    static func save(image: UIImage, name: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.86) else { return nil }
        let file = "\(name).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(file), options: .atomic)
            return file
        } catch {
            return nil
        }
    }

    @discardableResult
    static func save(videoFrom source: URL, name: String) -> String? {
        let ext = source.pathExtension.isEmpty ? "mp4" : source.pathExtension
        let file = "\(name).\(ext)"
        let destination = directory.appendingPathComponent(file)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return file
        } catch {
            return nil
        }
    }

    static func remove(_ name: String) {
        guard let url = url(for: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

extension UIImage {

    /// Downscales a picked image so a post never carries a 12 megapixel original.
    func downscaled(maxDimension: CGFloat = 1_600) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
