
import SwiftUI
import UIKit
import PencilKit

// MARK: - Canvas Image View
struct CanvasImageView: View {
    @ObservedObject var imageManager: CanvasImageManager
    @ObservedObject var textBoxManager: TextBoxManager
    let image: CanvasImage
    let pageIndex: Int
    let canvasSize: CGSize
    @State private var currentSize: CGSize = .zero
    @State private var showMenu: Bool = false

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
                                // Show menu when tapping selected image
                                showMenu = true
                            } else {
                                textBoxManager.deselectAllTextBoxes()
                                imageManager.selectImage(withId: image.id)
                            }
                        }
                        .confirmationDialog("Image Options", isPresented: $showMenu) {
                            Button("Crop") {
                                imageManager.startCropping(for: image.id, onPage: pageIndex)
                            }

                            Button("Copy") {
                                copyImageToClipboard(uiImage)
                            }

                            Button("Cancel", role: .cancel) { }
                        }
                        .gesture(
                            // Only allow dragging if the image is selected and not cropping
                            isSelected && !imageManager.isCropping ?
                            DragGesture(minimumDistance: 5)
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
                    
                    // Selection controls (hide when in crop mode)
                    if isSelected && !imageManager.isCropping {
                        selectionControls()
                    }
                }
                .rotationEffect(.degrees(image.rotation))
                .position(
                    x: currentPosition.x,
                    y: currentPosition.y
                )
                .zIndex(Double(image.zIndex + (isSelected ? 1000 : 0)))

                
            }
        }
    }
    
    private func copyImageToClipboard(_ uiImage: UIImage) {
        #if os(iOS)
        // Set both image and PNG data for better compatibility
        if let pngData = uiImage.pngData() {
            UIPasteboard.general.setData(pngData, forPasteboardType: "public.png")
        }
        UIPasteboard.general.image = uiImage
        #endif
    }

    @ViewBuilder
    private func selectionControls() -> some View {
        let imageWidth = currentSize.width > 0 ? currentSize.width : image.size.width
        let imageHeight = currentSize.height > 0 ? currentSize.height : image.size.height
        let rotationHandleOffset = CGVector(
            dx: -imageWidth / 2 - 14,
            dy: -imageHeight / 2 - 14
        )
        let centerPoint = CGPoint(
            x: image.position.x + imageWidth / 2,
            y: image.position.y + imageHeight / 2
        )
        
        ZStack {
            // Delete button (top-right corner)
            Button(action: {
                imageManager.removeImage(withId: image.id, fromPage: pageIndex)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
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
                        // Calculate the center point before resize
                        let centerX = image.position.x + image.size.width / 2
                        let centerY = image.position.y + image.size.height / 2

                        // Update size
                        updatedImage.resize(to: currentSize)

                        // Adjust position to keep center point stable
                        updatedImage.position.x = centerX - currentSize.width / 2
                        updatedImage.position.y = centerY - currentSize.height / 2

                        // PERFORMANCE: Use non-dragging update for resize completion
                        imageManager.updateImage(updatedImage, isDragging: false)
                    }
                    currentSize = .zero
                }
            )
            .offset(x: imageWidth/2 + 14, y: imageHeight/2 + 14)
            .allowsHitTesting(true)

            RotationHandle(
                center: centerPoint,
                initialVector: rotationHandleOffset,
                coordinateSpaceName: CanvasCoordinateSpace.canvas,
                onBegan: {
                    imageManager.beginDragging()
                },
                onChanged: { newRotation in
                    var updatedImage = image
                    updatedImage.rotation = CanvasImage.snapRotation(newRotation)
                    imageManager.updateImage(updatedImage, isDragging: true)
                },
                onEnded: { finalRotation in
                    var updatedImage = image
                    updatedImage.rotation = CanvasImage.snapRotation(finalRotation)
                    imageManager.updateImage(updatedImage, isDragging: false)
                    imageManager.endDragging()
                }
            )
            .offset(x: rotationHandleOffset.dx, y: rotationHandleOffset.dy)
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
                .frame(width: 18, height: 18)

            Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                .font(.system(size: 9, weight: .medium))
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

// MARK: - Crop Overlay
struct CropOverlay: View {
    @ObservedObject var imageManager: CanvasImageManager
    let imageId: UUID
    let pageIndex: Int
    @State private var cropRect: CGRect
    @State private var initialCropRect: CGRect = .zero

    private var imageBounds: CGRect {
        guard let image = imageManager.getImage(withId: imageId, onPage: pageIndex) else {
            return .zero
        }
        return image.frame
    }

    init(imageManager: CanvasImageManager, imageId: UUID, pageIndex: Int) {
        self.imageManager = imageManager
        self.imageId = imageId
        self.pageIndex = pageIndex
        self._cropRect = State(initialValue: imageManager.cropRect)
    }

    var body: some View {
        ZStack {
            // Show original image bounds as faded reference
            if let originalImage = imageManager.getImage(withId: imageId, onPage: pageIndex),
               let uiImage = ImageUtilities.dataToImage(originalImage.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: originalImage.size.width, height: originalImage.size.height)
                    .position(x: originalImage.position.x + originalImage.size.width / 2,
                             y: originalImage.position.y + originalImage.size.height / 2)
                    .opacity(0.3)
            }

            // Semi-transparent overlay outside crop area
            GeometryReader { geometry in
                Path { path in
                    // Full canvas rectangle
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    // Subtract crop rectangle to create cutout
                    path.addRect(cropRect)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            }

            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Resize handles at corners
            ForEach(CropHandle.allCases, id: \.self) { handle in
                cropHandle(for: handle)
            }

            // Control buttons
            VStack {
                HStack(spacing: 8) {
                    // Cancel button
                    Button(action: {
                        imageManager.cancelCrop()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                            Text("Cancel")
                                .font(.jost(.caption()))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.8))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Apply button
                    Button(action: {
                        imageManager.applyCrop(to: imageId, onPage: pageIndex, cropRect: cropRect)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                            Text("Crop")
                                .font(.jost(.caption()))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.matchalight_dark, Color.matchalight_light],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 16)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func cropHandle(for handle: CropHandle) -> some View {
        let handlePosition = handle.position(in: cropRect)

        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .position(handlePosition)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if initialCropRect == .zero {
                            initialCropRect = cropRect
                        }
                        updateCropRect(for: handle, translation: value.translation)
                    }
                    .onEnded { _ in
                        initialCropRect = .zero
                    }
            )
    }

    private func updateCropRect(for handle: CropHandle, translation: CGSize) {
        var newRect = initialCropRect

        switch handle {
        case .topLeft:
            newRect.origin.x = initialCropRect.origin.x + translation.width
            newRect.origin.y = initialCropRect.origin.y + translation.height
            newRect.size.width = initialCropRect.size.width - translation.width
            newRect.size.height = initialCropRect.size.height - translation.height
        case .topRight:
            newRect.origin.y = initialCropRect.origin.y + translation.height
            newRect.size.width = initialCropRect.size.width + translation.width
            newRect.size.height = initialCropRect.size.height - translation.height
        case .bottomLeft:
            newRect.origin.x = initialCropRect.origin.x + translation.width
            newRect.size.width = initialCropRect.size.width - translation.width
            newRect.size.height = initialCropRect.size.height + translation.height
        case .bottomRight:
            newRect.size.width = initialCropRect.size.width + translation.width
            newRect.size.height = initialCropRect.size.height + translation.height
        }

        // Constrain to image bounds
        let bounds = imageBounds

        // Clamp position to stay within image
        newRect.origin.x = max(bounds.minX, min(newRect.origin.x, bounds.maxX - 50))
        newRect.origin.y = max(bounds.minY, min(newRect.origin.y, bounds.maxY - 50))

        // Clamp size to stay within image
        newRect.size.width = max(50, min(newRect.size.width, bounds.maxX - newRect.origin.x))
        newRect.size.height = max(50, min(newRect.size.height, bounds.maxY - newRect.origin.y))

        // Ensure minimum size and update
        if newRect.width >= 50 && newRect.height >= 50 {
            cropRect = newRect
            imageManager.updateCropRect(newRect)
        }
    }
}

enum CropHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

// MARK: - Canvas Image Overlay Container
struct CanvasImageOverlay: View {
    @ObservedObject var imageManager: CanvasImageManager
    @ObservedObject var textBoxManager: TextBoxManager
    let pageIndex: Int
    let canvasSize: CGSize
    var isPhotoToolActive: Bool = false
    var isTextBoxToolActive: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shouldInterceptBackground = imageManager.hasSelectedImage

        ZStack {
            // Background tap layer - only for deselection when an image is selected
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
                    textBoxManager: textBoxManager,
                    image: image,
                    pageIndex: pageIndex,
                    canvasSize: canvasSize
                )
            }

            // Crop overlay when in cropping mode
            if imageManager.isCropping, let selectedImageId = imageManager.selectedImageId {
                CropOverlay(
                    imageManager: imageManager,
                    imageId: selectedImageId,
                    pageIndex: pageIndex
                )
                .zIndex(10000) // Ensure it's on top of everything
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
        .coordinateSpace(name: CanvasCoordinateSpace.canvas)
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
        picker.allowsEditing = false
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
