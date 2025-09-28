//
//  CanvasImageOverlay.swift
//  MatchaNotes
//
//  Image overlay system for PencilKit canvas
//

import SwiftUI
import UIKit
import PencilKit

// MARK: - Individual Image View
struct CanvasImageView: View {
    @ObservedObject var imageManager: CanvasImageManager
    let image: CanvasImage
    let pageIndex: Int
    let canvasSize: CGSize
    @State private var isDragging: Bool = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var currentDragPosition: CGPoint = .zero
    @State private var dragOffset: CGPoint = .zero
    @State private var offset: CGSize = .zero
    @State private var currentSize: CGSize = .zero

    var isSelected: Bool {
        imageManager.selectedImageId == image.id
    }

    var effectivePosition: CGPoint {
        if isDragging {
            return currentDragPosition
        } else {
            return CGPoint(
                x: image.position.x + image.size.width / 2,
                y: image.position.y + image.size.height / 2
            )
        }
    }
    
    var body: some View {
        Group {
            if let uiImage = ImageUtilities.dataToImage(image.imageData) {
                ZStack {
                    // Main image
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: currentSize.width > 0 ? currentSize.width : image.size.width,
                            height: currentSize.height > 0 ? currentSize.height : image.size.height
                        )
                        .overlay(
                            Rectangle()
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        )
                        .contentShape(Rectangle()) // Ensure precise hit testing
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if isSelected {
                                    imageManager.deselectImage()
                                } else {
                                    imageManager.selectImage(withId: image.id)
                                }
                            }
                        }
                        .highPriorityGesture(
                            // Only allow dragging if the image is selected
                            isSelected ?
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { value in
                                    // Update the actual image position
                                    var updatedImage = image
                                    let newPosition = CGPoint(
                                        x: image.position.x + value.translation.width,
                                        y: image.position.y + value.translation.height
                                    )
                                    updatedImage.updatePosition(to: newPosition)
                                    imageManager.updateImage(updatedImage)
                                    offset = .zero
                                } : nil
                        )
                    
                    // Selection controls
                    if isSelected {
                        selectionControls()
                    }
                }
                .offset(offset)
                .position(
                    x: image.position.x + image.size.width / 2,
                    y: image.position.y + image.size.height / 2
                )
                .zIndex(Double(image.zIndex + (isSelected ? 1000 : 0)))
                // The highPriorityGesture above ensures the scroll view doesn't capture drags
                
            }
        }
    }
    
    @ViewBuilder
    private func selectionControls() -> some View {
        let imageWidth = currentSize.width > 0 ? currentSize.width : image.size.width
        let imageHeight = currentSize.height > 0 ? currentSize.height : image.size.height
        
        ZStack {
            // Delete button (top-right corner)
            Button(action: {
                withAnimation(.spring()) {
                    imageManager.removeImage(withId: image.id, fromPage: pageIndex)
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 64, height: 64) // Much larger hit area
            .contentShape(Rectangle())
            .offset(x: imageWidth/2 + 20, y: -imageHeight/2 - 20)
            .allowsHitTesting(true)
            
            // Corner handle - proportional scaling (bottom-right)
            ProportionalResizeHandle(
                startSize: currentSize.width > 0 ? currentSize : image.size,
                onChanged: { newSize in
                    currentSize = newSize
                },
                onEnd: {
                    if currentSize.width > 0 && currentSize.height > 0 {
                        var updatedImage = image
                        updatedImage.resize(to: currentSize)
                        imageManager.updateImage(updatedImage)
                    }
                    currentSize = .zero
                }
            )
            .offset(x: imageWidth/2 + 20, y: imageHeight/2 + 20)
            .allowsHitTesting(true)
        }
    }
}

// MARK: - Proportional Resize Handle (Corner)
struct ProportionalResizeHandle: View {
    let startSize: CGSize
    let onChanged: (CGSize) -> Void
    let onEnd: () -> Void
    
    var body: some View {
        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.blue)
            .frame(width: 20, height: 20)
            .frame(width: 64, height: 64) // Much larger hit area
            .contentShape(Rectangle())
            .allowsHitTesting(true)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Calculate proportional scaling based on average movement
                    let scaleChange = (value.translation.width + value.translation.height) / 2
                    let aspectRatio = startSize.width / startSize.height
                    
                    let newWidth = max(50, startSize.width + scaleChange)
                    let newHeight = max(50, newWidth / aspectRatio)
                    
                    let newSize = CGSize(width: newWidth, height: newHeight)
                    onChanged(newSize)
                }
                .onEnded { _ in
                    onEnd()
                }
        )
    }
}

// MARK: - Canvas Image Overlay Container
struct CanvasImageOverlay: View {
    @ObservedObject var imageManager: CanvasImageManager
    let pageIndex: Int
    let canvasSize: CGSize
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Only intercept background taps when there's a selected image to deselect
            if imageManager.hasSelectedImage {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        imageManager.deselectImage()
                    }
            }
            
            // Images for current page
            ForEach(imageManager.getImagesForPage(pageIndex), id: \.id) { image in
                CanvasImageView(
                    imageManager: imageManager,
                    image: image,
                    pageIndex: pageIndex,
                    canvasSize: canvasSize
                )
            }
        }
        .clipped()
        .allowsHitTesting(imageManager.getImagesForPage(pageIndex).count > 0)
    }
}

// MARK: - Image Picker Integration
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void

    init(isPresented: Binding<Bool>, sourceType: UIImagePickerController.SourceType = .photoLibrary, onImageSelected: @escaping (UIImage) -> Void) {
        self._isPresented = isPresented
        self.sourceType = sourceType
        self.onImageSelected = onImageSelected
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.modalPresentationStyle = .formSheet

        // Check if the source type is available
        if sourceType == .camera {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                picker.sourceType = .camera
                picker.cameraCaptureMode = .photo
                // Set media types to ensure only photos are captured
                picker.mediaTypes = ["public.image"]
            } else {
                // Fallback to photo library if camera not available
                picker.sourceType = .photoLibrary
                print("Camera not available, falling back to photo library")
            }
        } else {
            picker.sourceType = .photoLibrary
        }

        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }

            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImageSelected(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImageSelected(originalImage)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}

// MARK: - Image Insertion Helper
extension CanvasImageManager {
    func addImageToPage(_ image: UIImage, at position: CGPoint, pageIndex: Int) {
        // Calculate appropriate size
        let initialSize = ImageUtilities.calculateInitialSize(for: image, maxWidth: 300, maxHeight: 300)
        
        // Convert image to data
        guard let imageData = ImageUtilities.imageToData(image, compressionQuality: 0.8) else {
            print("Failed to convert image to data")
            return
        }
        
        // Create canvas image
        let canvasImage = CanvasImage(
            imageData: imageData,
            position: position,
            size: initialSize,
            pageIndex: pageIndex
        )
        
        // Add to manager (this will automatically register undo action)
        addImage(canvasImage)
        
        // Select the newly added image
        selectImage(withId: canvasImage.id)
    }
}
