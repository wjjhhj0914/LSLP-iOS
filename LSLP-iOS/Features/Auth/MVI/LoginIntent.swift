//
//  LoginIntent.swift
//  LSLP-iOS
//
//  Created by Codex on 4/23/26.
//

import Foundation

enum LoginIntent {
    case emailChanged(String)
    case passwordChanged(String)
    case loginButtonTapped
    case errorDismissed
}
