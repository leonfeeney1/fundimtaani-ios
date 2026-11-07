import SwiftUI

/// Auth screens for the customer app, against the Phase 1 API.
/// Two login paths (password and email code), signup, email
/// verification, forgot/reset. The session cookie does the work — the
/// app never stores a password or a token.

/// Shared bits for the auth forms.
struct AuthFieldError: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.caption)
                .foregroundStyle(Color(hex: "DC2626"))
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showVerify = false
    @State private var showCodeLogin = false
    @State private var showSignup = false
    @State private var showForgot = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section {
                TextField("Email or phone", text: $identifier)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            } header: {
                Text("Welcome back")
            } footer: {
                Text("Your email must be verified before you can log in.")
            }
            if let errorMessage {
                Section { ErrorBannerView(message: errorMessage) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Log in").font(.headline).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting || identifier.isEmpty || password.isEmpty)
            }
            Section {
                Button("Log in with an email code instead") { showCodeLogin = true }
                Button("Forgot password?") { showForgot = true }
                Button("Create an account") { showSignup = true }
            }
        }
        .navigationTitle("Log in")
        .navigationDestination(isPresented: $showVerify) { VerifyView(onVerified: finishLogin) }
        .navigationDestination(isPresented: $showCodeLogin) { LoginCodeView(onLoggedIn: finishLogin) }
        .navigationDestination(isPresented: $showSignup) { SignupView() }
        .navigationDestination(isPresented: $showForgot) { ForgotPasswordView() }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let payload = try await api.login(identifier: identifier, password: password)
            if payload.next == "verify" {
                showVerify = true
            } else {
                await finishLogin()
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }

    private func finishLogin() async {
        await appState.refreshSession()
        if appState.isSignedIn { dismiss() }
    }
}

/// Passwordless login: email first, then the 6-digit code. The code
/// request is deliberately neutral (no account oracle), and resends are
/// throttled to 3/hour per account on the server — the UI says so.
struct LoginCodeView: View {
    var onLoggedIn: () async -> Void

    @State private var email = ""
    @State private var code = ""
    @State private var step = 1
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    private let api = APIClient.shared

