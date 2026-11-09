import Foundation

public struct APIError: Error, Sendable, Equatable {
  public var status: Int
  /// The server's `{ "error": code }`; the app maps codes to Copy. `transport` when the request never landed.
  public var code: String
  public var payload: [String: JSONValue]

  public static let transport = "transport"
  public var isTransport: Bool { code == Self.transport }
  public var isUnauthorized: Bool { status == 401 }
}

public enum JSONValue: Codable, Sendable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let b = try? c.decode(Bool.self) {
      self = .bool(b)
    } else if let n = try? c.decode(Double.self) {
      self = .number(n)
    } else {
      self = .string((try? c.decode(String.self)) ?? "")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .string(let s): try c.encode(s)
    case .number(let n): try c.encode(n)
    case .bool(let b): try c.encode(b)
    case .null: try c.encodeNil()
    }
  }

  public var number: Double? { if case .number(let n) = self { n } else { nil } }
}

/// Sends requests to the Worker (spec §11.1). One actor; every write carries an idempotency key.
public actor APIClient {
  public typealias TokenProvider = @Sendable () async -> String?

  let baseURL: URL
  let session: URLSession
  let token: TokenProvider
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  public init(baseURL: URL, session: URLSession = .shared, token: @escaping TokenProvider) {
    self.baseURL = baseURL
    self.session = session
    self.token = token
  }

  public static var configuredBaseURL: URL {
    let text = Bundle.main.object(forInfoDictionaryKey: "TollAPIBaseURL") as? String
    return text.flatMap(URL.init(string:)) ?? URL(string: "https://toll.alders.dev/v1")
      ?? URL(filePath: "/")
  }

  public func get<R: Decodable & Sendable>(_ path: String, query: [String: String] = [:])
    async throws -> R
  {
    try decode(
      try await send("GET", path, query: query, body: nil, contentType: nil, idempotencyKey: nil))
  }

  public func send<B: Encodable & Sendable, R: Decodable & Sendable>(
    _ method: String, _ path: String, json body: B, idempotencyKey: String = UUID.v7Key()
  ) async throws -> R {
    let data = try encoder.encode(body)
    return try decode(
      try await send(
        method, path, query: [:], body: data, contentType: "application/json",
        idempotencyKey: idempotencyKey))
  }

  public func sendNoContent<B: Encodable & Sendable>(
    _ method: String, _ path: String, json body: B?, idempotencyKey: String = UUID.v7Key()
  ) async throws {
    let data = try body.map { try encoder.encode($0) }
    _ = try await send(
      method, path, query: [:], body: data, contentType: data == nil ? nil : "application/json",
      idempotencyKey: idempotencyKey)
  }

  public func upload<R: Decodable & Sendable>(_ path: String, data: Data, contentType: String)
    async throws -> R
  {
    try decode(
      try await send(
        "PUT", path, query: [:], body: data, contentType: contentType, idempotencyKey: UUID.v7Key())
    )
  }

  func send(
    _ method: String, _ path: String, query: [String: String], body: Data?, contentType: String?,
    idempotencyKey: String?
  ) async throws -> Data {
    var components = URLComponents(
      url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
    if !query.isEmpty {
      components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    guard let url = components?.url else {
      throw APIError(status: 0, code: APIError.transport, payload: [:])
    }
    var request = URLRequest(url: url, timeoutInterval: 20)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
    if let idempotencyKey, method != "GET" {
      request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
    }
    if let token = await token() {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw APIError(status: 0, code: APIError.transport, payload: [:])
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      let payload = (try? decoder.decode([String: JSONValue].self, from: data)) ?? [:]
      let code = if case .string(let c)? = payload["error"] { c } else { "http_\(status)" }
      throw APIError(status: status, code: code, payload: payload)
    }
    return data
  }

  private func decode<R: Decodable>(_ data: Data) throws -> R {
    if R.self == Empty.self, let empty = Empty() as? R { return empty }
    return try decoder.decode(R.self, from: data)
  }
}

public struct Empty: Codable, Sendable {
  public init() {}
}

extension UUID {
  public static func v7Key() -> String { UUID.v7().lowercasedString }
}
