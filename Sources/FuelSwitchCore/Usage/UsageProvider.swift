import Foundation

public enum UsageError: Error, Equatable {
    case rateLimited
    case unauthorized
    case unavailableQuota
    /// An Anthropic account can be a subscription and an API Console
    /// organisation at the same time. A token bound to the latter is entirely
    /// valid — the profile endpoint answers normally — but the usage endpoint
    /// refuses it permanently.
    case organizationNotAllowed
    case http(Int)
}

public protocol UsageProvider: Sendable {
    func fetch(account: Account) async throws -> AccountUsage
}

extension UsageProvider {
    /// Shared mapping from status code to domain error.
    public func checkStatus(_ response: URLResponse, body: Data = Data()) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 429: throw UsageError.rateLimited
        case 403 where OrganizationRefusal.matches(body): throw UsageError.organizationNotAllowed
        case 401, 403: throw UsageError.unauthorized
        default: throw UsageError.http(http.statusCode)
        }
    }
}

/// Recognises the error code where signing the same account in again
/// wastes the user's time.
enum OrganizationRefusal {
    static let code = "oauth_not_allowed_for_organization"

    private struct Response: Decodable {
        struct ErrorBody: Decodable {
            struct Details: Decodable { let errorCode: String? }
            let details: Details?
        }
        let error: ErrorBody?
    }

    static func matches(_ body: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(Response.self, from: body) else { return false }
        return response.error?.details?.errorCode == code
    }
}