    var body: some View {
        Form {
            if step == 1 {
                Section {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Log in with a code")
                } footer: {
                    Text("We'll email you a 6-digit code. It expires in 10 minutes.")
                }
            } else {
                Section {
                    TextField("6-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: code) { _, new in
                            code = String(new.filter(\.isNumber).prefix(6))
                        }
                } header: {
                    Text("Enter the code sent to \(email)")
                } footer: {
                    Text("5 wrong tries burns the code. Resends are limited to 3 per hour.")
                }
            }
            if let infoMessage {
                Section { Text(infoMessage).font(.subheadline).foregroundStyle(Brand.primary) }
            }
            if let errorMessage {
                Section { ErrorBannerView(message: errorMessage) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(step == 1 ? "Send code" : "Verify and log in")
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting || (step == 1 ? email.isEmpty : code.count != 6))
                if step == 2 {
                    Button("Send a new code") {
                        Task { await requestCode(again: true) }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
        .navigationTitle("Log in with a code")
    }

    private func submit() async {
        if step == 1 {
            await requestCode(again: false)
        } else {
            await verify()
        }
    }

    private func requestCode(again: Bool) async {
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        do {
            _ = try await api.requestLoginCode(email: email)
            step = 2
            infoMessage = again ? "A fresh code is on its way." : "Code sent — check your inbox."
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }

    private func verify() async {
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        do {
            _ = try await api.verifyLoginCode(code)
            await onLoggedIn()
        } catch let error as APIError {
            switch error {
            case .validation(let message, _):
                // The server message already carries the tries left.
                errorMessage = message
            case .rateLimited:
                errorMessage = "Too many wrong attempts — that code is burned. Request a new code."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }
}

/// Signup: name, Kenyan phone, email, password, role, age + TOS.
/// A duplicate email/phone returns 409 — shown as a field error, and
/// the form is never auto-retried.
struct SignupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var role = "customer"
    @State private var ageConfirm = false
    @State private var tosAccept = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var fieldErrors: [String: String] = [:]
    @State private var showVerify = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section {
                TextField("Full name", text: $name)
                    .textContentType(.name)
                AuthFieldError(message: fieldErrors["name"])
                TextField("Phone (e.g. 0712 345 678)", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                AuthFieldError(message: fieldErrors["phone"])
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                AuthFieldError(message: fieldErrors["email"])
                SecureField("Password (at least 8 characters)", text: $password)
                    .textContentType(.newPassword)
                AuthFieldError(message: fieldErrors["password"])
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                AuthFieldError(message: fieldErrors["confirm_password"])
            } header: {
                Text("Create your account")
            }
            Section {
                Picker("I am joining as", selection: $role) {
                    Text("A customer").tag("customer")
                    Text("A fundi").tag("technician")
                }
                .pickerStyle(.segmented)
                if role == "technician" {
                    Text("After verifying your email you'll complete your fundi application. The in-app application opens in the next update — for now it opens the website.")
                        .font(.caption)
                        .foregroundStyle(Brand.body)
                }
            }
            Section {
                Toggle("I am at least 18 years old", isOn: $ageConfirm)
                Toggle("I accept the Terms of Service and Privacy Policy", isOn: $tosAccept)
            }
            if let errorMessage {
                Section { ErrorBannerView(message: errorMessage) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Create account").font(.headline).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting || !ageConfirm || !tosAccept)
            }
        }
        .navigationTitle("Sign up")
        .navigationDestination(isPresented: $showVerify) {
            VerifyView(onVerified: {
                await appState.refreshSession()
            })
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        fieldErrors = [:]
        guard password == confirmPassword else {
            fieldErrors["confirm_password"] = "The two passwords do not match."
            isSubmitting = false
            return
        }
        do {
            _ = try await api.signup(name: name, phone: phone, email: email, password: password, role: role)
            showVerify = true
        } catch let error as APIError {
            if case .validation(let message, let fields) = error {
                errorMessage = message
                fieldErrors = fields ?? [:]
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }
}

/// Email verification: the 6-digit code sent at signup (or after a
/// password reset, or when an unverified email logs in). 10-minute
/// expiry — on expiry the server auto-sends a fresh code. 5 wrong
/// tries burns the code. Resend can correct the email address.
struct VerifyView: View {
    var onVerified: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var correctEmail = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    private let api = APIClient.shared

    var body: some View {
        Form {
            Section {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: code) { _, new in
                        code = String(new.filter(\.isNumber).prefix(6))
                    }
            } header: {
                Text("Verify your email")
            } footer: {
                Text("The code expires in 10 minutes. 5 wrong tries burns it and you'll need a fresh one.")
            }
            if let infoMessage {
                Section { Text(infoMessage).font(.subheadline).foregroundStyle(Brand.primary) }
            }
            if let errorMessage {
                Section { ErrorBannerView(message: errorMessage) }
            }
            Section {
                Button {
                    Task { await verify() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Verify").font(.headline).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting || code.count != 6)
            }
            Section {
                TextField("Correct email (optional)", text: $correctEmail)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                Button("Send a new code") {
                    Task { await resend() }
                }
                .disabled(isSubmitting)
            } footer: {
                Text("Resends are limited to 3 per hour.")
            }
        }
        .navigationTitle("Verify email")
    }

    private func verify() async {
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        do {
            _ = try await api.verifyCode(code)
            await onVerified()
            dismiss()
        } catch let error as APIError {
            switch error {
            case .validation(let message, _):
                // The server message already carries the tries left.
                errorMessage = message
                if message.contains("expired") {
                    infoMessage = "That code expired — a fresh one is on its way."
                }
            case .rateLimited:
                errorMessage = "Too many wrong attempts — that code is burned. Request a new code."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }

    private func resend() async {
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        do {
            let payload = try await api.resendVerification(email: correctEmail.isEmpty ? nil : correctEmail)
            infoMessage = "A fresh code was sent to \(payload.email)."
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }
}

/// Forgot password: neutral response either way (no account oracle).
struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var sent = false
    @State private var errorMessage: String?
    @State private var showReset = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section {
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
            } header: {
                Text("Reset your password")
            } footer: {
                Text("If that email is registered, a reset link is on its way. The link opens the website today — the in-app reset takes the token from it.")
            }
            if sent {
                Section {
                    Text("If that email is registered, a password-reset link is on its way.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.primary)
                }
            }
            if let errorMessage {
                Section { ErrorBannerView(message: errorMessage) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Send reset link").font(.headline).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting || email.isEmpty)
                Button("I have a reset token") { showReset = true }
            }
        }
        .navigationTitle("Forgot password")
        .navigationDestination(isPresented: $showReset) { ResetPasswordView() }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            _ = try await api.forgotPassword(email: email)
            sent = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }
}

/// Reset password from the emailed link. Phase 1 has no universal link
/// yet (that needs an associated-domains entry), so the token is pasted
/// from the link — the part after /reset-password/ in the email.
/// After a reset the server forces email re-verification.
struct ResetPasswordView: View {
    @EnvironmentObject private var appState: AppState
    @State private var token = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var fieldErrors: [String: String] = [:]
    @State private var showVerify = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section {
                TextField("Reset token (from your email link)", text: $token)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                SecureField("New password (at least 8 characters)", text: $password)
                    .textContentType(.newPassword)
                AuthFieldError(message: fieldErrors["password"])
                SecureField("Confirm new password", text: $confirmPassword)
                    .textContentType(.newPassword)
                AuthFieldError(message: fieldErrors["confirm_password"])
            } header: {
                Text("Set a new password")
            } footer: {
                Text("The token is the long code after /reset-password/ in the email link. It expires in 15 minutes. After resetting, you'll verify your email again.")
            }
            if let errorMessage {
                Section { ErrorBannerView(message: errorMessage) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Reset password").font(.headline).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.primary)
                .disabled(isSubmitting || token.isEmpty || password.isEmpty)
            }
        }
        .navigationTitle("Reset password")
        .navigationDestination(isPresented: $showVerify) {
            VerifyView(onVerified: {
                await appState.refreshSession()
            })
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        fieldErrors = [:]
        guard password == confirmPassword else {
            fieldErrors["confirm_password"] = "The two passwords do not match."
            isSubmitting = false
            return
        }
        do {
            _ = try await api.resetPassword(token: token, password: password)
            showVerify = true
        } catch let error as APIError {
            if case .validation(let message, let fields) = error {
                errorMessage = message
                fieldErrors = fields ?? [:]
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = APIErrorAlert.message(for: error)
        }
        isSubmitting = false
    }
}
