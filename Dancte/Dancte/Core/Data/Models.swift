import UIKit

// MARK: - Dance taxonomy

enum DanceStyle: String, Codable, CaseIterable {
    case breaking, popping, locking, hipHop, house, waacking, krump, jazzFunk, tutting, litefeet, freestyle

    var title: String {
        switch self {
        case .breaking:  return "Breaking"
        case .popping:   return "Popping"
        case .locking:   return "Locking"
        case .hipHop:    return "Hip-Hop"
        case .house:     return "House"
        case .waacking:  return "Waacking"
        case .krump:     return "Krump"
        case .jazzFunk:  return "Jazz Funk"
        case .tutting:   return "Tutting"
        case .litefeet:  return "Litefeet"
        case .freestyle: return "Freestyle"
        }
    }

    var symbol: String {
        switch self {
        case .breaking:  return "bolt.fill"
        case .popping:   return "sparkles"
        case .locking:   return "hand.raised.fill"
        case .hipHop:    return "waveform"
        case .house:     return "house.fill"
        case .waacking:  return "wind"
        case .krump:     return "flame.fill"
        case .jazzFunk:  return "music.note"
        case .tutting:   return "square.grid.3x3.fill"
        case .litefeet:  return "figure.walk"
        case .freestyle: return "star.fill"
        }
    }

    var accentIndex: Int { DanceStyle.allCases.firstIndex(of: self) ?? 0 }
    var accent: UIColor { Palette.accent(accentIndex) }
    var gradient: [UIColor] { Grad.forAccent(accentIndex) }

    /// The one-line "what is this" copy shown on the style picker.
    var blurb: String {
        switch self {
        case .breaking:  return "Power, footwork and freezes"
        case .popping:   return "Pops, waves and animation"
        case .locking:   return "Locks, points and funk"
        case .hipHop:    return "Grooves, bounce and party moves"
        case .house:     return "Jacking, footwork and flow"
        case .waacking:  return "Arms, drama and punk"
        case .krump:     return "Chest pops and raw energy"
        case .jazzFunk:  return "Sharp lines and choreo"
        case .tutting:   return "Angles, digits and geometry"
        case .litefeet:  return "Fast footwork and get-downs"
        case .freestyle: return "No rules, just feel"
        }
    }
}

extension DanceStyle {

    /// The signature moves of each style. Used to seed the skill tree and to
    /// suggest drills while a dancer logs a session.
    var commonDrills: [String] {
        switch self {
        case .breaking:  return ["Top Rock", "Six Step", "Windmill", "Baby Freeze", "Swipe", "Head Spin", "Backspin", "Chair Freeze"]
        case .popping:   return ["The Pop", "Wave", "Robot", "Scarecrow", "Ticking", "Animation", "Walk Out"]
        case .locking:   return ["Points", "Locks", "Wrist Roll", "Scooby Doo", "Skeeter Rabbit", "Which-a-Way"]
        case .hipHop:    return ["Bounce Groove", "Rock Steady", "Chest Pop", "Kick Ball Change", "Party Rock", "Running Man"]
        case .house:     return ["Shuffle", "Jacking", "Loose Legs", "Farmer", "Cross Step", "Side Walk"]
        case .waacking:  return ["Arm Rolls", "Whistle", "Punk Move", "Tutting Blend", "Line Work"]
        case .krump:     return ["Chest Pop", "Bucket", "Arm Swing", "Stomp", "Character", "Jab"]
        case .tutting:   return ["Box", "Grid Walk", "Digit Roll", "Egyptian", "King Tut"]
        case .litefeet:  return ["Get Down", "Hat Trick", "Toe Wop", "Rev Up", "Brooklyn Rock"]
        case .jazzFunk:  return ["Body Roll", "Hair Whip", "Jazz Square", "Sharp Arm", "Kick Ball Change"]
        case .freestyle: return ["Cypher Round", "Musicality", "Texture Work", "Level Change", "Freestyle Set"]
        }
    }
}

