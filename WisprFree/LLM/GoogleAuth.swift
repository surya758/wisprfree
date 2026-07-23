import Foundation

/// Mints Vertex AI access tokens from the gcloud Application Default
/// Credentials file (`gcloud auth application-default login`), so the app
/// needs no API key and no gcloud binary at runtime.
actor GoogleAuth {
    static let shared = GoogleAuth()

    private struct ADCFile: Decodable {
        let client_id: String
        let client_secret: String
        let refresh_token: String
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
    }

    private var cachedToken: String?
    private var expiry: Date = .distantPast

    func accessToken() async throws -> String {
        if let token = cachedToken, expiry > Date().addingTimeInterval(60) {
            return token
        }

        let adcPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gcloud/application_default_credentials.json")
        guard let adcData = try? Data(contentsOf: adcPath),
              let adc = try? JSONDecoder().decode(ADCFile.self, from: adcData) else {
            throw WisprError.auth("No gcloud credentials found. Run: gcloud auth application-default login")
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            .init(name: "grant_type", value: "refresh_token"),
            .init(name: "client_id", value: adc.client_id),
            .init(name: "client_secret", value: adc.client_secret),
            .init(name: "refresh_token", value: adc.refresh_token),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw WisprError.auth("Token refresh failed (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(body)")
        }

        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        cachedToken = token.access_token
        expiry = Date().addingTimeInterval(TimeInterval(token.expires_in))
        return token.access_token
    }
}
