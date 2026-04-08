import SwiftUI

struct ExportOptionsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let note: Note
    let totalPages: Int
    let onExport: (ExportType, [Int]) -> Void
    
    @State private var selectedExportType: ExportType = .pdf
    @State private var selectedPages: Set<Int> = []
    @State private var selectAllPages: Bool = true
    @State private var showOnlyBookmarked: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom header with Cancel button
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                    Spacer()

                    Text("Export Options")
                        .font(.jost(.headline()))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            colorScheme == .dark
                                ? Color.matchabrown_dark : Color.matchabrown_light)

                    Spacer()

                    // Empty view to balance Cancel button for centering
                    Text("Cancel")
                        .foregroundColor(.clear)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(
                    colorScheme == .dark
                        ? Color.matchabackground_dark : Color.matchabackground_light)

                // Export Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.jost(.headline()))
                        .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    ForEach(ExportType.allCases) { exportType in
                        HStack {
                            Image(systemName: exportType.icon)
                                .frame(width: 24)
                            Text(exportType.rawValue)
                                .font(.jost(.body()))
                            Spacer()
                            if selectedExportType == exportType {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedExportType == exportType ? 
                                      (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1)) : 
                                      Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedExportType == exportType ? 
                                       (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light) : 
                                       Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedExportType = exportType
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
                
                Divider()
                
                // Page Selection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Select Pages")
                            .font(.jost(.headline()))
                            .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                        Spacer()

                        // Bookmarked filter button
                        Button(action: {
                            showOnlyBookmarked.toggle()
                            // When filter changes, reset selection
                            if showOnlyBookmarked {
                                selectedPages = Set(filteredPages)
                                selectAllPages = true
                            } else {
                                selectedPages = Set(0..<totalPages)
                                selectAllPages = true
                            }
                        }) {
                            Image(systemName: showOnlyBookmarked ? "bookmark.fill" : "bookmark")
                                .foregroundColor(showOnlyBookmarked ? .matchalight_dark : (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light))
                        }
                        .font(.jost(.subheadline()))

                        Toggle("All Pages", isOn: $selectAllPages)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light))
                            .onChange(of: selectAllPages) { oldValue, newValue in
                                if newValue {
                                    selectedPages = Set(filteredPages)
                                } else {
                                    selectedPages.removeAll()
                                }
                            }
                        Text("All")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark.opacity(0.7) : Color.matchabrown_light.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Grid of page checkboxes
                    ZStack {
                        ScrollView {
                            LazyVGrid(columns: pageGridColumns, spacing: 16) {
                                ForEach(filteredPages, id: \.self) { pageIndex in
                                    PageSelectButton(
                                        pageNumber: pageIndex + 1,
                                        pageIndex: pageIndex,
                                        note: note,
                                        isSelected: selectedPages.contains(pageIndex),
                                        colorScheme: colorScheme
                                    ) {
                                        if selectedPages.contains(pageIndex) {
                                            selectedPages.remove(pageIndex)
                                            selectAllPages = false
                                        } else {
                                            selectedPages.insert(pageIndex)
                                            if selectedPages.count == filteredPages.count {
                                                selectAllPages = true
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }

                        // Top fade effect
                        VStack {
                            (colorScheme == .dark
                                ? Color.matchabackground_dark
                                : Color.matchabackground_light)
                                .mask(
                                    LinearGradient(
                                        colors: [Color.white, Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 10)
                                .allowsHitTesting(false)

                            Spacer()
                        }
                    }
                }
                
                Spacer()
                
                // Export Button
                VStack {
                    Button(action: {
                        let pagesToExport = selectAllPages ? Array(0..<totalPages) : Array(selectedPages).sorted()
                        if !pagesToExport.isEmpty {
                            onExport(selectedExportType, pagesToExport)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export \(selectAllPages ? "All" : "\(selectedPages.count)") Page\(selectedPages.count == 1 ? "" : "s")")
                        }
                        .font(.jost(.headline()))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedPages.isEmpty ? Color.gray : (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light))
                        )
                    }
                    .disabled(selectedPages.isEmpty)
                    .padding()
                }
            }
            .background(colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light)
            .navigationBarHidden(true)
        }
        .onAppear {
            // Initialize with all pages selected
            selectedPages = Set(filteredPages)
        }
    }
    
    private var pageGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 16)]
    }

    private var filteredPages: [Int] {
        let allPages = Array(0..<totalPages)
        if showOnlyBookmarked {
            return allPages.filter { note.bookmarkedPages.contains($0) }
        }
        return allPages
    }
}

struct PageSelectButton: View {
    let pageNumber: Int
    let pageIndex: Int
    let note: Note
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    @State private var previewImage: UIImage?
    @State private var isGeneratingPreview = false
    
    private var noteAspectRatio: CGFloat {
        PaperUtilities.paperAspectRatio(
            for: note.paperSize,
            orientation: note.paperOrientation
        )
    }
    
    private var previewBaseSize: CGSize {
        note.paperOrientation == .landscape
            ? CGSize(width: 90, height: 70)
            : CGSize(width: 70, height: 90)
    }
    
    private var previewSize: CGSize {
        let area = previewBaseSize.width * previewBaseSize.height
        guard noteAspectRatio > 0, area > 0 else { return previewBaseSize }
        let width = sqrt(area * noteAspectRatio)
        let height = area / width
        return CGSize(width: width, height: height)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Base paper background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(getPaperBackgroundColor(for: note.paperColor))
                        .frame(width: previewSize.width, height: previewSize.height)
                    
                    // Preview image overlay
                    if let previewImage = previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if isGeneratingPreview {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    
                    // Selection overlay
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: previewSize.width, height: previewSize.height)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                            .font(.title2)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? 
                               (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light) : 
                               Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
                
                Text("Page \(pageNumber)")
                    .font(.jost(.caption()))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Generate preview lazily when view appears - only if there's content
            generatePreviewIfNeeded()
        }
    }
    
    private func generatePreviewIfNeeded() {
        // Only generate if there's actual content on this page
        guard PreviewGenerator.hasContent(note: note, pageIndex: pageIndex) else {
            previewImage = nil
            return
        }
        
        // Check if already generating
        guard !isGeneratingPreview else { return }
        
        isGeneratingPreview = true
        
        // Generate preview asynchronously on background thread
        // Use a smaller custom size for better performance with many pages
        DispatchQueue.global(qos: .userInitiated).async {
            let preview = PreviewGenerator.generatePreview(
                for: note,
                pageIndex: pageIndex,
                size: .custom(previewSize)
            )
            
            DispatchQueue.main.async {
                self.previewImage = preview
                self.isGeneratingPreview = false
            }
        }
    }
    
    private func getPaperBackgroundColor(for color: PaperColor) -> Color {
        return PaperUtilities.getPaperBackgroundColor(for: color)
    }
}
