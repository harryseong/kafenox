import Foundation
import KafenoxCore
import OSLog

public enum APIError: Error, LocalizedError {
    case server(statusCode: Int)
    case decoding(Error)

    /// User-facing copy. Raw NSErrors and decoding errors never reach a
    /// person; callers surface `errorDescription` and log the underlying
    /// value separately.
    public var errorDescription: String? {
        switch self {
        case .server(let statusCode) where statusCode == 401 || statusCode == 403:
            return "Couldn't authenticate with the server."
        case .server(let statusCode) where (500...599).contains(statusCode):
            return "The server had a problem. Try again in a moment."
        case .server:
            return "The server rejected that request."
        case .decoding:
            return "Couldn't read the server's response."
        }
    }

    /// Detail for logs only -- not shown to users.
    public var diagnosticDescription: String {
        switch self {
        case .server(let statusCode): return "HTTP \(statusCode)"
        case .decoding(let error): return "decoding: \(error)"
        }
    }
}

public actor APIClient: CoffeeRepository {
    public static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    public init() {}

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(APIConfig.apiKey, forHTTPHeaderField: "x-api-key")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.networking.error(
                "\(method, privacy: .public) \(path, privacy: .public) failed: HTTP \(statusCode, privacy: .public)")
            throw APIError.server(statusCode: statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Logger.networking.error("Decoding \(String(describing: type), privacy: .public) failed: \(error)")
            throw APIError.decoding(error)
        }
    }

    public func listCoffees() async throws -> [Coffee] {
        struct Response: Decodable { let coffees: [Coffee] }
        return try decode(Response.self, from: await request("coffees")).coffees
    }

    public func coffee(photoId: String) async throws -> Coffee {
        try decode(Coffee.self, from: await request("coffees/\(photoId)"))
    }

    /// `models` carries the Settings-selected Bedrock model per feature
    /// (e.g. ["scan": "haiku", "notes": "haiku"]); the backend stores it on
    /// the item so the async extraction pipeline honors it.
    public func initiateUpload(models: [String: String]) async throws -> UploadTicket {
        var body: Data?
        if !models.isEmpty {
            body = try JSONSerialization.data(withJSONObject: ["models": models])
        }
        return try decode(UploadTicket.self, from: await request("uploads", method: "POST", body: body))
    }

    public func uploadPhoto(_ imageData: Data, to uploadUrl: URL) async throws {
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: request, from: imageData)
        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.networking.error("S3 upload failed: HTTP \(statusCode, privacy: .public)")
            throw APIError.server(statusCode: statusCode)
        }
    }

    public func uploadStatus(photoId: String) async throws -> UploadStatus {
        try decode(UploadStatus.self, from: await request("uploads/\(photoId)/status"))
    }

    public func updateCoffee(photoId: String, _ update: CoffeeUpdate) async throws -> Coffee {
        let body = try JSONSerialization.data(withJSONObject: update.payload)
        return try decode(Coffee.self, from: await request("coffees/\(photoId)", method: "PATCH", body: body))
    }

    /// "Looks good" -- confirms an extracted coffee as-is, without edits.
    /// The backend treats `verified` as a flag, not an editable field.
    public func verifyCoffee(photoId: String) async throws -> Coffee {
        try await updateCoffee(photoId: photoId, CoffeeUpdate(verified: true))
    }

    public func deleteCoffee(photoId: String) async throws {
        _ = try await request("coffees/\(photoId)", method: "DELETE")
    }

    /// POST /insights/ask -- Claude-backed Q&A over the user's collection.
    public func askInsights(question: String, history: [ChatTurn], model: String?) async throws -> String {
        struct Response: Decodable { let answer: String }
        var payload: [String: Any] = [
            "question": question,
            "history": history.map { ["role": $0.role, "text": $0.text] },
        ]
        if let model {
            payload["model"] = model
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try decode(Response.self, from: await request("insights/ask", method: "POST", body: body)).answer
    }
}
