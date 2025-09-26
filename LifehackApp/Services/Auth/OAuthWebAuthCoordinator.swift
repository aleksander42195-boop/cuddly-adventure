import Foundation
import AuthenticationServices

final class OAuthWebAuthCoordinator: NSObject {
    private var session: ASWebAuthenticationSession?

    func startAuth(authURL: URL, callbackScheme: String = "lifehackapp", completion: @escaping (Result<URL, Error>) -> Void) {
        let sess = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
            if let url = url { completion(.success(url)) }
            else { completion(.failure(error ?? NSError(domain: "OAuth", code: -1))) }
        }
        sess.presentationContextProvider = self
        sess.prefersEphemeralWebBrowserSession = true
        self.session = sess
        sess.start()
    }
}

extension OAuthWebAuthCoordinator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
