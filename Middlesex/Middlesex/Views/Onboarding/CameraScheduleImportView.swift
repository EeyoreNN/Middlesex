//
//  CameraScheduleImportView.swift
//  Middlesex
//
//  AI-powered schedule import with teacher selection
//

import SwiftUI
import PhotosUI
import AVFoundation

struct CameraScheduleImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preferences = UserPreferences.shared
    @Binding var redWeekSchedule: [String: [BlockTime]]
    @Binding var whiteWeekSchedule: [String: [BlockTime]]

    // Step tracking
    enum ImportStep {
        case captureImages
        case selectTeachers
        case configureXBlocks
    }

    @State private var currentStep: ImportStep = .captureImages

    // Image capture state
    @State private var redWeekImage: UIImage?
    @State private var whiteWeekImage: UIImage?
    @State private var showingImagePicker = false
    @State private var currentWeekType: WeekType?

    // AI parsing state
    @State private var isProcessing = false
    @State private var processingProgress = ""
    @State private var redWeekResult: ParsedScheduleResult?
    @State private var whiteWeekResult: ParsedScheduleResult?

    // Teacher/room selection
    @State private var selectedClasses: [String: SchoolClass] = [:] // Block -> SchoolClass
    @State private var selectedTeachers: [String: Teacher] = [:]  // Block -> Teacher
    @State private var selectedRooms: [String: String] = [:]  // Block -> Room

    // X block configuration
    @State private var xBlockDaysRed: [String: [String]] = [:]
    @State private var xBlockDaysWhite: [String: [String]] = [:]

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    enum WeekType {
        case red, white
    }

    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case .captureImages:
                    imageCaptureView
                case .selectTeachers:
                    TeacherRoomSelectionView(
                        selectedClasses: selectedClasses,
                        selectedTeachers: $selectedTeachers,
                        selectedRooms: $selectedRooms,
                        onComplete: {
                            currentStep = .configureXBlocks
                        }
                    )
                case .configureXBlocks:
                    XBlockConfigurationView(
                        selectedClasses: selectedClasses,
                        selectedTeachers: selectedTeachers,
                        xBlockDaysRed: $xBlockDaysRed,
                        xBlockDaysWhite: $xBlockDaysWhite,
                        onComplete: {
                            saveSchedule()
                            dismiss()
                        }
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var navigationTitle: String {
        switch currentStep {
        case .captureImages:
            return "Import Schedule"
        case .selectTeachers:
            return "Select Teachers"
        case .configureXBlocks:
            return "Configure X Blocks"
        }
    }

    private var imageCaptureView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                        Text("AI Schedule Import")
                            .font(.title2)
                            .bold()
                    }

                    Text("Take photos of your Red and White week schedules. AI will extract your classes, rooms, and X block schedule automatically!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Red Week Photo
                weekPhotoCard(
                    title: "Red Week Schedule",
                    image: $redWeekImage,
                    weekType: .red
                )

                // White Week Photo
                weekPhotoCard(
                    title: "White Week Schedule",
                    image: $whiteWeekImage,
                    weekType: .white
                )

                // Processing Status
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(processingProgress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
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
                            Text("Process with AI")
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
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: currentWeekType == .red ? $redWeekImage : $whiteWeekImage)
        }
    }

    private func weekPhotoCard(title: String, image: Binding<UIImage?>, weekType: WeekType) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if image.wrappedValue != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if let img = image.wrappedValue {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)

                Button(role: .destructive) {
                    image.wrappedValue = nil
                } label: {
                    Text("Retake Photo")
                        .font(.subheadline)
                }
            } else {
                Button {
                    currentWeekType = weekType
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
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

            redWeekResult = try await OpenAIVisionAPI.shared.parseSchedule(
                imageData: redImageData,
                weekType: "Red"
            )

            processingProgress = "Analyzing White Week schedule..."

            // Process White Week
            guard let whiteImage = whiteWeekImage,
                  let whiteImageData = whiteImage.jpegData(compressionQuality: 0.8) else {
                throw ScheduleProcessingError.imageConversionFailed
            }

            whiteWeekResult = try await OpenAIVisionAPI.shared.parseSchedule(
                imageData: whiteImageData,
                weekType: "White"
            )

            processingProgress = "Preparing class selection..."

            // Convert AI results to SchoolClass objects
            await MainActor.run {
                prepareClassSelection()
                isProcessing = false
                currentStep = .selectTeachers
            }

        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func prepareClassSelection() {
        guard let redResult = redWeekResult else { return }

        // Convert parsed blocks to SchoolClass objects
        for (blockLetter, blockInfo) in redResult.blocks {
            // Try to find matching SchoolClass from ClassList
            if let schoolClass = ClassList.availableClasses.first(where: { $0.name == blockInfo.className }) {
                selectedClasses[blockLetter] = schoolClass
            } else {
                // Create a temporary SchoolClass for classes not in our list
                selectedClasses[blockLetter] = SchoolClass(
                    name: blockInfo.className,
                    department: .other
                )
            }

            // Pre-fill room from AI
            selectedRooms[blockLetter] = blockInfo.room

            // Pre-fill X block days from AI
            xBlockDaysRed[blockLetter] = blockInfo.xBlockDays
        }

        // Get White week X block days
        if let whiteResult = whiteWeekResult {
            for (blockLetter, blockInfo) in whiteResult.blocks {
                xBlockDaysWhite[blockLetter] = blockInfo.xBlockDays
            }
        }
    }

    private func saveSchedule() {
        let blocks = ["A", "B", "C", "D", "E", "F", "G"]

        for (block, schoolClass) in selectedClasses {
            guard let teacher = selectedTeachers[block],
                  let room = selectedRooms[block] else { continue }

            let userClass = UserClass(
                className: schoolClass.name,
                teacher: teacher.name,
                room: room,
                color: "#C8102E",
                xBlockDaysRed: xBlockDaysRed[block],
                xBlockDaysWhite: xBlockDaysWhite[block]
            )

            // Map block letters to period numbers (A=1, B=2, etc.)
            if let blockIndex = blocks.firstIndex(of: block) {
                preferences.setClass(userClass, for: blockIndex + 1, weekType: .red)
                // Also save for white week with same data
                preferences.setClass(userClass, for: blockIndex + 1, weekType: .white)
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

#Preview {
    CameraScheduleImportView(
        redWeekSchedule: .constant([:]),
        whiteWeekSchedule: .constant([:])
    )
}
