//
//  LoginView.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let authService: any AuthServicing

    init(authService: (any AuthServicing)? = nil) {
        self.authService = authService ?? AuthService(
            session: .shared,
            tokenStore: InMemoryTokenStore()
        )
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("이메일 로그인")
                        .font(.largeTitle.bold())
                    Text("MV 단계에서는 View가 서비스 계층을 직접 호출합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("이메일", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("비밀번호", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                Button(action: submitLogin) {
                    HStack {
                        Spacer()

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("로그인")
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(canSubmit ? Color.blue : Color.gray.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmit || isLoading)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    private func submitLogin() {
        Task {
            await login()
        }
    }

    @MainActor
    private func login() async {
        guard canSubmit, !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await authService.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            successMessage = "\(response.nick)님 로그인 성공"
        } catch {
            errorMessage = error.localizedDescription
            print("Login failed: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
