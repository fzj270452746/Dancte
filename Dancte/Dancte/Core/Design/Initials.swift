import UIKit

/// What an avatar shows when there is no photo for that account. The app ships
/// only the portraits that were delivered, so anything without one falls back
/// to the dancer's initials rather than to invented artwork.
enum Initials {

    static func of(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }
}
