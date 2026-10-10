import UIKit

extension Notification.Name {
    static let dancteAuth      = Notification.Name("dancte.notify.auth")
    static let dancteFeed      = Notification.Name("dancte.notify.feed")
    static let danctePractice  = Notification.Name("dancte.notify.practice")
    static let dancteChat      = Notification.Name("dancte.notify.chat")
    static let dancteRelations = Notification.Name("dancte.notify.relations")
    static let dancteWallet    = Notification.Name("dancte.notify.wallet")
    /// Asks the home wall to jump to its community section on a given tag.
    static let dancteOpenTag   = Notification.Name("dancte.notify.openTag")
}

// MARK: - Per-account library
//
// Every account keeps its own shelf: who it follows, who it is friends with,
// what it liked, saved and bought. Storing these per user id (rather than as a
// single global bag) is what makes signing out and back in behave correctly.

struct Library: Codable, Hashable {
    var following: Set<String> = []
    var followerIDs: Set<String> = []
    var friends: Set<String> = []
    var incomingRequests: Set<String> = []
    var outgoingRequests: Set<String> = []
    var likedPostIDs: Set<String> = []
    var savedPostIDs: Set<String> = []
    var blockedUserIDs: Set<String> = []
    var ownedGifts: [String: Int] = [:]
}

// MARK: - Per-account practice log
//
// The training log is the product's core, so it belongs to the dancer who kept
// it rather than to the device. Each account owns its sessions, plans, skills
// and weekly targets; signing in as somebody else starts a fresh log.

struct PracticeLog: Codable, Hashable {
    var sessions: [PracticeSession] = []
    var plans: [PracticePlan] = []
    var moves: [MoveSkill] = []
    var goals: PracticeGoals = .standard

    static let empty = PracticeLog()
}

// MARK: - Practice statistics

struct PracticeStats {
    var totalMinutes: Int
    var totalSessions: Int
    var currentStreak: Int
    var longestStreak: Int
    var minutesThisWeek: Int
    var sessionsThisWeek: Int
    var activeDays: Int
    var averageMinutes: Int
    var styleMinutes: [(style: DanceStyle, minutes: Int)]
    var last7Days: [(date: Date, minutes: Int)]
    var topMood: PracticeMood?
    var longestSessionMinutes: Int
    var bestWeekMinutes: Int
    var consistency: Double
    var weekdayMinutes: [(weekday: Int, minutes: Int)]
    var mostTrainedMove: String?
    var loggedToday: Bool
    var minutesToday: Int

    static let empty = PracticeStats(
        totalMinutes: 0, totalSessions: 0, currentStreak: 0, longestStreak: 0,
        minutesThisWeek: 0, sessionsThisWeek: 0, activeDays: 0, averageMinutes: 0,
        styleMinutes: [], last7Days: [], topMood: nil,
        longestSessionMinutes: 0, bestWeekMinutes: 0, consistency: 0,
        weekdayMinutes: [], mostTrainedMove: nil, loggedToday: false, minutesToday: 0
    )
}

// MARK: - Store

/// Single source of truth for the whole app. Everything lives in memory and is
/// mirrored to a JSON snapshot on disk, so signing out and back in, or killing
/// the app, never loses a post, a practice log or a conversation.
final class DancteStore {

    static let shared = DancteStore()

    private(set) var users: [User] = []
    private(set) var posts: [Post] = []
    private(set) var comments: [Comment] = []
    private(set) var spotlight: [DanceVideo] = []
    private(set) var gifts: [Gift] = []

    private(set) var conversations: [Conversation] = []

    private(set) var accounts: [Account] = []
    private(set) var currentUserID: String?

    /// user id -> that account's shelf
    private(set) var libraries: [String: Library] = [:]

    /// user id -> that account's training log
    private(set) var practiceLogs: [String: PracticeLog] = [:]

    private let fileURL: URL
    private var isLoaded = false

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("Dancte", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("studio-state.json")
        load()
    }

    // MARK: - Library access

    var library: Library {
        guard let id = currentUserID else { return Library() }
        return libraries[id] ?? Library()
    }

    private func mutateLibrary(_ body: (inout Library) -> Void) {
        guard let id = currentUserID else { return }
        mutateLibrary(for: id, body)
    }

    /// Edits another dancer's shelf. Following somebody is a two-sided fact, so
    /// the follow has to land on their record too, not only on yours.
    private func mutateLibrary(for userID: String, _ body: (inout Library) -> Void) {
        var current = libraries[userID] ?? Library()
        body(&current)
        libraries[userID] = current
    }

    var following: Set<String> { library.following }
    var followerIDs: Set<String> { library.followerIDs }
    var friends: Set<String> { library.friends }
    var incomingRequests: Set<String> { library.incomingRequests }
    var outgoingRequests: Set<String> { library.outgoingRequests }
    var likedPostIDs: Set<String> { library.likedPostIDs }
    var savedPostIDs: Set<String> { library.savedPostIDs }
    var blockedUserIDs: Set<String> { library.blockedUserIDs }
    var ownedGifts: [String: Int] { library.ownedGifts }

