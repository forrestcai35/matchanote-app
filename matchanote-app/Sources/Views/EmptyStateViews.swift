//
//  EmptyStateViews.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI

// MARK: - Empty State Views
struct EmptyDocumentsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showNewWrittenNoteView: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("No Documents")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                Text("Create your first note or folder to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                showNewWrittenNoteView = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Create Note")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct EmptyFavoritesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedItem: String
    @Binding var currentFolderID: UUID?
    @Binding var folderPath: [Folder]
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("No Favorites")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                Text("Mark notes as favorites to see them here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                selectedItem = "documents"
                currentFolderID = nil
                folderPath = []
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("Browse Documents")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct EmptyRecentsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedItem: String
    @Binding var currentFolderID: UUID?
    @Binding var folderPath: [Folder]
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("No Recent Notes")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                Text("Recently opened notes will appear here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                selectedItem = "documents"
                currentFolderID = nil
                folderPath = []
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("Browse Documents")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}
