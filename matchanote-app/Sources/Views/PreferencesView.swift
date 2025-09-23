import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Preferences")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Assistant section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image("logo_icon")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Assistant")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(
                                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                        }
                        
                        // Assistant orientation setting
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Default Orientation")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Choose which side the assistant will appear on when opening notes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            // Orientation picker
                            HStack(spacing: 16) {
                                ForEach(AssistantOrientation.allCases, id: \.self) { orientation in
                                    orientationOption(orientation)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                
                Spacer()
            }
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                }
            }
        }
    }
    
    @ViewBuilder
    private func orientationOption(_ orientation: AssistantOrientation) -> some View {
        Button(action: {
            preferencesManager.assistantDefaultOrientation = orientation
        }) {
            HStack(spacing: 12) {
                // Visual representation
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            preferencesManager.assistantDefaultOrientation == orientation
                                ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                : Color.gray.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 80, height: 50)
                    
                    HStack(spacing: 2) {
                        if orientation == .left {
                            Rectangle()
                                .fill(
                                    preferencesManager.assistantDefaultOrientation == orientation
                                        ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                        : Color.gray.opacity(0.5)
                                )
                                .frame(width: 20, height: 30)
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 48, height: 30)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 48, height: 30)
                            Rectangle()
                                .fill(
                                    preferencesManager.assistantDefaultOrientation == orientation
                                        ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                                        : Color.gray.opacity(0.5)
                                )
                                .frame(width: 20, height: 30)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(orientation.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Assistant on the \(orientation.displayName.lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if preferencesManager.assistantDefaultOrientation == orientation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        preferencesManager.assistantDefaultOrientation == orientation
                            ? (colorScheme == .dark 
                                ? Color.matchalight_dark.opacity(0.1) 
                                : Color.matchalight_light.opacity(0.1))
                            : Color.clear
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
