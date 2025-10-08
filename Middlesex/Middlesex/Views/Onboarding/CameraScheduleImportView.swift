import SwiftUI
import PhotosUI
import AVFoundation

struct CameraScheduleImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var redWeekSchedule: [String: [BlockTime]]
    @Binding var whiteWeekSchedule: [String: [BlockTime]]

    @State private var redWeekImage: UIImage?
    @State private var whiteWeekImage: UIImage?
    @State private var isProcessing = false
    @State private var processingProgress = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingImagePicker = false
    @State private var currentWeekType: WeekType?

    enum WeekType {
        case red, white
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(MiddlesexTheme.primaryRed)
                            Text("Schedule Import")
                                .font(.title2)
                                .bold()
                        }

                        Text("Take photos of your Red week and White week schedules. Make sure the schedule is clearly visible and well-lit.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Red Week Photo
                    VStack(spacing: 12) {
                        HStack {
                            Text("Red Week Schedule")
                                .font(.headline)
                            Spacer()
                            if redWeekImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        if let image = redWeekImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        } else {
                            Button {
                                currentWeekType = .red
                                showingImagePicker = true
                            } label: {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.system(size: 48))
                                    Text("Take Photo")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                            }
                        }

                        if redWeekImage != nil {
                            Button(role: .destructive) {
                                redWeekImage = nil
                            } label: {
                                Text("Retake Photo")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)

                    // White Week Photo
                    VStack(spacing: 12) {
                        HStack {
                            Text("White Week Schedule")
                                .font(.headline)
                            Spacer()
                            if whiteWeekImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        if let image = whiteWeekImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        } else {
                            Button {
                                currentWeekType = .white
                                showingImagePicker = true
                            } label: {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.system(size: 48))
                                    Text("Take Photo")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                            }
                        }

                        if whiteWeekImage != nil {
                            Button(role: .destructive) {
                                whiteWeekImage = nil
                            } label: {
                                Text("Retake Photo")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)

                    // Processing Status
                    if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(processingProgress)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }

                    // Process Button
                    if redWeekImage != nil && whiteWeekImage != nil && !isProcessing {
                        Button {
                            Task {
                                await processSchedules()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Process Schedules with AI")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MiddlesexTheme.primaryRed)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: currentWeekType == .red ? $redWeekImage : $whiteWeekImage)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func processSchedules() async {
        isProcessing = true
        processingProgress = "Analyzing Red Week schedule..."

        do {
            // Process Red Week
            guard let redImage = redWeekImage,
                  let redImageData = redImage.jpegData(compressionQuality: 0.8) else {
                throw ScheduleProcessingError.imageConversionFailed
            }

            let redSchedule = try await OpenAIVisionAPI.shared.parseSchedule(
                imageData: redImageData,
                weekType: "Red"
            )

            processingProgress = "Analyzing White Week schedule..."

            // Process White Week
            guard let whiteImage = whiteWeekImage,
                  let whiteImageData = whiteImage.jpegData(compressionQuality: 0.8) else {
                throw ScheduleProcessingError.imageConversionFailed
            }

            let whiteSchedule = try await OpenAIVisionAPI.shared.parseSchedule(
                imageData: whiteImageData,
                weekType: "White"
            )

            processingProgress = "Finalizing schedules..."

            // Update the bindings
            await MainActor.run {
                self.redWeekSchedule = redSchedule
                self.whiteWeekSchedule = whiteSchedule
                isProcessing = false
                dismiss()
            }

        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

enum ScheduleProcessingError: LocalizedError {
    case imageConversionFailed
    case apiKeyNotFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process image. Please try taking the photo again."
        case .apiKeyNotFound:
            return "OpenAI API key not configured. Please contact your administrator."
        case .invalidResponse:
            return "Unable to parse schedule from image. Please ensure the schedule is clearly visible."
        }
    }
}

// Image Picker using UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
