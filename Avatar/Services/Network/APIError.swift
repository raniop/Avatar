import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed
    case unauthorized
    case serverError(Int)
    case decodingError
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .requestFailed:
            "Request failed"
        case .unauthorized:
            "Session expired. Please log in again."
        case .serverError(let code):
            "Server error (\(code))"
        case .decodingError:
            "Failed to process response"
        case .networkUnavailable:
            "No internet connection"
        }
    }
}