enum DanceLevel: String, Codable, CaseIterable {
    case beginner, intermediate, advanced, all

    var title: String {
        switch self {
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced:     return "Advanced"
        case .all:          return "All Levels"
        }
    }
}

// MARK: - Media

enum MediaKind: String, Codable, Hashable {
    case image, video
}

/// A single piece of media attached to a post.
///
/// `assetName` is the resource key. When a matching file exists in the bundle
/// (image with any of the supported extensions, or a video file) it is used
/// directly; otherwise the UI renders generated placeholder art from the same
/// key so the layout is always complete.
struct MediaItem: Codable, Hashable {
    var id: String
    var kind: MediaKind
    var assetName: String
    var duration: Double
    var aspect: CGFloat
    var caption: String

    init(id: String = UUID().uuidString,
         kind: MediaKind,
         assetName: String,
         duration: Double = 0,
         aspect: CGFloat = 4.0 / 5.0,
         caption: String = "") {
        self.id = id
        self.kind = kind
        self.assetName = assetName
        self.duration = duration
        self.aspect = aspect
        self.caption = caption
    }
}

// MARK: - People

struct User: Codable, Identifiable, Hashable {
    var id: String
    var handle: String
    var displayName: String
    var avatarName: String
    var bio: String
    var city: String
    var crew: String
    var styles: [DanceStyle]
    var followerCount: Int
    var followingCount: Int
    var postCount: Int
    var isVerified: Bool
    var joinedAt: Date
}

// MARK: - Posts

struct Post: Codable, Identifiable, Hashable {
    var id: String
    var authorID: String
    var text: String
    var media: [MediaItem]
    var tags: [String]
    var style: DanceStyle?
    var createdAt: Date
    var likeCount: Int
    var isSeeded: Bool
}

struct Comment: Codable, Identifiable, Hashable {
    var id: String
    var postID: String
    var authorID: String
    var text: String
    var createdAt: Date
    var likeCount: Int
}

// MARK: - Spotlight clips

struct DanceVideo: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var coachID: String
    var style: DanceStyle
    var level: DanceLevel
    var duration: Double
    var assetName: String
    var posterName: String
    var viewCount: Int
    var likeCount: Int
}

// MARK: - Practice

enum PracticeMood: String, Codable, CaseIterable {
    case fired, locked, steady, sore, inspired

    var title: String {
        switch self {
        case .fired:    return "Fired Up"
        case .locked:   return "Locked In"
        case .steady:   return "Steady"
        case .sore:     return "Sore"
        case .inspired: return "Inspired"
        }
    }

    var symbol: String {
        switch self {
        case .fired:    return "flame.fill"
        case .locked:   return "target"
        case .steady:   return "equal.circle.fill"
        case .sore:     return "bandage.fill"
        case .inspired: return "lightbulb.fill"
        }
    }

    var accent: UIColor {
        switch self {
        case .fired:    return Palette.blaze
        case .locked:   return Palette.lime
        case .steady:   return Palette.cyan
        case .sore:     return Palette.textMuted
        case .inspired: return Palette.violet
        }
    }
}

enum MoveStage: String, Codable, CaseIterable {
    case discovered, drilling, clean, battleReady

    var title: String {
        switch self {
        case .discovered:  return "Discovered"
        case .drilling:    return "Drilling"
        case .clean:       return "Clean"
        case .battleReady: return "Battle Ready"
        }
    }

    var progress: CGFloat {
        switch self {
        case .discovered:  return 0.25
        case .drilling:    return 0.5
        case .clean:       return 0.75
        case .battleReady: return 1.0
        }
    }

    var next: MoveStage? {
        switch self {
        case .discovered:  return .drilling
        case .drilling:    return .clean
        case .clean:       return .battleReady
        case .battleReady: return nil
        }
    }

