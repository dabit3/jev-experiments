import Foundation

/// Thin HTTP client for the TypeSafe System One endpoint. Every call is one fan-out request.
struct JevClient: Sendable {
  struct Result: Sendable {
    let response: JevResponse
    let latencyMs: Double
  }

  enum Failure: Error, Equatable {
    case missingAPIKey
    case http(Int)
    case rateLimited(TimeInterval)
    case transport(String)
  }

  static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
  static let apiKeyDefaultsKey = "typesafeAPIKey"
  static let requestTimeout: TimeInterval = 4

  /// `TYPESAFE_API_KEY` from the environment first, then the Settings field (UserDefaults).
  static func apiKey(environment: [String: String] = ProcessInfo.processInfo.environment)
    -> String?
  {
    if let key = environment["TYPESAFE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
      !key.isEmpty
    {
      return key
    }
    if let key = UserDefaults.standard.string(forKey: apiKeyDefaultsKey)?.trimmingCharacters(
      in: .whitespacesAndNewlines), !key.isEmpty
    {
      return key
    }
    return nil
  }

  let session: URLSession

  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = Self.requestTimeout
    configuration.httpMaximumConnectionsPerHost = 8
    configuration.httpShouldUsePipelining = true
    session = URLSession(configuration: configuration)
  }

  func ask(_ request: JevRequest) async throws -> Result {
    guard let key = Self.apiKey() else { throw Failure.missingAPIKey }
    var urlRequest = URLRequest(url: Self.endpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    let started = DispatchTime.now()
    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await session.data(for: urlRequest)
    } catch {
      if Task.isCancelled { throw CancellationError() }
      throw Failure.transport(error.localizedDescription)
    }
    let latencyMs = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1e6
    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
      if http.statusCode == 429 || http.statusCode == 529 {
        throw Failure.rateLimited(Self.retryDelay(http.value(forHTTPHeaderField: "Retry-After")))
      }
      throw Failure.http(http.statusCode)
    }
    let decoded = try JSONDecoder().decode(JevResponse.self, from: data)
    return Result(response: decoded, latencyMs: latencyMs)
  }

  static func retryDelay(_ value: String?, now: Date = Date()) -> TimeInterval {
    guard let value else { return 15 }
    if let seconds = Double(value), seconds.isFinite { return max(1, seconds) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    guard let date = formatter.date(from: value) else { return 15 }
    return max(1, date.timeIntervalSince(now))
  }
}
