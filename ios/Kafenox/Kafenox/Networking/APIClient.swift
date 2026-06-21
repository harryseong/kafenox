import Foundation

enum APIError: Error, LocalizedError {
    case server(statusCode: Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .server(let statusCode):
            return "Server returned status \(statusCode)"
        case .decoding(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

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
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(statusCode: statusCode)
        }
        return data
    }

    func listCoffees() async throws -> [Coffee] {
        struct Response: Decodable { let coffees: [Coffee] }
        let data = try await request("coffees")
        do {
            return try decoder.decode(Response.self, from: data).coffees
        } catch {
            throw APIError.decoding(error)
        }
    }

    func getCoffee(photoId: String) async throws -> Coffee {
        let data = try await request("coffees/\(photoId)")
        do {
            return try decoder.decode(Coffee.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    struct UploadInit: Decodable {
        let photoId: String
        let uploadUrl: URL
    }

    func initiateUpload() async throws -> UploadInit {
        let data = try await request("uploads", method: "POST")
        do {
            return try decoder.decode(UploadInit.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func uploadPhoto(_ imageData: Data, to uploadUrl: URL) async throws {
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: request, from: imageData)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(statusCode: statusCode)
        }
    }

    struct UploadStatus: Decodable {
        let photoId: String
        let status: String
        let errorMessage: String?
    }

    func getUploadStatus(photoId: String) async throws -> UploadStatus {
        let data = try await request("uploads/\(photoId)/status")
        do {
            return try decoder.decode(UploadStatus.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func updateCoffee(photoId: String, fields: [String: Any]) async throws -> Coffee {
        let body = try JSONSerialization.data(withJSONObject: fields)
        let data = try await request("coffees/\(photoId)", method: "PATCH", body: body)
        do {
            return try decoder.decode(Coffee.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func deleteCoffee(photoId: String) async throws {
        _ = try await request("coffees/\(photoId)", method: "DELETE")
    }
}