    /// What it actually takes to be at this stage, in the dancer's own terms.
    var blurb: String {
        switch self {
        case .discovered:  return "You know what it looks like. Now break it into pieces."
        case .drilling:    return "You can do it slowly. Speed and repetition are the work."
        case .clean:       return "It lands on beat most tries. Polish the entries and exits."
        case .battleReady: return "You'd throw it in a cypher without thinking. Keep it sharp."
        }
    }

    var accent: UIColor {
        switch self {
        case .discovered:  return Palette.textFaint
        case .drilling:    return Palette.cyan
        case .clean:       return Palette.amber
        case .battleReady: return Palette.lime
        }
    }
}

struct PracticeSession: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var minutes: Int
    var style: DanceStyle
    var intensity: Int          // 1...5
    var mood: PracticeMood
    var drills: [String]
    var notes: String
    var mediaName: String?
    var createdAt: Date
    /// The plan this session was logged against, when the dancer picked one.
    var planID: String?
}

struct PracticePlan: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var style: DanceStyle
    var weeklyMinuteTarget: Int
    var weeklySessionTarget: Int
    var focus: String
    var startDate: Date
    var endDate: Date
    var accentIndex: Int

    /// Whole weeks the plan is meant to run for, at least one.
    var totalWeeks: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
        return max(1, Int(ceil(Double(max(days, 0)) / 7.0)))
    }

    var isFinished: Bool { endDate.startOfDay < Date().startOfDay }

    /// 1-based index of the week we are in, clamped to the plan's length.
    var currentWeek: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: Date().startOfDay).day ?? 0
        return min(max(1, days / 7 + 1), totalWeeks)
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date().startOfDay, to: endDate.startOfDay).day ?? 0)
    }
}

/// A set of preset programmes a dancer can start in one tap. Templates are
/// static content — they are never persisted, only the plan they spawn is.
struct PracticePlanTemplate: Identifiable, Hashable {
    var id: String
    var title: String
    var style: DanceStyle
    var weeks: Int
    var sessionsPerWeek: Int
    var minutesPerWeek: Int
    var focus: String
    var blurb: String
    var drills: [String]

    var accentIndex: Int { style.accentIndex }
}

struct MoveSkill: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var style: DanceStyle
    var stage: MoveStage
    var reps: Int
    var updatedAt: Date
    /// Free-form reminder of what still needs work on this move.
    var notes: String?
    /// Rep target the dancer set for themselves.
    var targetReps: Int?
}

/// Weekly targets and rest days that drive the training board. Kept separate
/// from any single plan so the board still works for a dancer with no plan.
struct PracticeGoals: Codable, Hashable {
    var weeklyMinuteTarget: Int
    var weeklySessionTarget: Int
    var focusStyle: DanceStyle
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday) the dancer rests on.
    var restDays: Set<Int>

    static let standard = PracticeGoals(weeklyMinuteTarget: 240,
                                        weeklySessionTarget: 4,
                                        focusStyle: .freestyle,
                                        restDays: [])

    /// How the weekly minute target is spread across the days the dancer trains.
    var trainingDaysPerWeek: Int { max(1, 7 - restDays.count) }

    func plannedMinutes(onWeekday weekday: Int) -> Int {
        restDays.contains(weekday) ? 0 : weeklyMinuteTarget / trainingDaysPerWeek
    }

    func isRest(weekday: Int) -> Bool { restDays.contains(weekday) }
}

/// A half-finished session handed from the live timer into the log editor, so
/// a timed workout never has to be typed in twice.
struct PracticeDraft {
    var date: Date = Date()
    var minutes: Int
    var style: DanceStyle
    var drills: [String]
    var planID: String?
}

// MARK: - Chat

enum MessageKind: String, Codable {
    case text, gift, call
}

struct ChatMessage: Codable, Identifiable, Hashable {
    var id: String
    var senderID: String
    var kind: MessageKind
    var text: String
    var giftID: String?
    var createdAt: Date
    var isRead: Bool
}

struct Conversation: Codable, Identifiable, Hashable {
    var id: String
    var peerID: String
    var messages: [ChatMessage]

