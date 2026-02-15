import SwiftUI
import PhotosUI

/// Four-step child creation flow:
/// Step 1 — Upload photo (starts avatar generation in background)
/// Step 2 — Child's name
/// Step 3 — Age, gender, interests, goals
/// Step 4 — Summary with avatar reveal
struct NewChildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var appRouter

    var onChildCreated: (() -> Void)?

    @State private var currentStep = 1

    // Step 1 state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    // Background avatar generation
    @State private var avatarTask: Task<UIImage?, Never>?
    @State private var generatedAvatarImage: UIImage?
    @State private var isGeneratingAvatar = false
    @State private var avatarError: String?

    // Step 2 state
    @State private var childName = ""

    // Step 3 state
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
        case "Soccer": return "כדורגל"
        case "Basketball": return "כדורסל"
        case "Tennis": return "טניס"
        case "Swimming": return "שחייה"
        case "Gymnastics": return "התעמלות"
        case "Martial Arts": return "אומנויות לחימה"
        case "Cycling": return "רכיבת אופניים"
        case "Running": return "ריצה"
        case "Skateboarding": return "סקייטבורד"
        case "Drawing": return "ציור"
        case "Music": return "מוזיקה"
        case "Dancing": return "ריקוד"
        case "Singing": return "שירה"
        case "Photography": return "צילום"
        case "Crafts": return "יצירה"
        case "Theater": return "תיאטרון"
        case "Space": return "חלל"
        case "Science": return "מדע"
        case "Robots": return "רובוטים"
        case "Video Games": return "משחקי מחשב"
        case "Coding": return "תכנות"
        case "Math Puzzles": return "חידות מתמטיקה"
        case "Animals": return "חיות"
        case "Dinosaurs": return "דינוזאורים"
        case "Nature": return "טבע"
        case "Gardening": return "גינון"
        case "Ocean Life": return "חיי הים"
        case "Superheroes": return "גיבורי על"
        case "Princesses": return "נסיכות"
        case "Cars": return "מכוניות"
        case "Lego": return "לגו"
        case "Building": return "בנייה"
        case "Cooking": return "בישול"
        case "Reading": return "קריאה"
        case "Fairy Tales": return "אגדות"
        case "Pirates": return "פיראטים"
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.childGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator + background avatar progress
                    stepIndicator
                        .padding(.top, AppTheme.Spacing.md)

                    // Step content
                    ZStack {
                        if currentStep == 1 {
                            step1PhotoView
                                .transition(.asymmetric(
                                    insertion: .move(edge: L == .hebrew ? .leading : .trailing),
                                    removal: .move(edge: L == .hebrew ? .trailing : .leading)
                                ))
                        } else if currentStep == 2 {
                            step2NameView
                                .transition(.asymmetric(
                                    insertion: .move(edge: L == .hebrew ? .leading : .trailing),
                                    removal: .move(edge: L == .hebrew ? .trailing : .leading)
                                ))
                        } else if currentStep == 3 {
                            step3InterestsView
                                .transition(.asymmetric(
                                    insertion: .move(edge: L == .hebrew ? .leading : .trailing),
                                    removal: .move(edge: L == .hebrew ? .trailing : .leading)
                                ))
                        } else {
                            step4SummaryView
                                .transition(.asymmetric(
                                    insertion: .move(edge: L == .hebrew ? .leading : .trailing),
                                    removal: .move(edge: L == .hebrew ? .trailing : .leading)
                                ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.35), value: currentStep)
                }
            }
            .environment(\.layoutDirection, L.layoutDirection)
            .navigationTitle(L.createChildTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if currentStep > 1 {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                currentStep -= 1
                            }
                        } else {
                            avatarTask?.cancel()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                            Text(L.goBack)
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .allowsHitTesting(!isSaving)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        VStack(spacing: 8) {
            // Dots
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? .white : .white.opacity(0.3))
                        .frame(width: step == currentStep ? 10 : 8,
                               height: step == currentStep ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }

            // Background avatar generation indicator
            if isGeneratingAvatar {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                        .scaleEffect(0.7)
                    Text(L.creatingAvatar)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isGeneratingAvatar)
    }

    // MARK: - Step 1: Upload Photo

    private var step1PhotoView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Title
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(L.uploadChildPhoto)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(L.uploadChildPhotoSubtitle)
                    .font(AppTheme.Fonts.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
                .frame(height: 20)

            // Photo picker circle
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 44))
                                Text(L.tapToUploadPhoto)
                                    .font(AppTheme.Fonts.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        )

                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 200, height: 200)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedPhotoData = data
                        startAvatarGeneration(imageData: data)
                        // Auto-advance to step 2
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentStep = 2
                        }
                    }
                }
            }

            if let error = avatarError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    // MARK: - Step 2: Name

    private var step2NameView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Title
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(L.whatsTheirName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(L.whatsTheirNameSubtitle)
                    .font(AppTheme.Fonts.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
                .frame(height: 30)

            // Name field — big and centered
            TextField(L.enterChildName, text: $childName)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding()
                .padding(.horizontal, AppTheme.Spacing.md)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()

            // Next button
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentStep = 3
                }
            } label: {
                Text(L.next)
                    .font(AppTheme.Fonts.childBody)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(!childName.isEmpty ? .white : .white.opacity(0.3))
                    .foregroundStyle(!childName.isEmpty ? AppTheme.Colors.primary : .white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            }
            .disabled(childName.isEmpty)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Step 3: Age, Gender, Interests, Goals

    private var step3InterestsView: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Title
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(L.whatDoTheyLove)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(L.whatDoTheyLoveSubtitle)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.md)

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

                // Next button
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = 4
                    }
                } label: {
                    Text(L.next)
                        .font(AppTheme.Fonts.childBody)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                }
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    // MARK: - Step 4: Summary

    private var step4SummaryView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            if let image = generatedAvatarImage {
                // Avatar reveal
                VStack(spacing: AppTheme.Spacing.md) {
                    Text(L.meetAvatar)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 220, height: 220)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
                        .transition(.scale.combined(with: .opacity))

                    if !childName.isEmpty {
                        Text(childName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // Selected interests as tags
                    if !selectedInterests.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(selectedInterests.prefix(8), id: \.self) { interest in
                                Text(localizedInterest(interest))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.2))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: generatedAvatarImage != nil)
            } else {
                // Still generating — show spinner
                VStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2.0)

                    Text(L.almostReady)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(L.creatingAvatar)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if let error = avatarError {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)

                    // Retry button
                    Button {
                        if let data = selectedPhotoData {
                            avatarError = nil
                            startAvatarGeneration(imageData: data)
                        }
                    } label: {
                        Text("Retry")
                            .font(AppTheme.Fonts.bodyBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Let's go! button (only when avatar is ready)
            Button {
                Task { await saveChild() }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(AppTheme.Colors.primary)
                    }
                    Text(isSaving ? L.saving : L.letsGoButton)
                }
                .font(AppTheme.Fonts.childBody)
                .frame(maxWidth: .infinity)
                .padding()
                .background(generatedAvatarImage != nil ? .white : .white.opacity(0.3))
                .foregroundStyle(generatedAvatarImage != nil ? AppTheme.Colors.primary : .white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            }
            .disabled(generatedAvatarImage == nil || isSaving)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Avatar Generation (Background)

    private func startAvatarGeneration(imageData: Data) {
        avatarTask?.cancel()
        isGeneratingAvatar = true
        avatarError = nil

        avatarTask = Task {
            do {
                let image = try await openAI.createCartoonFromPhoto(imageData: imageData)
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            generatedAvatarImage = image
                        }
                        isGeneratingAvatar = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        avatarError = error.localizedDescription
                        isGeneratingAvatar = false
                    }
                }
            }
            return nil
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

            // 3. Refresh children list BEFORE dismissing so RoleSelectionView updates instantly
            await appRouter.prefetchChildren(force: true)

            // 4. Done — notify parent and dismiss
            onChildCreated?()
            dismiss()
        } catch {
            avatarError = error.localizedDescription
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
