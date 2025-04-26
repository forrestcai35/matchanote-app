import SwiftUI

#if canImport(UIKit)
  import UIKit
  import PhotosUI
#elseif canImport(AppKit)
  import AppKit
#endif

class AIAssistantState: ObservableObject {
  @Published var messages: [ChatMessage] = []
  @Published var userInput = ""
  @Published var selectedModel = "qwen/qwq-32b:free"
  @Published var isLoading = false
  @Published var errorMessage: String? = nil
  @Published var tempMediaItems: [MediaItem] = []
  @Published var availableModels = [
    "qwen/qwq-32b:free", "deepseek/deepseek-r1-zero:free", "google/gemma-3-1b-it:free",
    "mistralai/mistral-small-3.1-24b-instruct:free",
  ]
}

struct ChatMessage: Identifiable {
  let id = UUID()
  let content: String
  let isUser: Bool
  let model: String
  var mediaItems: [MediaItem]? = nil

  init(content: String, isUser: Bool, model: String = "", mediaItems: [MediaItem]? = nil) {
    self.content = content
    self.isUser = isUser
    self.model = model
    self.mediaItems = mediaItems
  }
}

struct MediaItem: Identifiable {
  let id = UUID()
  let data: Data
  let type: MediaType

  enum MediaType {
    case image
    case file(String)
  }
}

// AI Assistant View
struct AIAssistantView: View {
  // Use an environment object instead of local state to persist across orientation changes
  @EnvironmentObject private var state: AIAssistantState
  @State private var showingImagePicker = false
  @State private var showingFileImporter = false
  @State private var showingCamera = false
  @State private var contextInfo = ""
  @Environment(\.colorScheme) private var colorScheme
  @State private var isInputTargeted = false

  // Configure models
  init() {
    OpenRouterAPI.configure(apiKey: EnvironmentManager.shared.getLlmAPIKey(for: "OPENROUTER")!)
  }

  var body: some View {
    VStack(spacing: 0) {
      // Assistant header
      HStack {
        Image(systemName: "sparkles")
          .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
        Text("Matcha Assistant")
          .font(.headline)

        Spacer()

      }
      .padding()
      .background(colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)

      // Chat history area
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {

          // Display messages
          ForEach(state.messages) { message in
            if message.isUser {
              UserMessageView(message: message)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
              AssistantMessageView(message: message)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          if state.isLoading {
            HStack {
              ProgressView()
                .padding(.horizontal, 4)
              Text("Thinking...")
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
          }

          if let error = state.errorMessage {
            Text(error)
              .foregroundColor(.red)
              .font(.caption)
              .padding(.vertical, 8)
          }
        }
        .padding()
      }

      // Input area
      VStack(spacing: 8) {
        // Controls row
        HStack {
          // AI Model dropdown
          Menu {
            ForEach(state.availableModels, id: \.self) { model in
              Button(model) {
                state.selectedModel = model
              }
            }
          } label: {
            HStack {
              Text(state.selectedModel)
                .font(.caption)
                .foregroundColor(.primary)
              Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 6)
            .cornerRadius(8)
          }

          // Add media menu
          Menu {
            Button {
              showingImagePicker = true
            } label: {
              Label("Choose Image", systemImage: "photo")
            }

            Button {
              showingFileImporter = true
            } label: {
              Label("Import File", systemImage: "doc")
            }

            #if canImport(UIKit)
              Button {
                showingCamera = true
              } label: {
                Label("Take Photo", systemImage: "camera")
              }
            #endif
          } label: {
            Image(systemName: "plus.circle")
              .foregroundColor(.gray)
          }
          .padding(.horizontal, 6)

          Spacer()
        }
        .padding(.horizontal)

        ZStack(alignment: .bottomTrailing) {
          VStack {
            if !state.tempMediaItems.isEmpty {
              ScrollView(.horizontal) {
                HStack {
                  ForEach(state.tempMediaItems) { item in
                    ZStack(alignment: .topTrailing) {
                      if case .image = item.type {
                        #if canImport(UIKit)
                          if let uiImage = UIImage(data: item.data) {
                            Image(uiImage: uiImage)
                              .resizable()
                              .scaledToFit()
                              .frame(height: 60)
                              .cornerRadius(6)
                          }
                        #elseif canImport(AppKit)
                          if let nsImage = NSImage(data: item.data) {
                            Image(nsImage: nsImage)
                              .resizable()
                              .scaledToFit()
                              .frame(height: 60)
                              .cornerRadius(6)
                          }
                        #endif
                      } else if case .file(let name) = item.type {
                        HStack {
                          Image(systemName: "doc")
                          Text(name)
                            .lineLimit(1)
                        }
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .frame(height: 60)
                      }

                      Button(action: {
                        removeMediaItem(item)
                      }) {
                        Image(systemName: "xmark.circle.fill")
                          .foregroundColor(.red)
                          .background(Color.white.opacity(0.7))
                          .clipShape(Circle())
                      }
                      .padding(2)
                    }
                    .padding(2)
                  }
                }
              }
              .padding(.horizontal)
            }

            GrowingTextEditor(text: $state.userInput, placeholderText: "Ask Matcha Assistant...")
              .padding(.vertical, 8)
              .padding(.trailing, 40)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.gray.opacity(0.3), lineWidth: 1)
              )
              .cornerRadius(8)
              .padding(1)
              .submitLabel(.send)
              .onSubmit {
                if (!state.userInput.isEmpty || !state.tempMediaItems.isEmpty) && !state.isLoading {
                  sendMessage()
                }
              }
              .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isInputTargeted) {
                providers, _ in
                for provider in providers {
                  if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                      guard let url = url else { return }

                      DispatchQueue.main.async {
                        handleDroppedMedia(from: url)
                      }
                    }
                    return true
                  }
                }
                return false
              }
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(isInputTargeted ? Color.blue : Color.clear, lineWidth: 2)
              )
          }