    var lastMessage: ChatMessage? { messages.last }
    var unreadCount: Int { messages.filter { !$0.isRead && $0.senderID == peerID }.count }
}

// MARK: - Gifts

/// Seven collectible gifts, one per price tier, themed around street dance
/// culture. `productID` maps to a consumable in-app purchase product.
struct Gift: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var tagline: String
    var tier: Int
    var assetName: String
    var accentIndex: Int

    var price: Decimal { Gift.tierPrices[tier] }

    /// The App Store Connect identifier of this gift's consumable. One per
    /// price tier, low to high, in tier order.
    var productID: String { Gift.productIDs[id] ?? "com.dance.Dancte.gift.\(id)" }

    var accent: UIColor { Palette.accent(accentIndex) }

    static let tierPrices: [Decimal] = [0.99, 1.99, 4.99, 9.99, 19.99, 49.99, 99.99]

    static let productIDs: [String: String] = [
        "patch":   "yvoaikogjsnndjsu",
        "mixtape": "dzcukgvzaotyvpnk",
        "cap":     "pbzznmzvbarhrfvj",
        "kicks":   "sqspihjxfbypufcy",
        "boombox": "odoyavsqwxsbleco",
        "trophy":  "uswxusnxccyxehqx",
        "crown":   "faboiosrwrtvolab"
    ]

    /// Glyph used wherever the gift is drawn.
    var symbol: String {
        switch id {
        case "patch":   return "seal.fill"
        case "mixtape": return "music.note.list"
        case "cap":     return "graduationcap.fill"
        case "kicks":   return "figure.walk"
        case "boombox": return "hifispeaker.fill"
        case "trophy":  return "trophy.fill"
        case "crown":   return "crown.fill"
        default:        return "gift.fill"
        }
    }
}

// MARK: - Moderation

enum ReportReason: String, Codable, CaseIterable {
    case illegalContent, inappropriateContent, blockUser, other

    var title: String {
        switch self {
        case .illegalContent:        return "Illegal Content"
        case .inappropriateContent:  return "Inappropriate Content"
        case .blockUser:             return "Block This User"
        case .other:                 return "Something Else"
        }
    }

    var detail: String {
        switch self {
        case .illegalContent:       return "Violence, drugs, scams or anything unlawful"
        case .inappropriateContent: return "Nudity, harassment, hate speech or spam"
        case .blockUser:            return "Hide this account and remove them from your feed"
        case .other:                return "Tell us what is wrong with this content"
        }
    }

    var symbol: String {
        switch self {
        case .illegalContent:       return "exclamationmark.shield.fill"
        case .inappropriateContent: return "eye.slash.fill"
        case .blockUser:            return "hand.raised.slash.fill"
        case .other:                return "ellipsis.bubble.fill"
        }
    }
}

// MARK: - Accounts

enum AuthProvider: String, Codable {
    case password, apple
}

struct Account: Codable, Identifiable, Hashable {
    var id: String
    var userID: String
    var handle: String
    var secret: String
    var provider: AuthProvider
    var createdAt: Date
}

// MARK: - Resource resolution

/// Resolves a logical resource key to a real bundled file when one exists.
/// A key with nothing behind it resolves to nothing: the app shows the
/// material that shipped and leaves the rest out rather than inventing art.
enum Assets {

    private static let imageExtensions = ["png", "jpg", "jpeg", "heic", "webp", "pdf"]
    private static let videoExtensions = ["mp4", "mov", "m4v"]

    static func image(_ name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        // Anything the dancer picked lives in the app container.
        if let url = MediaStore.url(for: name), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return image
        }
        if let image = UIImage(named: name) { return image }
        for ext in imageExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }

    static func videoURL(_ name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        if let url = MediaStore.url(for: name) { return url }
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }

    /// Whether a key has a real file behind it. Lets the seed data publish only
    /// the media that exists instead of listing keys that resolve to nothing.
    static func hasImage(_ name: String) -> Bool { image(name) != nil }

    static func hasVideo(_ name: String) -> Bool { videoURL(name) != nil }
}
