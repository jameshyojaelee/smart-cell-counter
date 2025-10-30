//
//  LoginView.swift
//  SmartCellCounter
//
//  Created by 이효록 on 10/29/25.
//

import GoogleSignInSwift // Import this for the official button
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        ZStack {
            // Use the app's background theme
            Theme.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Title
                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.matrix") // Placeholder icon
                        .font(.system(size: 80))
                        .foregroundColor(Theme.accent)
                    Text(L10n.Settings.About.appName) // Re-use existing localization
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Please sign in to continue")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // Google Sign-In Button
                GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }
                .frame(height: 50)
                .padding(.horizontal, 40)
                .disabled(authManager.isLoading)
                .overlay {
                    if authManager.isLoading {
                        ProgressView().tint(.white)
                    }
                }

                // Show error message if one exists
                if let error = authManager.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(Theme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
    struct LoginView_Previews: PreviewProvider {
        static var previews: some View {
            LoginView()
                .environmentObject(AuthManager())
        }
    }
#endif
