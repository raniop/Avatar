import SwiftUI
import PhotosUI

/// Two-step child creation flow:
/// Step 1 — Name + Avatar photo
/// Step 2 — Age, gender, interests, goals
struct NewChildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var appRouter

    var onChildCreated: (() -> Void)?

    @State private var step = 1

    // Step 1 state
    @State private var childName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var generatedAvatarImage: UIImage?
    @State private var isAnalyzingPhoto = false
    @State private var analysisError: String?

    // Step 2 state
    @State private var age = 4
    @State private var gender = "boy"
    @State private var selectedInterests: [String] = []
    @State private var selectedGoals: [String] = []

    // Saving
    @State private var isSaving = false

    private var L: AppLocale { appRouter.currentLocale }

    private let openAI = OpenAIService.shared
    private let storage = AvatarStorage.shared
    private let apiClient = APIClient.shared

    let availableInterests = [
        // Sports
        "Soccer", "Basketball", "Tennis", "Swimming", "Gymnastics",
        "Martial Arts", "Cycling", "Running", "Skateboarding",
        // Creative
        "Drawing", "Music", "Dancing", "Singing", "Photography",
        "Crafts", "Theater",
        // Science & Tech
        "Space", "Science", "Robots", "Video Games", "Coding",
        "Math Puzzles",
        // Nature & Animals
        "Animals", "Dinosaurs", "Nature", "Gardening", "Ocean Life",
        // Imagination & Play
        "Superheroes", "Princesses", "Cars", "Lego", "Building",
        "Cooking", "Reading", "Fairy Tales", "Pirates",
        // Social
        "Board Games", "Puzzles", "Magic Tricks"
    ]

    let availableGoals = [
        "Sharing", "Confidence", "Making Friends", "Emotional Expression",
        "Dealing with Anger", "Patience", "Kindness", "Independence",
        "Problem Solving", "Listening", "Being Brave", "Cooperation"
    ]

    /// Localized display name for interests
    private func localizedInterest(_ key: String) -> String {
        guard L == .hebrew else { return key }
        switch key {
        // Sports
        case "Soccer": return "כדורגל"
        case "Basketball": return "כדורסל"
        case "Tennis": return "טניס"
        case "Swimming": return "שחייה"
        case "Gymnastics": return "התעמלות"
        case "Martial Arts": return "אומנויות לחימה"
        case "Cycling": return "רכיבת אופניים"
        case "Running": return "ריצה"
        case "Skateboarding": return "סקייטבורד"
        // Creative
        case "Drawing": return "ציור"
        case "Music": return "מוזיקה"
        case "Dancing": return "ריקוד"
        case "Singing": return "שירה"
        case "Photography": return "צילום"
        case "Crafts": return "יצירה"
        case "Theater": return "תיאטרון"
        // Science & Tech
        case "Space": return "חלל"
        case "Science": return "מדע"
        case "Robots": return "רובוטים"
        case "Video Games": return "משחקי מחשב"
        case "Coding": return "תכנות"
        case "Math Puzzles": return "חידות מתמטיקה"
        // Nature & Animals
        case "Animals": return "חיות"
        case "Dinosaurs": return "דינוזאורים"
        case "Nature": return "טבע"
        case "Gardening": return "גינון"
        case "Ocean Life": return "חיי הים"
        // Imagination & Play
        case "Superheroes": return "גיבורי על"
        case "Princesses": return "נסיכות"
        case "Cars": return "מכוניות"
        case "Lego": return "לגו"
        case "Building": return "בנייה"
        case "Cooking": return "בישול"
        case "Reading": return "קריאה"
        case "Fairy Tales": return "אגדות"
        case "Pirates": return "פיראטים"
        // Social
        case "Board Games": return "משחקי קופסה"
        case "Puzzles": return "פאזלים"
        case "Magic Tricks": return "קסמים"
        default: return key
        }
    }

    /// Localized display name for goals
    private func localizedGoal(_ key: String) -> String {
        guard L == .hebrew else { return key }
        switch key {
        case "Sharing": return "שיתוף"
        case "Confidence": return "ביטחון עצמי"
        case "Making Friends": return "לבנות חברויות"
        case "Emotional Expression": return "ביטוי רגשי"
        case "Dealing with Anger": return "התמודדות עם כעס"
        case "Patience": return "סבלנות"
        case "Kindness": return "חסד ואדיבות"
        case "Independence": return "עצמאות"
        case "Problem Solving": return "פתרון בעיות"
        case "Listening": return "הקשבה"
        case "Being Brave": return "אומץ"
        case "Cooperation": return "שיתוף פעולה"
        default: return key
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.childGradient
                    .ignoresSafeArea()

                if step == 1 {
                    step1View
                        .transition(.move(edge: .leading))
                } else {
                    step2View
                        .transition(.move(edge: .trailing))
                }
            }
            .environment(\.layoutDirection, L.layoutDirection)
            .navigationTitle(L.createChildTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .allowsHitTesting(!isSaving && !isAnalyzingPhoto)
        }
    }

    // MARK: - Step 1: Name + Avatar

    private var step1View: some View {
        VStack(spacing: 0) {
            // Avatar circle — tapping opens photo picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let image = generatedAvatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))
                            .shadow(color: .black.opacity(0.2), radius: 10)

                        // Change badge
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(.black.opacity(0.45)))
                            }
                        }
                        .frame(width: 200, height: 200)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 200, height: 200)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 36))
                                    Text(L.tapToUploadPhoto)
                                        .font(AppTheme.Fonts.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundStyle(.white.opacity(0.6))
                            )
                    }

                    if isAnalyzingPhoto {
                        Circle()
                            .fill(.black.opacity(0.5))
                            .frame(width: 200, height: 200)
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text(L.creatingAvatar)
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .disabled(isAnalyzingPhoto)
            .padding(.top, AppTheme.Spacing.xl)
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        isAnalyzingPhoto = true
                        analysisError = nil
                        do {
                            let image = try await openAI.createCartoonFromPhoto(imageData: data)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                generatedAvatarImage = image
                            }
                        } catch {
                            analysisError = error.localizedDescription
                        }
                        isAnalyzingPhoto = false
                    }
                }
            }

            if let error = analysisError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, 4)
            }

            // Name field
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(L.childNameLabel)
                    .font(AppTheme.Fonts.bodyBold)
                    .foregroundStyle(.white)

                TextField(L.enterChildName, text: $childName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.lg)

            Spacer()

            // Next button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = 2
                }
            } label: {
                Text(L.next)
                    .font(AppTheme.Fonts.childBody)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? .white : .white.opacity(0.3))
                    .foregroundStyle(canProceed ? AppTheme.Colors.primary : .white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            }
            .disabled(!canProceed)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    private var canProceed: Bool {
        !childName.isEmpty && generatedAvatarImage != nil
    }

    // MARK: - Step 2: Age, Interests, Goals

    private var step2View: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Back to step 1
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = 1
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                            Text(L.goBack)
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.top, AppTheme.Spacing.sm)

                // Age
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(L.age)
                        .font(AppTheme.Fonts.bodyBold)
                        .foregroundStyle(.white)

                    HStack(spacing: 20) {
                        Button {
                            if age > 2 { age -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Text("\(age)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 80)

                        Button {
                            if age < 12 { age += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                // Gender
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(L.gender)
                        .font(AppTheme.Fonts.bodyBold)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        GenderButton(label: L.boy, value: "boy", selected: $gender)
                        GenderButton(label: L.girl, value: "girl", selected: $gender)
                        GenderButton(label: L.other, value: "other", selected: $gender)
                    }
                }

                // Interests
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(L.interests)
                        .font(AppTheme.Fonts.bodyBold)
                        .foregroundStyle(.white)

                    FlowLayout(spacing: 8) {
                        ForEach(availableInterests, id: \.self) { interest in
                            TagChip(
                                label: localizedInterest(interest),
                                isSelected: selectedInterests.contains(interest)
                            ) {
                                if selectedInterests.contains(interest) {
                                    selectedInterests.removeAll { $0 == interest }
                                } else {
                                    selectedInterests.append(interest)
                                }
                            }
                        }
                    }
                }

                // Goals
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(L.developmentGoals)
                        .font(AppTheme.Fonts.bodyBold)
                        .foregroundStyle(.white)

                    FlowLayout(spacing: 8) {
                        ForEach(availableGoals, id: \.self) { goal in
                            TagChip(
                                label: localizedGoal(goal),
                                isSelected: selectedGoals.contains(goal)
                            ) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.removeAll { $0 == goal }
                                } else {
                                    selectedGoals.append(goal)
                                }
                            }
                        }
                    }
                }

                // Save button
                Button {
                    Task { await saveChild() }
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(AppTheme.Colors.primary)
                        }
                        Text(isSaving ? L.saving : L.createChild)
                    }
                    .font(AppTheme.Fonts.childBody)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                }
                .disabled(isSaving)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    // MARK: - Save

    private func saveChild() async {
        isSaving = true
        do {
            // 1. Create child in backend
            let request = CreateChildRequest(
                name: childName,
                age: age,
                gender: gender,
                interests: selectedInterests,
                developmentGoals: selectedGoals,
                locale: L.rawValue
            )
            let child = try await apiClient.createChild(request)

            // 2. Save avatar for this child
            if let image = generatedAvatarImage {
                try await storage.saveAvatar(name: childName, image: image, childId: child.id)
            }

            // 3. Done — notify parent and dismiss
            onChildCreated?()
            dismiss()
        } catch {
            analysisError = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Helper Views

private struct GenderButton: View {
    let label: String
    let value: String
    @Binding var selected: String

    var body: some View {
        Button {
            selected = value
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(selected == value ? .white : .white.opacity(0.15))
                .foregroundStyle(selected == value ? AppTheme.Colors.primary : .white)
                .clipShape(Capsule())
        }
    }
}

private struct TagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.Fonts.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? .white : .white.opacity(0.15))
                .foregroundStyle(isSelected ? AppTheme.Colors.primary : .white)
                .clipShape(Capsule())
        }
    }
}
