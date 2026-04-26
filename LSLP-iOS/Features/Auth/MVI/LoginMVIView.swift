//
//  LoginMVIView.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct LoginMVIView: View {
    @StateObject private var container = LoginContainer()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("이메일 로그인")
                        .font(.largeTitle.bold())
                    Text("MVI 단계에서는 View가 Intent만 전달하고 Container가 상태를 관리합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField(
                        "이메일",
                        text: Binding(
                            get: { container.state.email },
                            set: { container.send(.emailChanged($0)) }
                        )
                    )
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField(
                        "비밀번호",
                        text: Binding(
                            get: { container.state.password },
                            set: { container.send(.passwordChanged($0)) }
                        )
                    )
                    .textContentType(.password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let errorMessage = container.state.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let user = container.state.loggedInUser {
                    Text("\(user.nick)님 로그인 성공")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                Button {
                    container.send(.loginButtonTapped)
                } label: {
                    HStack {
                        Spacer()

                        if container.state.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("로그인")
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(container.state.canSubmit ? Color.blue : Color.gray.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!container.state.canSubmit)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

struct LoginMVIView_Previews: PreviewProvider {
    static var previews: some View {
        LoginMVIView()
    }
}
