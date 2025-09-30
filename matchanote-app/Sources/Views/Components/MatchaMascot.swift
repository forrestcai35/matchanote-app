//
//  MatchaMascot.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI

// MARK: - Mascot Emotion States
enum MascotEmotion: String, CaseIterable {
    case happy = "leaf_happy"
    case sad = "leaf_sad"
    case love = "leaf_love"
    case knowledge = "leaf_knowledge"
    case upset = "leaf_upset"
    case wink = "leaf_wink"
    case star = "leaf_star"
    
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .sad: return "Sad"
        case .love: return "Love"
        case .knowledge: return "Knowledge"
        case .upset: return "Upset"
        case .wink: return "Wink"
        case .star: return "Star"
        }
    }
    
    var description: String {
        switch self {
        case .happy: return "Feeling great and ready to help!"
        case .sad: return "A bit down, but here to support you"
        case .love: return "Spreading love and positive vibes"
        case .knowledge: return "Full of wisdom and ready to share"
        case .upset: return "A bit frustrated, but still here for you"
        case .wink: return "Playful and ready for some fun"
        case .star: return "Full of awe and wonder"
        }
    }
}

// MARK: - Mascot Size Options
enum MascotSize {
    case small
    case medium
    case large
    case extraLarge
    
    var frameSize: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 60
        case .large: return 80
        case .extraLarge: return 120
        }
    }
    
    var animationScale: CGFloat {
        switch self {
        case .small: return 1.0
        case .medium: return 1.1
        case .large: return 1.2
        case .extraLarge: return 1.3
        }
    }
}

// MARK: - Matcha Mascot Component
struct MatchaMascot: View {
    let emotion: MascotEmotion
    let size: MascotSize
    let isAnimated: Bool
    let showDescription: Bool
    
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        emotion: MascotEmotion = .happy,
        size: MascotSize = .medium,
        isAnimated: Bool = true,
        showDescription: Bool = false
    ) {
        self.emotion = emotion
        self.size = size
        self.isAnimated = isAnimated
        self.showDescription = showDescription
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Mascot Image
            Image(emotion.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: size.frameSize, height: size.frameSize)
                .scaleEffect(isAnimating ? size.animationScale : 1.0)
                .animation(
                    isAnimated ? 
                        .easeInOut(duration: 0.3) : 
                        .easeInOut(duration: 0.2),
                    value: isAnimating
                )
                .onAppear {
                    if isAnimated {
                        withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                            isAnimating = true
                        }
                    }
                }
            
            // Optional Description
            if showDescription {
                VStack(spacing: 4) {
                    Text(emotion.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                        )
                    
                    Text(emotion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.4).delay(0.3), value: isAnimating)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Animated Mascot with Context
struct MatchaMascotWithContext: View {
    let emotion: MascotEmotion
    let size: MascotSize
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        emotion: MascotEmotion = .happy,
        size: MascotSize = .large,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.emotion = emotion
        self.size = size
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Mascot
            MatchaMascot(
                emotion: emotion,
                size: size,
                isAnimated: true
            )
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeInOut(duration: 0.3).delay(0.1), value: isVisible)
            
            // Content
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                    )
                    .multilineTextAlignment(.center)
                    .opacity(isVisible ? 1.0 : 0.0)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(.easeInOut(duration: 0.3).delay(0.2), value: isVisible)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(isVisible ? 1.0 : 0.0)
                        .offset(y: isVisible ? 0 : 10)
                        .animation(.easeInOut(duration: 0.3).delay(0.3), value: isVisible)
                }
                
                // Action Button
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text(actionTitle)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isVisible ? 1.0 : 0.0)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(.easeInOut(duration: 0.3).delay(0.4), value: isVisible)
                }
            }
        }
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Floating Mascot (for subtle presence)
struct MatchaFloatingMascot: View {
    let emotion: MascotEmotion
    let position: FloatingPosition
    
    @Environment(\.colorScheme) private var colorScheme
    
    enum FloatingPosition {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
        case center
        
        var alignment: Alignment {
            switch self {
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
            case .center: return .center
            }
        }
    }
    
    init(emotion: MascotEmotion = .wink, position: FloatingPosition = .topTrailing) {
        self.emotion = emotion
        self.position = position
    }
    
    var body: some View {
        MatchaMascot(
            emotion: emotion,
            size: .small,
            isAnimated: false
        )
        .opacity(0.6)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        // Basic mascot
        MatchaMascot(emotion: .happy, size: .medium)
        
        // Mascot with context
        MatchaMascotWithContext(
            emotion: .knowledge,
            size: .large,
            title: "Welcome to Matcha!",
            subtitle: "Your AI-powered note-taking companion",
            actionTitle: "Get Started",
            action: {}
        )
        
        // Floating mascot
        ZStack {
            Color.gray.opacity(0.1)
                .frame(height: 200)
            
            MatchaFloatingMascot(emotion: .wink, position: .topTrailing)
        }
    }
    .padding()
}
