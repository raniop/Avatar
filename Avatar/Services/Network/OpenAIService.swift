import Foundation
import UIKit

struct OpenAIService {
    static let shared = OpenAIService()

    private let chatURL = "https://api.openai.com/v1/chat/completions"
    private let imageURL = "https://api.openai.com/v1/images/generations"

    private var apiKey: String {
        Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String ?? ""
    }

    struct PhotoAnalysisResult: Decodable {
        let skinTone: String
        let hairStyle: String
        let hairColor: String
        let eyeColor: String

        enum CodingKeys: String, CodingKey {
            case skinTone = "skinTone"
            case hairStyle = "hairStyle"
            case hairColor = "hairColor"
            case eyeColor = "eyeColor"
        }

        init(from decoder: Decoder) throws {
            if let container = try? decoder.container(keyedBy: CodingKeys.self),
               let st = try? container.decode(String.self, forKey: .skinTone) {
                skinTone = st
                hairStyle = try container.decode(String.self, forKey: .hairStyle)
                hairColor = try container.decode(String.self, forKey: .hairColor)
                eyeColor = try container.decode(String.self, forKey: .eyeColor)
            } else {
                enum SnakeKeys: String, CodingKey {
                    case skinTone = "skin_tone"
                    case hairStyle = "hair_style"
                    case hairColor = "hair_color"
                    case eyeColor = "eye_color"
                }
                let container = try decoder.container(keyedBy: SnakeKeys.self)
                skinTone = try container.decode(String.self, forKey: .skinTone)
                hairStyle = try container.decode(String.self, forKey: .hairStyle)
                hairColor = try container.decode(String.self, forKey: .hairColor)
                eyeColor = try container.decode(String.self, forKey: .eyeColor)
            }
        }
    }

    // MARK: - Analyze photo to extract features

