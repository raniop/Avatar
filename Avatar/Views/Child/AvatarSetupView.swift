import SwiftUI

struct AvatarSetupView: View {
    let child: Child
    let locale: AppLocale
    let onComplete: () -> Void

    @State private var step = 1
    @State private var selectedPreset: Int? = nil
    @State private var avatarName = ""
    @State private var isSaving = false
    @State private var appearAnimation = false

    private let storage = AvatarStorage.shared

    // Each preset has an index and a name per locale
    private struct PresetCharacter: Identifiable {
        let id: Int
        let hebrewName: String
        let englishName: String

        func name(for locale: AppLocale) -> String {
            locale == .hebrew ? hebrewName : englishName
        }
    }

    /// Voice ID based on selected character: boy characters (1-4) get male voice, girl characters (5-8) get female voice
    private var selectedVoiceId: String {
        guard let preset = selectedPreset else { return "friendly_female" }
        return preset <= 4 ? "friendly_male" : "friendly_female"
    }

    private let boyCharacters: [PresetCharacter] = [
        PresetCharacter(id: 2, hebrewName: "נועם", englishName: "Noah"),
        PresetCharacter(id: 1, hebrewName: "אורי", englishName: "Ori"),
        PresetCharacter(id: 4, hebrewName: "ליאם", englishName: "Liam"),
        PresetCharacter(id: 3, hebrewName: "טל", englishName: "Tal"),
    ]

    private let girlCharacters: [PresetCharacter] = [
        PresetCharacter(id: 5, hebrewName: "נועה", englishName: "Noa"),
        PresetCharacter(id: 6, hebrewName: "מאיה", englishName: "Maya"),
        PresetCharacter(id: 7, hebrewName: "ליה", englishName: "Lily"),
        PresetCharacter(id: 8, hebrewName: "שירה", englishName: "Shira"),
    ]

    private var characters: [PresetCharacter] {
        let isBoy = child.gender == "boy" || child.gender == nil
        return isBoy ? boyCharacters + girlCharacters : girlCharacters + boyCharacters
    }

    var body: some View {
        ZStack {
            // Playful gradient background
            LinearGradient(
                colors: [
                    Color(hex: "74B9FF"),
                    Color(hex: "A29BFE"),
                    Color(hex: "FD79A8")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if step == 1 {
                characterSelectionStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                meetFriendStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .environment(\.layoutDirection, locale.layoutDirection)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Step 1: Choose Character

    private var characterSelectionStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(locale.chooseYourFriend(gender: child.gender))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    .padding(.top, 16)

                // 2x4 grid of avatars with names
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(characters) { character in
                        avatarCard(character: character)
                    }
                }
                .padding(.horizontal, 32)
                .opacity(appearAnimation ? 1 : 0)
                .scaleEffect(appearAnimation ? 1 : 0.9)

                // Next button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        step = 2
                    }
                } label: {
                    Text(locale.next)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(selectedPreset != nil
                                      ? Color(hex: "6C5CE7")
                                      : Color.white.opacity(0.3))
                        )
                }
                .disabled(selectedPreset == nil)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .padding(.top, 8)
            }
        }
    }

    private func avatarCard(character: PresetCharacter) -> some View {
        let isSelected = selectedPreset == character.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPreset = character.id
                // Auto-set the character's name
                avatarName = character.name(for: locale)
            }
        } label: {
            VStack(spacing: 6) {
                Image("avatar_preset_\(character.id)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? .white : .clear, lineWidth: 4)
                    )
                    .shadow(
                        color: isSelected ? .white.opacity(0.5) : .black.opacity(0.1),
                        radius: isSelected ? 12 : 4,
                        y: isSelected ? 0 : 2
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)

                Text(character.name(for: locale))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Step 2: Meet Your Friend

    @State private var meetAppeared = false
    @State private var glowPulse = false

    private var meetFriendStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text(locale.meetYourFriend(gender: child.gender))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .opacity(meetAppeared ? 1 : 0)
                .offset(y: meetAppeared ? 0 : 20)

            // Avatar with pulsing glow
            if let preset = selectedPreset {
                Image("avatar_preset_\(preset)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .white.opacity(glowPulse ? 0.6 : 0.2), radius: glowPulse ? 24 : 10, y: 0)
                    .scaleEffect(meetAppeared ? 1 : 0.7)
                    .opacity(meetAppeared ? 1 : 0)
            }

            // Speech bubble
            VStack(spacing: 0) {
                // Triangle pointer
                Triangle()
                    .fill(.white)
                    .frame(width: 20, height: 10)

                // Bubble content
                Text(locale.avatarIntro(
                    avatarName: avatarName,
                    childName: child.name,
                    gender: child.gender
                ))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "6C5CE7"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                )
            }
            .padding(.horizontal, 32)
            .opacity(meetAppeared ? 1 : 0)
            .offset(y: meetAppeared ? 0 : 20)

            // Subtitle
            Text(locale.newFriendReady(gender: child.gender))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .opacity(meetAppeared ? 1 : 0)

            Spacer()

            // Let's Go button
            Button {
                Task { await saveAndFinish() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(locale.letsGo)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(Color(hex: "6C5CE7"))
                )
            }
            .disabled(isSaving)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .opacity(meetAppeared ? 1 : 0)
            .offset(y: meetAppeared ? 0 : 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                meetAppeared = true
            }
            // Start pulsing glow
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Save

    private func saveAndFinish() async {
        guard let preset = selectedPreset,
              let image = UIImage(named: "avatar_preset_\(preset)"),
              !avatarName.isEmpty else { return }

        isSaving = true
        do {
            // Save avatar image + name locally and to Firebase
            try await storage.saveAvatar(name: avatarName, image: image, childId: child.id)
            // Also save avatar name + voice to backend so it appears in conversation greetings
            try? await APIClient.shared.setAvatarName(childId: child.id, name: avatarName, voiceId: selectedVoiceId)
            await MainActor.run {
                onComplete()
            }
        } catch {
            print("AvatarSetup: Failed to save: \(error)")
            isSaving = false
        }
    }
}

// MARK: - Speech Bubble Triangle

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
