import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Avatar storage using Firebase (Firestore + Storage)
/// Stores avatars per-child so each child has their own avatar.
/// Also caches locally for fast loading.
final class AvatarStorage {
    static let shared = AvatarStorage()

    private let db = Firestore.firestore()
    private let storageRef = Storage.storage().reference()
    private let defaults = UserDefaults.standard
    private let cacheDirectory: URL

    private init() {
        cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    /// Per-child cache key
    private func localCacheKey(for childId: String) -> String {
        "cached_avatar_\(childId)"
    }

    // MARK: - Save (Firebase + local cache)

    func saveAvatar(name: String, image: UIImage, childId: String) async throws {
        guard let userId else {
            throw AvatarStorageError.notAuthenticated
        }

        // 1. Upload image to Firebase Storage
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw AvatarStorageError.imageConversionFailed
        }

        let imagePath = "avatars/\(userId)/\(childId)/avatar.jpg"
        let imageRef = storageRef.child(imagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageRef.downloadURL()

        // 2. Save metadata to Firestore
        let avatarData: [String: Any] = [
            "name": name,
            "imageURL": downloadURL.absoluteString,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(userId)
            .collection("avatar").document(childId)
            .setData(avatarData)

        // 3. Cache locally for fast loading
        cacheLocally(name: name, image: image, childId: childId)

        print("AvatarStorage: Saved avatar for child \(childId) to Firebase + local cache")
    }

    // MARK: - Load (local cache first, then Firebase)

    func loadAvatar(childId: String) async -> SavedAvatar? {
        // Try local cache first (instant)
        if let cached = loadFromLocalCache(childId: childId) {
            return cached
        }

        // No cache - load from Firebase
        return await loadFromFirebase(childId: childId)
    }

    func hasAvatar(childId: String) -> Bool {
        defaults.dictionary(forKey: localCacheKey(for: childId)) != nil
    }

    // MARK: - Delete

    func deleteAvatar(childId: String) async {
        guard let userId else { return }

        let imagePath = "avatars/\(userId)/\(childId)/avatar.jpg"
        try? await storageRef.child(imagePath).delete()

        try? await db.collection("users").document(userId)
            .collection("avatar").document(childId)
            .delete()

        clearLocalCache(childId: childId)
    }

    // MARK: - Firebase Loading

    private func loadFromFirebase(childId: String) async -> SavedAvatar? {
        guard let userId else { return nil }

        do {
            let doc = try await db.collection("users").document(userId)
                .collection("avatar").document(childId)
                .getDocument()

            guard let data = doc.data(),
                  let name = data["name"] as? String,
                  let imageURLString = data["imageURL"] as? String,
                  let imageURL = URL(string: imageURLString) else {
                return nil
            }

            // Download image
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: imageData) else { return nil }

            // Cache locally
            cacheLocally(name: name, image: image, childId: childId)

            return SavedAvatar(id: childId, name: name, image: image)
        } catch {
            print("AvatarStorage: Failed to load from Firebase for child \(childId): \(error)")
            return nil
        }
    }

    // MARK: - Local Cache

    private func cacheLocally(name: String, image: UIImage, childId: String) {
        let imageName = "avatar_cache_\(childId).jpg"
        let url = cacheDirectory.appendingPathComponent(imageName)

        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: url, options: .atomic)
        }

        defaults.set(["name": name, "imageName": imageName], forKey: localCacheKey(for: childId))
    }

    private func loadFromLocalCache(childId: String) -> SavedAvatar? {
        guard let data = defaults.dictionary(forKey: localCacheKey(for: childId)) as? [String: String],
              let name = data["name"],
              let imageName = data["imageName"] else {
            return nil
        }

        let url = cacheDirectory.appendingPathComponent(imageName)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }

        return SavedAvatar(id: childId, name: name, image: image)
    }

    private func clearLocalCache(childId: String) {
        if let data = defaults.dictionary(forKey: localCacheKey(for: childId)) as? [String: String],
           let imageName = data["imageName"] {
            let url = cacheDirectory.appendingPathComponent(imageName)
            try? FileManager.default.removeItem(at: url)
        }
        defaults.removeObject(forKey: localCacheKey(for: childId))
    }
}

// MARK: - Models

struct SavedAvatar {
    let id: String
    let name: String
    let image: UIImage
}

enum AvatarStorageError: LocalizedError {
    case notAuthenticated
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to save an avatar"
        case .imageConversionFailed: return "Failed to process avatar image"
        }
    }
}
