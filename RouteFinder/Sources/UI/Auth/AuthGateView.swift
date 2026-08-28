import SwiftUI

/// Loading splash plus local login / signup gate.
public struct AuthGateView: View {
    @Bindable var session: SessionController
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var privacyConsent = false
    @State private var showForgotPasswordConfirm = false

    public init(session: SessionController) {
        self.session = session
        _email = State(initialValue: session.prefillEmail)
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.18),
                    Color(red: 0.04, green: 0.07, blue: 0.11),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch session.phase {
            case .loading:
                splash
            case .unauthenticated, .authenticated:
                authCard
            }
        }
        .task {
            if session.phase == .loading {
                await session.bootstrap()
            }
        }
        .onChange(of: session.prefillEmail) { _, newValue in
            if email.isEmpty, !newValue.isEmpty {
                email = newValue
            }
        }
        .confirmationDialog(
            "Erase local account?",
            isPresented: $showForgotPasswordConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase Account & API Keys", role: .destructive) {
                session.resetForgottenPassword()
                password = ""
                confirmPassword = ""
                privacyConsent = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                """
                RouteFinder cannot email a password reset for local-only accounts. \
                This permanently deletes the account on this Mac and all API keys stored \
                for it in the Keychain. You can then create a new local account.
                """
            )
        }
    }

    private var splash: some View {
        VStack(spacing: RFSpacing.lg) {
            Text("RouteFinder")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Loading…")
                .font(RFFont.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            Text("RouteFinder")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(session.accountExists ? "Log in to unlock your API keys" : "Create a local account on this Mac")
                .font(RFFont.body)
                .foregroundStyle(.secondary)

            Text(session.accountExists ? "Log In" : "Sign Up")
                .font(RFFont.sectionTitle)

            TextField("Email", text: $email)
                .textFieldStyle(GlassTextFieldStyle())
                .accessibilityIdentifier("authEmailField")
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif

            SecureField("Password", text: $password)
                .textFieldStyle(GlassTextFieldStyle())

            if !session.accountExists {
                SecureField("Confirm password", text: $confirmPassword)
                    .textFieldStyle(GlassTextFieldStyle())

                privacyConsentRow

                if let hint = signupValidationHint {
                    Text(hint)
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = session.errorMessage {
                Text(error)
                    .font(RFFont.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(session.accountExists ? "Log In" : "Create Account") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)

            if session.accountExists {
                Button("Forgot password?") {
                    showForgotPasswordConfirm = true
                }
                .buttonStyle(.plain)
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
                .help("Erase this Mac’s local account and API keys, then sign up again.")
            }

            Text("Accounts and API keys stay on this Mac (Keychain). They are never uploaded by RouteFinder.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(RFSpacing.xl)
        .frame(maxWidth: 440)
        .glassPanel(cornerRadius: 20)
        .padding(RFSpacing.xl)
    }

    /// Separate checkbox + label so the long privacy text does not swallow clicks.
    private var privacyConsentRow: some View {
        HStack(alignment: .top, spacing: RFSpacing.sm) {
            #if os(macOS)
            Toggle(isOn: $privacyConsent) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Privacy consent")
            #else
            Toggle(isOn: $privacyConsent) {
                EmptyView()
            }
            .labelsHidden()
            .accessibilityLabel("Privacy consent")
            #endif

            Text(privacyNotice)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    privacyConsent.toggle()
                }
        }
    }

    private var privacyNotice: String {
        """
        I understand RouteFinder stores my email, password verifier, and API keys only on this Mac \
        (Keychain, this-device-only) to unlock the app and call third-party routing/weather APIs I configure. \
        Keys are not shared with other Mac users or uploaded by RouteFinder. I can log out or delete my \
        account to erase local credentials.
        """
    }

    private var canSubmit: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, password.count >= 8 else { return false }
        if !session.accountExists {
            return privacyConsent && password == confirmPassword && !confirmPassword.isEmpty
        }
        return true
    }

    private var signupValidationHint: String? {
        guard !session.accountExists else { return nil }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            return "Enter an email address."
        }
        if password.count < 8 {
            return "Password must be at least 8 characters."
        }
        if confirmPassword.isEmpty {
            return "Confirm your password."
        }
        if password != confirmPassword {
            return "Passwords do not match."
        }
        if !privacyConsent {
            return "Check the privacy notice to create an account."
        }
        return nil
    }

    private func submit() {
        if session.accountExists {
            session.login(email: email, password: password)
            if session.phase == .authenticated {
                password = ""
                confirmPassword = ""
            }
        } else {
            guard password == confirmPassword else {
                session.reportError("Passwords do not match.")
                return
            }
            guard privacyConsent else {
                session.reportError("You must accept the privacy notice to create an account.")
                return
            }
            session.signUp(email: email, password: password, privacyConsent: privacyConsent)
            if session.phase == .authenticated {
                password = ""
                confirmPassword = ""
            }
        }
    }
}