    // MARK: - Practice log access

    var practiceLog: PracticeLog {
        guard let id = currentUserID else { return .empty }
        return practiceLogs[id] ?? .empty
    }

    private func mutateLog(_ body: (inout PracticeLog) -> Void) {
        guard let id = currentUserID else { return }
        var current = practiceLogs[id] ?? .empty
        body(&current)
        practiceLogs[id] = current
    }

    var sessions: [PracticeSession] { practiceLog.sessions }
    var plans: [PracticePlan] { practiceLog.plans }
    var moves: [MoveSkill] { practiceLog.moves }
    var goals: PracticeGoals { practiceLog.goals }

    // MARK: - Session

    var isSignedIn: Bool { currentUserID != nil }

    var currentUser: User? { user(currentUserID) }

    func user(_ id: String?) -> User? {
        guard let id else { return nil }
        return users.first { $0.id == id }
    }

    /// Author lookup that degrades gracefully when an account has been removed
    /// by a report, so no screen ever ends up with a blank byline.
    func authorName(of userID: String) -> String {
        user(userID)?.displayName ?? "Dancte Dancer"
    }

    func authorHandle(of userID: String) -> String {
        user(userID)?.handle ?? "dancte"
    }

    func avatarName(of userID: String) -> String {
        user(userID)?.avatarName ?? "avatar_placeholder"
    }

