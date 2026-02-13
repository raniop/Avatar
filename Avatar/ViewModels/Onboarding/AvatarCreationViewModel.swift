import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class AvatarCreationViewModel {
    var avatarName = ""
    var selectedSkinTone = "FFDBB4"
    var selectedHairStyle: HairStyle = .short
    var selectedHairColor = "4A3728"
    var selectedEyeColor = "634E34"
    var selectedOutfit: OutfitType = .tshirt
    var selectedAccessories: [AccessoryType] = []
    var isCreating = false
    var isAnalyzingPhoto = false
    var analysisError: String?
    var generatedAvatarImage: UIImage?

    let skinToneOptions = [
        "FFDBB4", "F1C27D", "E0AC69", "C68642", "8D5524", "6B3E26"
    ]

    let hairColorOptions = [
        "4A3728", "2C1810", "B55239", "D4A76A", "E8D5B7", "1A1A1A"
    ]

    let eyeColorOptions = [
        "634E34", "3B7DD8", "6B8E23", "8B4513", "2F4F4F", "1C1C1C"
    ]

    private let openAI = OpenAIService.shared
    private let storage = AvatarStorage.shared

    var hasGeneratedAvatar: Bool {
        generatedAvatarImage != nil
    }

    func generateAvatarFromPhoto(imageData: Data) async {
        isAnalyzingPhoto = true
        analysisError = nil

        do {
            let image = try await openAI.createCartoonFromPhoto(imageData: imageData)
            withAnimation(.easeInOut(duration: 0.3)) {
                generatedAvatarImage = image
            }
        } catch {
            analysisError = error.localizedDescription
        }

        isAnalyzingPhoto = false
    }

    func createAvatar() async -> Bool {
        isCreating = true
        defer { isCreating = false }

        guard let image = generatedAvatarImage else { return false }

        do {
            // Save to Firebase Storage + Firestore (+ local cache)
            try await storage.saveAvatar(name: avatarName, image: image)
            return true
        } catch {
            analysisError = error.localizedDescription
            return false
        }
    }
}