          Button(action: {
            sendMessage()
          }) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundColor(
                (state.userInput.isEmpty && state.tempMediaItems.isEmpty) || state.isLoading
                  ? .gray : .green
              )
              .font(.title2)
          }
          .disabled((state.userInput.isEmpty && state.tempMediaItems.isEmpty) || state.isLoading)
          .padding(8)
        }
        .padding([.horizontal, .bottom])
      }
    }
    #if canImport(UIKit)
      .sheet(isPresented: $showingCamera) {
        CameraView { image in
          if let imageData = image.jpegData(compressionQuality: 0.8) {
            let mediaItem = MediaItem(data: imageData, type: .image)
            state.tempMediaItems.append(mediaItem)
          }
        }
      }
    #endif

    .sheet(isPresented: $showingImagePicker) {
      #if canImport(UIKit)
        ImagePicker { image in
          if let imageData = image.jpegData(compressionQuality: 0.8) {
            let mediaItem = MediaItem(data: imageData, type: .image)
            state.tempMediaItems.append(mediaItem)
          }
        }
      #endif
    }

    .fileImporter(
      isPresented: $showingFileImporter,
      allowedContentTypes: [.item],
      allowsMultipleSelection: true
    ) { result in
      do {
        let urls = try result.get()
        for url in urls {
          #if canImport(UIKit)
            if url.startAccessingSecurityScopedResource() {
              handleDroppedMedia(from: url)
              url.stopAccessingSecurityScopedResource()
            }
          #else
            handleDroppedMedia(from: url)
          #endif
        }
      } catch {
        print("Error importing file: \(error)")
      }
    }
  }

  #if canImport(UIKit)
    private func loadTransferable(from item: PhotosPickerItem) {
      item.loadTransferable(type: Data.self) { result in
        switch result {
        case .success(let data):
          DispatchQueue.main.async {
            let mediaItem = MediaItem(data: data!, type: .image)
            state.tempMediaItems.append(mediaItem)
          }
        case .failure(let error):
          print("Error loading image: \(error)")
        }
      }
    }
  #endif

  private func handleDroppedMedia(from url: URL) {
    do {
      let data = try Data(contentsOf: url)

      let mediaType: MediaItem.MediaType
      if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
        || url.pathExtension.lowercased() == "png"
      {
        mediaType = .image
      } else {
        mediaType = .file(url.lastPathComponent)
      }

      let mediaItem = MediaItem(data: data, type: mediaType)

      state.tempMediaItems.append(mediaItem)
    } catch {
      print("Error handling dropped media: \(error)")
    }
  }

  private func removeMediaItem(_ item: MediaItem) {
    if let index = state.tempMediaItems.firstIndex(where: { $0.id == item.id }) {
      state.tempMediaItems.remove(at: index)
    }
  }

  private func sendMessage() {
    guard !state.userInput.isEmpty || !state.tempMediaItems.isEmpty else { return }

    // Add user message to chat
    let userMessage = ChatMessage(
      content: state.userInput,
      isUser: true,
      mediaItems: state.tempMediaItems.isEmpty ? nil : state.tempMediaItems
    )
    state.messages.append(userMessage)

    // Store the input and clear the field
    let input = state.userInput
    state.userInput = ""
    let mediaItems = state.tempMediaItems
    state.tempMediaItems = []

    // Set loading state
    state.isLoading = true
    state.errorMessage = nil

    // Call API
    Task {
      do {
        // Note: Media handling for API call would need to be implemented
        // Currently this just sends the text content
        let response = try await OpenRouterAPI.sendMessage(
          userMessage: input, model: state.selectedModel)

        await MainActor.run {
          state.messages.append(
            ChatMessage(
              content: response,
              isUser: false,
              model: state.selectedModel
            ))
          state.isLoading = false
        }
      } catch {
        await MainActor.run {
          state.errorMessage = "Error: \(error.localizedDescription)"
          state.isLoading = false
        }
      }
    }
  }
}