    func analyzeChildPhoto(imageData: Data) async throws -> PhotoAnalysisResult {
        let compressedData = compressImage(data: imageData, maxDimension: 512, quality: 0.6)
        let base64Image = compressedData.base64EncodedString()

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": """
                            Analyze this child's photo and detect their physical appearance. \
                            Return ONLY a JSON object with these fields:
                            - "skinTone": hex color string (e.g. "FFDBB4") representing their skin tone
                            - "hairStyle": one of: "short", "medium", "long", "curly", "braids", "ponytail", "buzz", "afro"
                            - "hairColor": hex color string (e.g. "4A3728") representing their hair color
                            - "eyeColor": hex color string (e.g. "634E34") representing their eye color

                            Return ONLY the JSON, no markdown, no explanation.
                            """
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 150
        ]

        let data = try await postJSON(url: chatURL, body: requestBody)

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\"#", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw OpenAIError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(PhotoAnalysisResult.self, from: jsonData)
        } catch {
            throw OpenAIError.requestFailed("Parse error: \(cleaned)")
        }
    }

    // MARK: - Generate cartoon avatar from description

    func generateCartoonAvatar(prompt: String) async throws -> UIImage {
        let requestBody: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "b64_json"
        ]

        let data = try await postJSON(url: imageURL, body: requestBody, timeout: 60)

        let imageResponse = try JSONDecoder().decode(ImageGenerationResponse.self, from: data)
        guard let b64 = imageResponse.data.first?.b64Json,
              let imageData = Data(base64Encoded: b64),
              let image = UIImage(data: imageData) else {
            throw OpenAIError.noContent
        }

        return image
    }

    // MARK: - Analyze photo for cartoon generation

    private func analyzeForCartoon(imageData: Data) async throws -> [String: String] {
        let compressedData = compressImage(data: imageData, maxDimension: 512, quality: 0.7)
        let base64Image = compressedData.base64EncodedString()

        // Try models in order — gpt-4o-mini is less likely to refuse
        let models = ["gpt-4o-mini", "gpt-4o"]

        for model in models {
            do {
                let result = try await attemptAnalysis(model: model, base64Image: base64Image)
                return result
            } catch {
                print("OpenAI: \(model) failed: \(error.localizedDescription)")
                continue
            }
        }

        throw OpenAIError.requestFailed("All models refused to analyze the image")
    }

    private func attemptAnalysis(model: String, base64Image: String) async throws -> [String: String] {
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a character design tool for a children's educational app. \
                    Given a reference image, output a JSON object describing visual traits \
                    for generating a cartoon illustration. Focus only on artistic attributes: \
                    colors, shapes, and style. Always respond with valid JSON.
                    """
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": """
                            Describe the visual traits in this reference image accurately \
                            for creating a cartoon character. Be very precise about colors — \
                            distinguish between blonde, sandy blonde, light brown, dark brown, etc. \
                            Return JSON with these string fields: \
                            hairColor, hairStyle, eyeColor, skinTone, \
                            approximateAge, gender, facialFeatures. \
                            Example: {"hairColor":"blonde","hairStyle":"short textured", \
                            "eyeColor":"bright blue","skinTone":"fair","approximateAge":"6", \
                            "gender":"boy","facialFeatures":"round face, small nose"} \
                            Return ONLY JSON.
                            """
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 250
        ]

        let data = try await postJSON(url: chatURL, body: requestBody)

        // Log raw response for debugging
        let rawResponse = String(data: data, encoding: .utf8) ?? "nil"
        print("OpenAI [\(model)] raw response: \(rawResponse.prefix(500))")

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let message = chatResponse.choices.first?.message

        // Check for refusal
        if let refusal = message?.refusal {
            throw OpenAIError.requestFailed("Model refused: \(refusal)")
        }

        guard let content = message?.content, !content.isEmpty else {
            throw OpenAIError.noContent
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw OpenAIError.requestFailed("Parse error: \(cleaned)")
        }

        // Normalize all keys to camelCase and values to strings
        var result: [String: String] = [:]
        for (key, value) in raw {
            let normalizedKey = key.replacingOccurrences(of: "_", with: "")
                .lowercased()
            result[normalizedKey] = "\(value)"
        }
        return result
    }

    // MARK: - Full flow: photo → analyze → generate cartoon

    func createCartoonFromPhoto(imageData: Data) async throws -> UIImage {
        let desc = try await analyzeForCartoon(imageData: imageData)

        let age = desc["approximateage"] ?? "7"
        let gender = desc["gender"] ?? "child"
        let hairColor = desc["haircolor"] ?? "brown"
        let hairStyle = desc["hairstyle"] ?? "short"
        let eyeColor = desc["eyecolor"] ?? "brown"
        let skinTone = desc["skintone"] ?? "fair"
        let facialFeatures = desc["facialfeatures"] ?? "round face"

        let prompt = """
        A cute Pixar/Disney-style 3D cartoon avatar portrait of a \(age)-year-old \
        \(gender) with \(hairColor) \(hairStyle) hair, \(eyeColor) eyes, \
        \(skinTone) skin, and a \(facialFeatures). \
        Warm friendly smile, shown from chest up, looking at the viewer. \
        Soft pastel solid color background. \
        High quality children's book illustration, vibrant colors, adorable character design.
        """

        return try await generateCartoonAvatar(prompt: prompt)
    }

    // MARK: - Helpers

    private func postJSON(url: String, body: [String: Any], timeout: TimeInterval = 30) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.requestFailed("No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw OpenAIError.requestFailed("HTTP \(httpResponse.statusCode): \(responseBody)")
        }

        return data
    }

    private func compressImage(data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }

    private func colorName(_ hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Int((int >> 16) & 0xFF)
        let g = Int((int >> 8) & 0xFF)
        let b = Int(int & 0xFF)

        let brightness = (r + g + b) / 3
        let isWarm = r > b

        if brightness > 200 { return isWarm ? "light blonde" : "light" }
        if brightness > 150 { return isWarm ? "golden brown" : "light brown" }
        if brightness > 100 { return isWarm ? "brown" : "dark brown" }
        if brightness > 50 { return isWarm ? "dark brown" : "dark" }
        return "black"
    }
}

// MARK: - Response types

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
        let refusal: String?
    }
}

private struct ImageGenerationResponse: Decodable {
    let data: [ImageData]

    struct ImageData: Decodable {
        let b64Json: String?

        enum CodingKeys: String, CodingKey {
            case b64Json = "b64_json"
        }
    }
}

enum OpenAIError: LocalizedError {
    case requestFailed(String)
    case noContent
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .requestFailed(let detail): "API error: \(detail)"
        case .noContent: "No response from AI"
        case .invalidJSON: "Could not parse AI response"
        }
    }
}
