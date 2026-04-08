import SwiftUI

// MARK: - Chat History Dropdown
struct ChatHistoryDropdown: View {
    @ObservedObject var assistantState: AIAssistantState
    @ObservedObject var chatStorage: ChatStorageManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var conversationsToShow = 10

    // Combine current unsaved conversation with saved conversations for display
    private var displayedConversations: [ChatConversation] {
        var conversations = chatStorage.conversations

        // If there's a current conversation that's not in the saved list, prepend it
        if let current = chatStorage.currentConversation,
           !conversations.contains(where: { $0.id == current.id }) {
            conversations.insert(current, at: 0)
        }

        return conversations
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Recent Chats")
                    .font(.jost(.headline()))
                
                Spacer()
            }
            .padding()
            
            Divider()

            // Conversations list
            if displayedConversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message.badge")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No conversations yet")
                        .font(.jost(.subheadline()))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(displayedConversations.prefix(conversationsToShow)) { conversation in
                            DropdownConversationRow(
                                conversation: conversation,
                                isSelected: chatStorage.currentConversation?.id == conversation.id,
                                onSelect: {
                                    assistantState.loadConversation(conversation)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        assistantState.showingChatHistory = false
                                    }
                                },
                                onDelete: {
                                    chatStorage.deleteConversation(conversation)
                                }
                            )
                        }

                        // Load More button
                        if conversationsToShow < displayedConversations.count {
                            Button(action: {
                                withAnimation {
                                    conversationsToShow += 50
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Show \(min(50, displayedConversations.count - conversationsToShow)) more")
                                        .font(.jost(.subheadline()))
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 400)
            }
            
            Divider()
            
            // Footer with info
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Auto-deleted after 30 days")
                    .font(.jost(.caption2()))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(
            (colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
                .brightness(colorScheme == .dark ? 0.05 : 0)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
        .onAppear {
            // Reset to show only 10 conversations when dropdown opens
            conversationsToShow = 10
        }
    }
}

// MARK: - Dropdown Conversation Row
struct DropdownConversationRow: View {
    let conversation: ChatConversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Icon indicator
                Circle()
                    .fill(
                        isSelected ?
                            (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light) :
                            Color.gray.opacity(0.3)
                    )
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(.jost(.subheadline()))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(conversation.timeAgoText)
                        Text("•")
                        Text("\(conversation.messages.count) msgs")
                    }
                    .font(.jost(.caption2()))
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.jost(.caption()))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ?
                    (colorScheme == .dark ? Color.matchabrown_dark.opacity(0.15) : Color.matchabrown_light.opacity(0.1)) :
                    Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

