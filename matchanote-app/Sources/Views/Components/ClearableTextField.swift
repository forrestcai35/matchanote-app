//
//  ClearableTextField.swift
//  matchanote-app
//
//  Created by Claude Code
//

import SwiftUI

/// A text field with a clear button that appears when text is entered
struct ClearableTextField: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)

            // Clear button - only visible when there's text
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray3))
                        .imageScale(.medium)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    VStack(spacing: 20) {
        ClearableTextField(placeholder: "Enter text", text: .constant(""))
        ClearableTextField(placeholder: "Enter text", text: .constant("Sample text"))
    }
    .padding()
}