    var feedPosts: [Post] {
        posts
            .filter { !blockedUserIDs.contains($0.authorID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func post(_ id: String) -> Post? { posts.first { $0.id == id } }

    func comments(for postID: String) -> [Comment] {
        comments.filter { $0.postID == postID }.sorted { $0.createdAt < $1.createdAt }
    }

    func commentCount(for postID: String) -> Int {
        comments.reduce(0) { $0 + ($1.postID == postID ? 1 : 0) }
    }

    func gift(_ id: String?) -> Gift? {
        guard let id else { return nil }
        return gifts.first { $0.id == id }
    }

    func conversation(with peerID: String) -> Conversation? {
        conversations.first { $0.peerID == peerID }
    }

    func isFollowing(_ userID: String) -> Bool { following.contains(userID) }
    func isFriend(_ userID: String) -> Bool { friends.contains(userID) }
    func hasOutgoingRequest(to userID: String) -> Bool { outgoingRequests.contains(userID) }
    func hasIncomingRequest(from userID: String) -> Bool { incomingRequests.contains(userID) }
    func isBlocked(_ userID: String) -> Bool { blockedUserIDs.contains(userID) }
    func isLiked(_ postID: String) -> Bool { likedPostIDs.contains(postID) }
    func isSaved(_ postID: String) -> Bool { savedPostIDs.contains(postID) }
    func isMine(_ post: Post) -> Bool { post.authorID == currentUserID }

    /// Direct messages are restricted to mutual friends — never strangers.
    func canChat(with userID: String) -> Bool { friends.contains(userID) }

    // MARK: - Auth

    enum AuthError: LocalizedError {
        case invalidCredentials
        case handleTaken
        case handleTooShort
        case secretTooShort
        case mismatch
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .invalidCredentials: return "That username and password don't match."
            case .handleTaken:        return "That username is already taken."
            case .handleTooShort:     return "Usernames need at least 3 characters."
            case .secretTooShort:     return "Passwords need at least 6 characters."
            case .mismatch:           return "Those passwords don't match."
            case .notSignedIn:        return "You need to be signed in first."
            }
        }
    }

    @discardableResult
    func signIn(handle: String, secret: String) throws -> User {
        let normalized = handle.trimmed.lowercased()
        guard !normalized.isEmpty, !secret.isEmpty,
              let account = accounts.first(where: { $0.handle.lowercased() == normalized && $0.secret == secret }),
              let user = user(account.userID) else {
            throw AuthError.invalidCredentials
        }
        adoptSession(userID: user.id)
        return user
    }

    @discardableResult
    func register(handle: String, secret: String, confirmation: String) throws -> User {
        let normalized = handle.handleized
        guard normalized.count >= 3 else { throw AuthError.handleTooShort }
        guard secret.count >= 6 else { throw AuthError.secretTooShort }
        guard secret == confirmation else { throw AuthError.mismatch }
        guard !accounts.contains(where: { $0.handle.lowercased() == normalized }) else { throw AuthError.handleTaken }

        let user = User(
            id: "u_" + UUID().uuidString.prefix(8),
            handle: normalized,
            displayName: handle.trimmed.isEmpty ? normalized : handle.trimmed,
            avatarName: "avatar_me",
            bio: "New to Dancte. Building my practice log one session at a time.",
            city: "Los Angeles, US",
            crew: "Independent",
            styles: [.hipHop, .freestyle],
            followerCount: 0,
            followingCount: 0,
            postCount: 0,
            isVerified: false,
            joinedAt: Date()
        )
        users.append(user)
        accounts.append(Account(id: UUID().uuidString,
                                userID: user.id,
                                handle: normalized,
                                secret: secret,
                                provider: .password,
                                createdAt: Date()))
        adoptSession(userID: user.id)
        return user
    }

    /// Completes a real Sign in with Apple authorisation. The Apple user
    /// identifier is the durable account key, so a returning dancer keeps their
    /// library even after reinstalling.
    @discardableResult
    func signInWithApple(userIdentifier: String, displayName: String?, email: String?) throws -> User {
        let accountKey = "apple:" + userIdentifier
        if let account = accounts.first(where: { $0.id == accountKey }),
           let user = user(account.userID) {
            adoptSession(userID: user.id)
            return user
        }

        let base = (displayName ?? email?.components(separatedBy: "@").first ?? "dancer").handleized
        let stem = base.isEmpty ? "dancer" : base
        var handle = stem
        var suffix = 1
        while accounts.contains(where: { $0.handle.lowercased() == handle }) {
            handle = "\(stem)\(suffix)"
            suffix += 1
        }

        let user = User(
            id: "u_" + UUID().uuidString.prefix(8),
            handle: handle,
            displayName: displayName ?? handle.capitalized,
            avatarName: "avatar_me",
            bio: "Dancing on Dancte. Logging every session.",
            city: "New York, US",
            crew: "Independent",
            styles: [.hipHop, .breaking],
            followerCount: 0,
            followingCount: 0,
            postCount: 0,
            isVerified: false,
            joinedAt: Date()
        )
        users.append(user)
        accounts.append(Account(id: accountKey,
                                userID: user.id,
                                handle: handle,
                                secret: "",
                                provider: .apple,
                                createdAt: Date()))
        adoptSession(userID: user.id)
        return user
    }

    private func adoptSession(userID: String) {
        currentUserID = userID
        if libraries[userID] == nil { libraries[userID] = Library() }
        if practiceLogs[userID] == nil { practiceLogs[userID] = .empty }
        save()
        broadcastAll()
    }

    func signOut() {
        currentUserID = nil
        save()
        broadcastAll()
    }

    /// Irreversibly removes the signed-in account together with everything it
    /// authored, so the data is genuinely gone rather than hidden.
    func deleteAccount() {
        guard let userID = currentUserID else { return }
        accounts.removeAll { $0.userID == userID }
        purge(userID: userID)
        libraries.removeValue(forKey: userID)
        practiceLogs.removeValue(forKey: userID)
        currentUserID = nil
        try? FileManager.default.removeItem(at: fileURL)
        save()
        broadcastAll()
    }

    private func broadcastAll() {
        [Notification.Name.dancteAuth, .dancteFeed, .dancteRelations, .dancteChat, .danctePractice, .dancteWallet]
            .forEach { NotificationCenter.default.post(name: $0, object: nil) }
    }

    func updateProfile(displayName: String, handle: String, bio: String, city: String,
                       crew: String, styles: [DanceStyle], avatarName: String?) {
        guard let id = currentUserID, let index = users.firstIndex(where: { $0.id == id }) else { return }
        users[index].displayName = displayName.trimmed.isEmpty ? users[index].handle : displayName.trimmed
        let newHandle = handle.handleized
        if newHandle.count >= 3, !accounts.contains(where: { $0.userID != id && $0.handle.lowercased() == newHandle }) {
            users[index].handle = newHandle
            for i in accounts.indices where accounts[i].userID == id { accounts[i].handle = newHandle }
        }
        users[index].bio = bio.trimmed
        users[index].city = city.trimmed
        users[index].crew = crew.trimmed
        if !styles.isEmpty { users[index].styles = styles }
        if let avatarName, !avatarName.isEmpty { users[index].avatarName = avatarName }
        save()
        NotificationCenter.default.post(name: .dancteAuth, object: nil)
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
    }

    // MARK: - Relations

    func toggleFollow(_ userID: String) {
        guard let me = currentUserID, userID != me else { return }
        var delta = 0
        mutateLibrary { library in
            if library.following.contains(userID) {
                library.following.remove(userID)
                delta = -1
            } else {
                library.following.insert(userID)
                delta = 1
            }
        }
        adjustCount(userID, followers: delta)
        adjustCount(me, following: delta)
        // Their follower list is the same fact seen from the other side, so it
        // moves with their follower count rather than drifting away from it.
        mutateLibrary(for: userID) { library in
            if delta > 0 {
                library.followerIDs.insert(me)
            } else {
                library.followerIDs.remove(me)
            }
        }
        persistRelations()
    }

    func sendFriendRequest(to userID: String) {
        guard currentUserID != nil, userID != currentUserID else { return }
        if hasIncomingRequest(from: userID) {
            acceptFriendRequest(from: userID)
            return
        }
        guard !isFriend(userID) else { return }
        mutateLibrary { $0.outgoingRequests.insert(userID) }
        persistRelations()
    }

    func cancelFriendRequest(to userID: String) {
        mutateLibrary { $0.outgoingRequests.remove(userID) }
        persistRelations()
    }

    func acceptFriendRequest(from userID: String) {
        guard let me = currentUserID, userID != me else { return }
        var didFollow = false
        mutateLibrary { library in
            library.incomingRequests.remove(userID)
            library.outgoingRequests.remove(userID)
            library.friends.insert(userID)
            // Accepting a request also follows them, and that has to move both
            // follow counts exactly as tapping Follow would.
            didFollow = library.following.insert(userID).inserted
        }
        if didFollow {
            adjustCount(userID, followers: 1)
            adjustCount(me, following: 1)
            mutateLibrary(for: userID) { $0.followerIDs.insert(me) }
        }
        ensureConversation(with: userID)
        persistRelations()
    }

    func declineFriendRequest(from userID: String) {
        mutateLibrary { $0.incomingRequests.remove(userID) }
        persistRelations()
    }

    func removeFriend(_ userID: String) {
        mutateLibrary { $0.friends.remove(userID) }
        persistRelations()
    }

    private func adjustCount(_ userID: String?, followers: Int = 0, following followingDelta: Int = 0) {
        guard let userID, let index = users.firstIndex(where: { $0.id == userID }) else { return }
        users[index].followerCount = max(0, users[index].followerCount + followers)
        users[index].followingCount = max(0, users[index].followingCount + followingDelta)
    }

    private func persistRelations() {
        save()
        NotificationCenter.default.post(name: .dancteRelations, object: nil)
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
        NotificationCenter.default.post(name: .dancteChat, object: nil)
    }

    // MARK: - Publishing

    @discardableResult
    func createPost(text: String, media: [MediaItem], tags: [String], style: DanceStyle?) -> Post {
        let post = Post(
            id: "p_" + UUID().uuidString.prefix(10),
            authorID: currentUserID ?? "",
            text: text,
            media: media,
            tags: tags,
            style: style,
            createdAt: Date(),
            likeCount: 0,
            isSeeded: false
        )
        posts.insert(post, at: 0)
        if let index = users.firstIndex(where: { $0.id == post.authorID }) {
            users[index].postCount += 1
        }
        save()
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
        return post
    }

    func deletePost(_ postID: String) {
        guard let post = post(postID) else { return }
        posts.removeAll { $0.id == postID }
        comments.removeAll { $0.postID == postID }
        mutateLibrary { library in
            library.likedPostIDs.remove(postID)
            library.savedPostIDs.remove(postID)
        }
        if let index = users.firstIndex(where: { $0.id == post.authorID }) {
            users[index].postCount = max(0, users[index].postCount - 1)
        }
        save()
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
    }

    func toggleLike(_ postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        var liking = false
        mutateLibrary { library in
            if library.likedPostIDs.contains(postID) {
                library.likedPostIDs.remove(postID)
            } else {
                library.likedPostIDs.insert(postID)
                liking = true
            }
        }
        posts[index].likeCount = max(0, posts[index].likeCount + (liking ? 1 : -1))
        save()
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
    }

    func toggleSave(_ postID: String) {
        mutateLibrary { library in
            if library.savedPostIDs.contains(postID) {
                library.savedPostIDs.remove(postID)
            } else {
                library.savedPostIDs.insert(postID)
            }
        }
        save()
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
    }

    var likedPosts: [Post] {
        posts.filter { likedPostIDs.contains($0.id) }.sorted { $0.createdAt > $1.createdAt }
    }

    var savedPosts: [Post] {
        posts.filter { savedPostIDs.contains($0.id) }.sorted { $0.createdAt > $1.createdAt }
    }

    var myPosts: [Post] {
        guard let id = currentUserID else { return [] }
        return posts(by: id)
    }

    func posts(by userID: String) -> [Post] {
        posts.filter { $0.authorID == userID }.sorted { $0.createdAt > $1.createdAt }
    }

    var followedUsers: [User] {
        users.filter { following.contains($0.id) && !blockedUserIDs.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Comments

    @discardableResult
    func addComment(to postID: String, text: String) -> Comment {
        let comment = Comment(
            id: "c_" + UUID().uuidString.prefix(10),
            postID: postID,
            authorID: currentUserID ?? "",
            text: text,
            createdAt: Date(),
            likeCount: 0
        )
        comments.append(comment)
        save()
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
        return comment
    }

    func deleteComment(_ commentID: String) {
        comments.removeAll { $0.id == commentID }
        save()
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
    }

    // MARK: - Moderation

    /// Removes a reported user and every trace of their content, from the
    /// reporting dancer's point of view as well as from every feed.
    func purgeUser(_ userID: String) {
        mutateLibrary { library in
            library.blockedUserIDs.insert(userID)
            library.following.remove(userID)
            library.friends.remove(userID)
            library.incomingRequests.remove(userID)
            library.outgoingRequests.remove(userID)
        }
        let authored = posts.filter { $0.authorID == userID }.map(\.id)
        posts.removeAll { $0.authorID == userID }
        comments.removeAll { $0.authorID == userID || authored.contains($0.postID) }
        conversations.removeAll { $0.peerID == userID }
        mutateLibrary { library in
            authored.forEach { library.likedPostIDs.remove($0); library.savedPostIDs.remove($0) }
        }
        NotificationCenter.default.post(name: .dancteRelations, object: nil)
        NotificationCenter.default.post(name: .dancteFeed, object: nil)
        NotificationCenter.default.post(name: .dancteChat, object: nil)
        save()
    }

    private func purge(userID: String) {
        let authored = posts.filter { $0.authorID == userID }.map(\.id)
        posts.removeAll { $0.authorID == userID }
        comments.removeAll { $0.authorID == userID || authored.contains($0.postID) }
        conversations.removeAll { $0.peerID == userID }
        users.removeAll { $0.id == userID }
        practiceLogs.removeValue(forKey: userID)
    }

    // MARK: - Practice

    @discardableResult
    func logSession(date: Date, minutes: Int, style: DanceStyle, intensity: Int,
                    mood: PracticeMood, drills: [String], notes: String, mediaName: String?,
                    planID: String? = nil) -> PracticeSession {
        let session = PracticeSession(
            id: "s_" + UUID().uuidString.prefix(10),
            date: date,
            minutes: max(1, minutes),
            style: style,
            intensity: min(5, max(1, intensity)),
            mood: mood,
            drills: drills,
            notes: notes,
            mediaName: mediaName,
            createdAt: Date(),
            planID: planID
        )
        mutateLog { log in
            log.sessions.append(session)
            log.sessions.sort { $0.date > $1.date }
            // Logging a drill counts as a rep against every matching skill.
            for drill in drills {
                if let index = log.moves.firstIndex(where: { $0.name.caseInsensitiveCompare(drill) == .orderedSame }) {
                    log.moves[index].reps += 1
                    log.moves[index].updatedAt = Date()
                }
            }
        }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
        return session
    }

    func updateSession(_ session: PracticeSession) {
        guard sessions.contains(where: { $0.id == session.id }) else { return }
        mutateLog { log in
            guard let index = log.sessions.firstIndex(where: { $0.id == session.id }) else { return }
            log.sessions[index] = session
            log.sessions.sort { $0.date > $1.date }
        }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
    }

    func deleteSession(_ sessionID: String) {
        mutateLog { $0.sessions.removeAll { $0.id == sessionID } }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
    }

    func sessions(on day: Date) -> [PracticeSession] {
        sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func session(_ id: String) -> PracticeSession? { sessions.first { $0.id == id } }

    /// Every session that ran a given move, newest first.
    func sessions(drilling moveName: String) -> [PracticeSession] {
        sessions.filter { session in
            session.drills.contains { $0.caseInsensitiveCompare(moveName) == .orderedSame }
        }
    }

    // MARK: Plans

    @discardableResult
    func savePlan(_ plan: PracticePlan) -> PracticePlan {
        mutateLog { log in
            if let index = log.plans.firstIndex(where: { $0.id == plan.id }) {
                log.plans[index] = plan
            } else {
                log.plans.append(plan)
            }
            log.plans.sort { $0.startDate > $1.startDate }
        }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
        return plan
    }

    func deletePlan(_ planID: String) {
        mutateLog { log in
            log.plans.removeAll { $0.id == planID }
            // Sessions outlive their plan; they just stop being attributed.
            for index in log.sessions.indices where log.sessions[index].planID == planID {
                log.sessions[index].planID = nil
            }
        }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
    }

    /// Turns a preset programme into a real plan and stocks the skill tree with
    /// the moves it is built around.
    @discardableResult
    func startPlan(from template: PracticePlanTemplate) -> PracticePlan {
        let start = Date().startOfDay
        let plan = PracticePlan(id: "pl_" + UUID().uuidString.prefix(8),
                                title: template.title,
                                style: template.style,
                                weeklyMinuteTarget: template.minutesPerWeek,
                                weeklySessionTarget: template.sessionsPerWeek,
                                focus: template.focus,
                                startDate: start,
                                endDate: start.adding(days: template.weeks * 7),
                                accentIndex: template.accentIndex)
        mutateLog { log in
            log.plans.append(plan)
            log.plans.sort { $0.startDate > $1.startDate }
            for name in template.drills where !log.moves.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                log.moves.append(MoveSkill(id: "mv_" + UUID().uuidString.prefix(8),
                                           name: name,
                                           style: template.style,
                                           stage: .discovered,
                                           reps: 0,
                                           updatedAt: Date(),
                                           notes: nil,
                                           targetReps: nil))
            }
            log.moves.sort { $0.updatedAt > $1.updatedAt }
        }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
        return plan
    }

    func plan(_ id: String) -> PracticePlan? { plans.first { $0.id == id } }

    /// Plans whose end date has not passed yet, soonest to finish first.
    var activePlans: [PracticePlan] {
        plans.filter { !$0.isFinished }.sorted { $0.endDate < $1.endDate }
    }

    var finishedPlans: [PracticePlan] {
        plans.filter(\.isFinished).sorted { $0.endDate > $1.endDate }
    }

    /// Whether a session counts towards a plan. An explicit attribution wins;
    /// otherwise sessions logged before plans existed fall back to style.
    private func belongs(_ session: PracticeSession, to plan: PracticePlan) -> Bool {
        if let planID = session.planID { return planID == plan.id }
        if plan.style == .freestyle { return true }
        return session.style == plan.style
    }

    /// Minutes and session count logged against a plan inside the week that
    /// contains `date`.
    func planProgress(_ plan: PracticePlan, in date: Date = Date()) -> (minutes: Int, sessions: Int) {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return (0, 0) }
        let relevant = sessions.filter { interval.contains($0.date) && belongs($0, to: plan) }
        return (relevant.reduce(0) { $0 + $1.minutes }, relevant.count)
    }

    /// Week-by-week minutes against the plan's weekly target, from its first
    /// week up to the current one.
    func weeklyBreakdown(for plan: PracticePlan) -> [(weekStart: Date, minutes: Int, sessions: Int, target: Int)] {
        let calendar = Calendar.current
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: plan.startDate)?.start else { return [] }
        let lastDay = min(plan.endDate.startOfDay, Date().startOfDay)

        var weeks: [(weekStart: Date, minutes: Int, sessions: Int, target: Int)] = []
        var cursor = firstWeek
        var guardRail = 0
        while cursor <= lastDay, guardRail < 260 {
            guardRail += 1
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let relevant = sessions.filter { interval.contains($0.date) && self.belongs($0, to: plan) }
            weeks.append((cursor,
                          relevant.reduce(0) { $0 + $1.minutes },
                          relevant.count,
                          plan.weeklyMinuteTarget))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return weeks
    }

    /// Share of completed weeks that hit the plan's minute target.
    func adherence(for plan: PracticePlan) -> Double {
        let currentWeekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start
        let completed = weeklyBreakdown(for: plan).filter { $0.weekStart != currentWeekStart }
        guard !completed.isEmpty else { return 0 }
        let hits = completed.filter { $0.minutes >= $0.target }.count
        return Double(hits) / Double(completed.count)
    }

    // MARK: Goals

    func saveGoals(_ goals: PracticeGoals) {
        mutateLog { $0.goals = goals }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
    }

    // MARK: Moves

    @discardableResult
    func saveMove(_ move: MoveSkill) -> MoveSkill {
        mutateLog { log in
            if let index = log.moves.firstIndex(where: { $0.id == move.id }) {
                log.moves[index] = move
            } else {
                log.moves.append(move)
            }
            log.moves.sort { $0.updatedAt > $1.updatedAt }
        }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
        return move
    }

    func deleteMove(_ moveID: String) {
        mutateLog { $0.moves.removeAll { $0.id == moveID } }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
    }

    func advance(_ moveID: String) {
        var advanced = false
        mutateLog { log in
            guard let index = log.moves.firstIndex(where: { $0.id == moveID }),
                  let next = log.moves[index].stage.next else { return }
            log.moves[index].stage = next
            log.moves[index].updatedAt = Date()
            advanced = true
        }
        guard advanced else { return }
        save()
        NotificationCenter.default.post(name: .danctePractice, object: nil)
    }

    func move(_ id: String) -> MoveSkill? { moves.first { $0.id == id } }

    func moves(for style: DanceStyle?) -> [MoveSkill] {
        guard let style else { return moves.sorted { $0.updatedAt > $1.updatedAt } }
        return moves.filter { $0.style == style }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// How many tracked moves sit at each stage, in stage order.
    func stageCounts() -> [(stage: MoveStage, count: Int)] {
        MoveStage.allCases.map { stage in
            (stage, moves.filter { $0.stage == stage }.count)
        }
    }

    // MARK: Statistics

    var stats: PracticeStats {
        guard !sessions.isEmpty else { return .empty }

        let calendar = Calendar.current
        let today = Date().startOfDay
        let totalMinutes = sessions.reduce(0) { $0 + $1.minutes }
        let byDay = Dictionary(grouping: sessions) { $0.date.startOfDay }
        let sortedDays = byDay.keys.sorted(by: >)

        var currentStreak = 0
        if let first = sortedDays.first {
            let gap = calendar.dateComponents([.day], from: first, to: today).day ?? 0
            if gap <= 1 {
                var cursor = first
                for day in sortedDays where day <= cursor {
                    if day == cursor {
                        currentStreak += 1
                        cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                    }
                }
            }
        }

        var longestStreak = 0
        var run = 0
        var previous: Date?
        for day in sortedDays.reversed() {
            if let previous, calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longestStreak = max(longestStreak, run)
            previous = day
        }

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        let weekSessions = sessions.filter { $0.date >= weekStart }

        let styleMinutes = Dictionary(grouping: sessions, by: \.style)
            .map { (style: $0.key, minutes: $0.value.reduce(0) { $0 + $1.minutes }) }
            .sorted { $0.minutes > $1.minutes }

        let last7Days: [(Date, Int)] = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return (day, byDay[day]?.reduce(0) { $0 + $1.minutes } ?? 0)
        }

        let topMood = Dictionary(grouping: sessions, by: \.mood)
            .max { $0.value.count < $1.value.count }?.key

        let byWeek = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date.startOfDay
        }
        let bestWeekMinutes = byWeek.values.map { $0.reduce(0) { $0 + $1.minutes } }.max() ?? 0

        // Monday-first so the insight chart lines up with the training week.
        let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
        let byWeekday = Dictionary(grouping: sessions) { calendar.component(.weekday, from: $0.date) }
        let weekdayMinutes = weekdayOrder.map { weekday in
            (weekday, byWeekday[weekday]?.reduce(0) { $0 + $1.minutes } ?? 0)
        }

        let drillCounts = Dictionary(grouping: sessions.flatMap(\.drills), by: { $0 })
        let mostTrainedMove = drillCounts.max { $0.value.count < $1.value.count }?.key

        // How many of the days since the very first session were training days.
        let span = (calendar.dateComponents([.day], from: sortedDays.last ?? today, to: today).day ?? 0) + 1
        let consistency = min(1, Double(byDay.count) / Double(max(1, span)))

        let todaySessions = byDay[today] ?? []

        return PracticeStats(
            totalMinutes: totalMinutes,
            totalSessions: sessions.count,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            minutesThisWeek: weekSessions.reduce(0) { $0 + $1.minutes },
            sessionsThisWeek: weekSessions.count,
            activeDays: byDay.count,
            averageMinutes: totalMinutes / max(1, sessions.count),
            styleMinutes: styleMinutes,
            last7Days: last7Days,
            topMood: topMood,
            longestSessionMinutes: sessions.map(\.minutes).max() ?? 0,
            bestWeekMinutes: bestWeekMinutes,
            consistency: consistency,
            weekdayMinutes: weekdayMinutes,
            mostTrainedMove: mostTrainedMove,
            loggedToday: !todaySessions.isEmpty,
            minutesToday: todaySessions.reduce(0) { $0 + $1.minutes }
        )
    }

    /// The current week as the training board draws it: actual minutes against
    /// what the goals asked for, with rest days marked.
    func weekBoard(containing date: Date = Date()) -> [(date: Date, minutes: Int, planned: Int, isRest: Bool)] {
        let calendar = Calendar.current
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        let byDay = Dictionary(grouping: sessions) { $0.date.startOfDay }
        let currentGoals = goals
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let weekday = calendar.component(.weekday, from: day)
            return (day,
                    byDay[day]?.reduce(0) { $0 + $1.minutes } ?? 0,
                    currentGoals.plannedMinutes(onWeekday: weekday),
                    currentGoals.isRest(weekday: weekday))
        }
    }

