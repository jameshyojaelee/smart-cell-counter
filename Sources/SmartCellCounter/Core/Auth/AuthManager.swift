//
//  AuthManager.swift
//  SmartCellCounter
//
//  Created by 이효록 on 10/29/25.
//

import FirebaseAuth
import Foundation
import GoogleSignIn
import GoogleSignInSwift

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var user: User? // Firebase User object
    @Published var error: Error?
    @Published var isLoading: Bool = false

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        // Listen for changes in Firebase's authentication state
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        // Stop listening when this object is deallocated
        if let authStateHandler {
            Auth.auth().removeStateDidChangeListener(authStateHandler)
        }
    }

    var isAuthenticated: Bool {
        return user != nil
    }

    func signInWithGoogle() async {
        isLoading = true
        error = nil

        do {
            // 1. Get the top-most view controller to present the Google sign-in sheet
            guard let topVC = await MainActor.run(body: {
                UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                    .first
            }) else {
                throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller."])
            }

            // 2. Start the Google Sign-In flow
            let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)

            // 3. Get the ID token from the Google sign-in result
            guard let idToken = gidSignInResult.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not get ID token from Google."])
            }

            // 4. Create a Firebase credential with the Google ID token
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: gidSignInResult.user.accessToken.tokenString)

            // 5. Sign in to Firebase with the credential
            let authResult = try await Auth.auth().signIn(with: credential)
            user = authResult.user

        } catch {
            self.error = error
            print("Error during Google Sign-In: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            user = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            self.error = error
        }
    }
}