struct AssistantMessageView: View {
  var message: ChatMessage

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {

      Text(message.content)
        .padding(10)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)

      HStack {
        Button(action: {
          // Copy to clipboard functionality
          #if canImport(UIKit)
            UIPasteboard.general.string = message.content
          #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content, forType: .string)
          #endif
        }) {
          Image(systemName: "doc.on.doc")
            .font(.caption)
            .foregroundColor(.gray)
        }
        .buttonStyle(.plain)

      }
      .padding(.top, 4)
    }
  }
}

struct UserMessageView: View {
  var message: ChatMessage
  @EnvironmentObject private var state: AIAssistantState
  @State private var isTargeted = false

  init(message: ChatMessage) {
    self.message = message
  }

  var body: some View {
    VStack(alignment: .trailing, spacing: 4) {
      // Message section with chat bubble
      VStack(alignment: .trailing) {
        Text(message.content)
          .padding(10)

        // Display media if available
        if let mediaItems = message.mediaItems {
          ForEach(mediaItems) { item in
            if case .image = item.type {
              #if canImport(UIKit)
                if let uiImage = UIImage(data: item.data) {
                  Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                }
              #elseif canImport(AppKit)
                if let nsImage = NSImage(data: item.data) {
                  Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                }
              #endif
            } else if case .file(let name) = item.type {
              HStack {
                Image(systemName: "doc")
                Text(name)
              }
              .padding(6)
              .background(Color.gray.opacity(0.1))
              .cornerRadius(6)
            }
          }
        }
      }
      .padding(10)
      .background(Color.gray.opacity(0.1))
      .foregroundColor(.primary)
      .cornerRadius(10)
      .padding(.horizontal, 4)
      .onDrop(of: ["public.image", "public.file-url"], isTargeted: $isTargeted) { providers, _ in
        for provider in providers {
          if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
              guard let url = url else { return }

              DispatchQueue.main.async {
                handleDroppedMedia(from: url)
              }
            }
            return true
          }
        }
        return false
      }
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(isTargeted ? Color.blue : Color.clear, lineWidth: 2)
      )

      // Controls
      HStack {
        Menu {
          ForEach(state.availableModels, id: \.self) { model in
            Button(model) {
              state.selectedModel = model
            }
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.caption)
            .foregroundColor(.gray)
        }
        .buttonStyle(.plain)

        Image(systemName: "doc.on.doc")
          .font(.caption)
          .foregroundColor(.gray)
      }
      .padding(.top, 2)
    }
  }

  private func handleDroppedMedia(from url: URL) {
    // Find the index of this message
    if let index = state.messages.firstIndex(where: { $0.id == message.id }) {
      do {
        let data = try Data(contentsOf: url)
        var updatedMessage = state.messages[index]

        // Create a new media item
        let mediaType: MediaItem.MediaType
        if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
          || url.pathExtension.lowercased() == "png"
        {
          mediaType = .image
        } else {
          mediaType = .file(url.lastPathComponent)
        }

        let mediaItem = MediaItem(data: data, type: mediaType)

        // Add the media item to the message
        if updatedMessage.mediaItems == nil {
          updatedMessage.mediaItems = [mediaItem]
        } else {
          updatedMessage.mediaItems?.append(mediaItem)
        }

        // Update the message in the state
        state.messages[index] = updatedMessage
      } catch {
        print("Error handling dropped media: \(error)")
      }
    }
  }
}

#if canImport(UIKit)
  // Camera view for taking photos directly in the app
  struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
      let parent: CameraView

      init(parent: CameraView) {
        self.parent = parent
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        if let image = info[.originalImage] as? UIImage {
          parent.onImageCaptured(image)
        }
        picker.dismiss(animated: true)
      }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
      }
    }
  }

  // Image picker for selecting from photo library
  struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .photoLibrary
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
      let parent: ImagePicker

      init(parent: ImagePicker) {
        self.parent = parent
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        if let image = info[.originalImage] as? UIImage {
          parent.onImagePicked(image)
        }
        picker.dismiss(animated: true)
      }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
      }
    }
  }
#endif