    /// Minutes logged per day for the `days` days ending today, oldest first.
    func minuteSeries(days: Int) -> [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: sessions) { $0.date.startOfDay }
        return (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: Date().startOfDay) ?? Date().startOfDay
            return (day, byDay[day]?.reduce(0) { $0 + $1.minutes } ?? 0)
        }
    }

    /// Total minutes per week for the last `weeks` weeks, oldest first.
    func weeklySeries(weeks: Int) -> [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        let byWeek = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date.startOfDay
        }
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date().startOfDay
        return (0..<weeks).reversed().compactMap { offset in
            guard let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek) else { return nil }
            return (week, byWeek[week]?.reduce(0) { $0 + $1.minutes } ?? 0)
        }
    }

    /// Everything in the log, trimmed to a window — used by the insights screen.
    func sessions(inLast days: Int?) -> [PracticeSession] {
        guard let days else { return sessions }
        let cutoff = Date().startOfDay.adding(days: -(max(1, days) - 1))
        return sessions.filter { $0.date >= cutoff }
    }

    // MARK: - Chat

    @discardableResult
    func ensureConversation(with peerID: String) -> Conversation {
        if let existing = conversations.first(where: { $0.peerID == peerID }) { return existing }
        let conversation = Conversation(id: "cv_" + UUID().uuidString.prefix(8), peerID: peerID, messages: [])
        conversations.append(conversation)
        save()
        return conversation
    }

    @discardableResult
    func sendMessage(to peerID: String, kind: MessageKind, text: String, giftID: String? = nil) -> ChatMessage {
        let conversation = ensureConversation(with: peerID)
        let message = ChatMessage(
            id: "m_" + UUID().uuidString.prefix(10),
            senderID: currentUserID ?? "",
            kind: kind,
            text: text,
            giftID: giftID,
            createdAt: Date(),
            isRead: true
        )
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].messages.append(message)
        }
        save()
        NotificationCenter.default.post(name: .dancteChat, object: nil)
        return message
    }

    func markRead(_ peerID: String) {
        guard let index = conversations.firstIndex(where: { $0.peerID == peerID }) else { return }
        var changed = false
        for i in conversations[index].messages.indices where !conversations[index].messages[i].isRead {
            conversations[index].messages[i].isRead = true
            changed = true
        }
        guard changed else { return }
        save()
        NotificationCenter.default.post(name: .dancteChat, object: nil)
    }

    var totalUnread: Int { conversations.reduce(0) { $0 + $1.unreadCount } }

    var sortedConversations: [Conversation] {
        conversations
            .filter { !blockedUserIDs.contains($0.peerID) && !$0.messages.isEmpty }
            .sorted { ($0.lastMessage?.createdAt ?? .distantPast) > ($1.lastMessage?.createdAt ?? .distantPast) }
    }

    /// People worth following — never a random stranger. The list is drawn from
    /// your styles and city, and every entry still needs a follow or a friend
    /// request before a conversation can start.
    var suggestedDancers: [User] {
        let blocked = blockedUserIDs
        let myStyles = Set(currentUser?.styles ?? [])
        return users
            .filter { $0.id != currentUserID && !blocked.contains($0.id) && !friends.contains($0.id) }
            .sorted { a, b in
                let aScore = a.styles.filter { myStyles.contains($0) }.count * 2 + (isFollowing(a.id) ? 0 : 1)
                let bScore = b.styles.filter { myStyles.contains($0) }.count * 2 + (isFollowing(b.id) ? 0 : 1)
                return aScore == bScore ? a.followerCount > b.followerCount : aScore > bScore
            }
    }

    var friendList: [User] {
        users.filter { friends.contains($0.id) }.sorted { $0.displayName < $1.displayName }
    }

    var followerList: [User] {
        users.filter { followerIDs.contains($0.id) && !blockedUserIDs.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Wallet

    func grant(gift: Gift) {
        mutateLibrary { $0.ownedGifts[gift.id, default: 0] += 1 }
        save()
        NotificationCenter.default.post(name: .dancteWallet, object: nil)
    }

    func ownedCount(of gift: Gift) -> Int { ownedGifts[gift.id] ?? 0 }

    var ownedGiftTotal: Int { ownedGifts.values.reduce(0, +) }

    // MARK: - Persistence

    /// Bumping this retires any snapshot written by an older shape, so the app
    /// rebuilds the starting studio instead of failing to decode. It is also
    /// bumped whenever the seeded studio itself changes, so an install that
    /// already exists picks the new starting content up rather than keeping the
    /// posts it was seeded with the first time it ran.
    private static let snapshotVersion = 4

    private struct Snapshot: Codable {
        var version: Int
        var users: [User]
        var posts: [Post]
        var comments: [Comment]
        var spotlight: [DanceVideo]
        var gifts: [Gift]
        var conversations: [Conversation]
        var accounts: [Account]
        var currentUserID: String?
        var libraries: [String: Library]
        var practiceLogs: [String: PracticeLog]
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true

        var signedInBeforeRebuild: String?

        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            if snapshot.version == Self.snapshotVersion {
                users = snapshot.users
                posts = snapshot.posts
                comments = snapshot.comments
                spotlight = snapshot.spotlight
                gifts = snapshot.gifts
                conversations = snapshot.conversations
                accounts = snapshot.accounts
                currentUserID = snapshot.currentUserID
                libraries = snapshot.libraries
                practiceLogs = snapshot.practiceLogs
                return
            }
            // An older snapshot is replaced wholesale, but whoever was signed in
            // stays signed in when the new starting content still has them — a
            // re-seed should not look like being logged out.
            signedInBeforeRebuild = snapshot.currentUserID
        }

        let seed = SeedData.build()
        users = seed.users
        posts = seed.posts
        comments = seed.comments
        spotlight = seed.spotlight
        gifts = seed.gifts
        conversations = seed.conversations
        accounts = seed.accounts
        libraries = seed.libraries
        practiceLogs = seed.practiceLogs
        if let signedInBeforeRebuild, users.contains(where: { $0.id == signedInBeforeRebuild }) {
            currentUserID = signedInBeforeRebuild
        }
        save()
    }

    func save() {
        let snapshot = Snapshot(
            version: Self.snapshotVersion,
            users: users, posts: posts, comments: comments, spotlight: spotlight, gifts: gifts,
            conversations: conversations, accounts: accounts, currentUserID: currentUserID,
            libraries: libraries, practiceLogs: practiceLogs
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Wipes every local trace and rebuilds the starting studio.
    func resetToSeed() {
        try? FileManager.default.removeItem(at: fileURL)
        isLoaded = false
        currentUserID = nil
        users = []; posts = []; comments = []; conversations = []
        accounts = []; libraries = [:]; practiceLogs = [:]
        load()
        broadcastAll()
    }
}

// Convenience accessor used across the app.
let store = DancteStore.shared
