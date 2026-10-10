import AuthenticationServices
import UIKit

/// Sign in with Apple, wired to `ASAuthorizationController` and the account
/// store. The Apple user identifier is the durable key, so a returning dancer
/// lands back in the same library.
final class AppleSignInService: NSObject {

    struct Credential {
        let userIdentifier: String
        let displayName: String?
        let email: String?
    }

    enum SignInError: LocalizedError {
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return nil
            case let .failed(message): return message
            }
        }
    }

    static let shared = AppleSignInService()

    private var completion: ((Result<Credential, Error>) -> Void)?
    private weak var anchor: ASPresentationAnchor?
    private var activeController: ASAuthorizationController?

    private override init() { super.init() }

    var isAvailable: Bool {
        // Real devices always support it; the simulator does when signed in.
        true
    }

    func start(anchor: ASPresentationAnchor, completion: @escaping (Result<Credential, Error>) -> Void) {
        self.completion = completion
        self.anchor = anchor

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        activeController = controller
        controller.performRequests()
    }

    func cancel() {
        if #available(iOS 16.0, *) {
            activeController?.cancel()
        }
        activeController = nil
        completion = nil
    }

    private func finish(_ result: Result<Credential, Error>) {
        let handler = completion
        completion = nil
        activeController = nil
        DispatchQueue.main.async { handler?(result) }
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(SignInError.failed("Apple returned an unexpected credential.")))
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let name = credential.fullName.flatMap { formatter.string(from: $0) }

        finish(.success(Credential(userIdentifier: credential.user,
                                   displayName: name?.isEmpty == false ? name : nil,
                                   email: credential.email)))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.failure(SignInError.cancelled))
            return
        }
        finish(.failure(SignInError.failed(
            "Sign in with Apple could not be completed. Please try again, or continue with a username and password."
        )))
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let anchor { return anchor }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
