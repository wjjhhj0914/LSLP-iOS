//
//  ChatComposerTextView.swift
//  LSLP-iOS
//
//  Created by Codex on 5/7/26.
//

import SnapKit
import SwiftUI
import UIKit

struct ChatComposerTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat

    let placeholder: String
    let minHeight: CGFloat = 44
    let maxHeight: CGFloat = 120

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ChatComposerContainerView {
        let containerView = ChatComposerContainerView()
        containerView.textView.delegate = context.coordinator
        containerView.placeholderLabel.text = placeholder
        containerView.textView.text = text
        containerView.placeholderLabel.isHidden = !text.isEmpty
        context.coordinator.updateHeight(for: containerView.textView)
        return containerView
    }

    func updateUIView(_ uiView: ChatComposerContainerView, context: Context) {
        if uiView.textView.text != text {
            uiView.textView.text = text
        }
        uiView.placeholderLabel.text = placeholder
        uiView.placeholderLabel.isHidden = !text.isEmpty
        context.coordinator.updateHeight(for: uiView.textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: ChatComposerTextView

        init(parent: ChatComposerTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            if let containerView = textView.superview as? ChatComposerContainerView {
                containerView.placeholderLabel.isHidden = !textView.text.isEmpty
            }
            updateHeight(for: textView)
        }

        func updateHeight(for textView: UITextView) {
            let rawHeight = textView.contentSize.height + 18
            let nextHeight = min(max(rawHeight, parent.minHeight), parent.maxHeight)

            DispatchQueue.main.async {
                self.parent.calculatedHeight = nextHeight
            }
        }
    }
}

final class ChatComposerContainerView: UIView {
    let textView = UITextView()
    let placeholderLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .white
        layer.cornerRadius = 18
        layer.masksToBounds = true

        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 15, weight: .medium)
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 10, bottom: 11, right: 10)

        placeholderLabel.font = .systemFont(ofSize: 15, weight: .medium)
        placeholderLabel.textColor = UIColor(red: 0.72, green: 0.74, blue: 0.72, alpha: 1)

        addSubview(textView)
        addSubview(placeholderLabel)

        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        placeholderLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(18)
            make.top.equalToSuperview().inset(12)
            make.trailing.lessThanOrEqualToSuperview().inset(18)
        }
    }
}
