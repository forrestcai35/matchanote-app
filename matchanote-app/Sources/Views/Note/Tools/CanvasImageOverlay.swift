
import SwiftUI
import UIKit
import PencilKit

// MARK: - Canvas Image View
struct CanvasImageView: View {
    @ObservedObject var imageManager: CanvasImageManager
    let image: CanvasImage
    let pageIndex: Int
    let canvasSize: CGSize
    @State private var currentSize: CGSize = .zero

    var isSelected: Bool {
        imageManager.selectedImageId == image.id
    }

    // Simple, fast position calculation
    private var currentPosition: CGPoint {
        CGPoint(
            x: image.position.x + image.size.width / 2,
            y: image.position.y + image.size.height / 2
        )
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
                            if isSelected {
                                imageManager.deselectImage()
                            } else {
                                imageManager.selectImage(withId: image.id)
                            }
                        }
                        .gesture(
                            // Only allow dragging if the image is selected
                            isSelected ?
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // PERFORMANCE: Use debounced updates during drag
                                    let newPosition = CGPoint(
                                        x: image.position.x + value.translation.width,
                                        y: image.position.y + value.translation.height
                                    )

                                    var updatedImage = image
                                    updatedImage.updatePosition(to: newPosition)
                                    imageManager.updateImage(updatedImage, isDragging: true)
                                }
                                .onEnded { _ in
                                    // Signal drag end for final undo registration
                                    imageManager.endDragging()
                                } : nil
                        )
                    
                    // Selection controls
                    if isSelected {
                        selectionControls()
                    }
                }
                .position(
                    x: currentPosition.x,
                    y: currentPosition.y
                )
                .zIndex(Double(image.zIndex + (isSelected ? 1000 : 0)))

                
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
                imageManager.removeImage(withId: image.id, fromPage: pageIndex)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 64, height: 64) // Much larger hit area
            .contentShape(Rectangle())
            .offset(x: imageWidth/2 + 14, y: -imageHeight/2 - 14)
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
                        // PERFORMANCE: Use non-dragging update for resize completion
                        imageManager.updateImage(updatedImage, isDragging: false)
                    }
                    currentSize = .zero
                }
            )
            .offset(x: imageWidth/2 + 14, y: imageHeight/2 + 14)
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
        ZStack {
            Circle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: 24, height: 24)
            
            Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
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
    var isPhotoToolActive: Bool = false
    var isTextBoxToolActive: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let hasImages = !imageManager.getImagesForPage(pageIndex).isEmpty
        let shouldInterceptBackground = imageManager.hasSelectedImage
        let allowHitTesting = hasImages || shouldInterceptBackground

        ZStack {
            // Background tap layer - intercepts when image is selected
            if shouldInterceptBackground {
                Color.clear
                    .frame(width: canvasSize.width, height: canvasSize.height)
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
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(allowHitTesting)
        .clipped()
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
        
        // Select the newly added image with a small delay to ensure view is rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectImage(withId: canvasImage.id)
        }
    }
}
