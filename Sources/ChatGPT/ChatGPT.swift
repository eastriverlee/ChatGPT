import Foundation

extension URLResponse {
    var http: HTTPURLResponse? {
        self as? HTTPURLResponse
    }
}

struct HTTPMethod {
    static let post = "POST"
}

let jsonEncoder = JSONEncoder()
let jsonDecoder = JSONDecoder()

public struct ChatGPT {
    public var apiKey: String
    public var baseURL: String
    public var path: String
    public var headers: [String: String]
    
    public init(
        baseURL: String = "https://api.openai.com",
        path: String = "/v1/chat/completions",
        apiKey: String = "",
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.path = path
        self.apiKey = apiKey
        self.headers = headers
    }

    public enum Model: Hashable, CustomStringConvertible {
        case gpt_3_5_turbo
        case gpt_4
        case custom(name: String)
        public var description: String {
            switch self {
            case .gpt_3_5_turbo:
                return "gpt-3.5-turbo"
            case .gpt_4:
                return "gpt-4"
            case .custom(let name):
                return name
            }
        }
    }
        
    private func prepareRequest(from history: [Message], with option: Option, stream: Bool) -> URLRequest {
        let body = Conversation(history, with: option, stream: stream)
        let address = baseURL + path
        guard let url = URL(string: address) else { fatalError("invalid URL: \(address)") }
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        for header in headers { request.setValue(header.value, forHTTPHeaderField: header.key) }
        request.httpBody = try! jsonEncoder.encode(body)
        return request
    }
    
    public struct Option {
        public var topProbabilityMass: Double? = 0
        public var frequencyPenalty: Double? = 0
        public var presencePenalty: Double? = 0
        public var temperature: Double? = 1
        public var user: String? = nil
        public var stop: [String]? = nil
        public var maxTokens: Int? = nil
        public var choices: Int? = 1
        public var model: Model = .gpt_3_5_turbo
        
        public init(
            topProbabilityMass: Double? = 0,
            frequencyPenalty: Double? = 0,
            presencePenalty: Double? = 0,
            temperature: Double? = 1,
            user: String? = nil,
            stop: [String]? = nil,
            maxTokens: Int? = nil,
            choices: Int? = 1,
            model: Model = .gpt_3_5_turbo
        ) {
            self.topProbabilityMass = topProbabilityMass
            self.frequencyPenalty = frequencyPenalty
            self.presencePenalty = presencePenalty
            self.temperature = temperature
            self.user = user
            self.stop = stop
            self.maxTokens = maxTokens
            self.choices = choices
            self.model = model
        }
    }
    
    public struct Conversation: Encodable {
        let topProbabilityMass: Double?
        let frequencyPenalty: Double?
        let presencePenalty: Double?
        let temperature: Double?
        let user: String?
        let stop: [String]?
        let maxTokens: Int?
        let choices: Int?
        let model: String
        let messages: [Message]
        let stream: Bool
        
        enum CodingKeys: String, CodingKey {
            case user
            case stop
            case model
            case stream
            case choices = "n"
            case messages
            case maxTokens = "max_tokens"
            case temperature
            case presencePenalty = "presence_penalty"
            case frequencyPenalty = "frequency_penalty"
            case topProbabilityMass = "top_p"
        }
        
        init(_ history: [Message], with option: Option, stream: Bool) {
            messages = history
            user = option.user
            stop = option.stop
            model = option.model.description
            choices = option.choices
            maxTokens = option.maxTokens
            temperature = option.temperature
            presencePenalty = option.presencePenalty
            frequencyPenalty = option.frequencyPenalty
            topProbabilityMass = option.topProbabilityMass
            self.stream = stream
        }
    }
    
    public struct Result: Codable {
        public let model: String?
        public let usage: Usage
        public let object: String
        public let choices: [Choice]
    }
    
    public struct Choice: Codable {
        public let message: Message
    }
    
    public struct ResultDelta: Codable {
        public let model: String?
        public let object: String
        public let choices: [ChoiceDelta]
    }
    
    public struct ChoiceDelta: Codable {
        public let delta: MessageDelta
    }
    
    public enum Role: String, Codable {
        case system, user, assistant
    }
    
    public struct Message: Codable {
        public let role: Role
        public var content: String
        
        public init(role: Role = .user, content: String) {
            self.role = role
            self.content = content
        }
    }
    
    public struct MessageDelta: Codable {
        public let role: Role?
        public var content: String?
    }
    
    public struct Usage: Codable {
        public let totalTokens: Int
        public let promptTokens: Int
        public let completionTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
    
    public enum Error: Swift.Error {
        case status(_ code: Int)
        case generic(_ message: String)
        case decoding(_ message: String)
    }
    
    private func getResponseData(from request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = response.http!.statusCode
        guard 200...299 ~= statusCode else { throw Error.status(statusCode) }
        return data
    }
    
    private func getResponseBytes(from request: URLRequest) async throws -> URLSession.AsyncBytes {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let statusCode = response.http!.statusCode
        guard 200...299 ~= statusCode else { throw Error.status(statusCode) }
        return bytes
    }
    
    public func getStringResponse(from history: [Message], with option: Option = Option()) async throws -> String {
        try await getResponse(from: history, with: option).choices[0].message.content
    }
    
    public func getResponse(from history: [Message], with option: Option = Option()) async throws -> Result {
        let request = prepareRequest(from: history, with: option, stream: false)
        let data = try await getResponseData(from: request)
        do {
            return try jsonDecoder.decode(Result.self, from: data)
        } catch { throw Error.decoding(String(describing: error)) }
    }
    
    public func getStreamResponse(from history: [Message], with option: Option = Option()) async throws -> ResultStream {
        let request = prepareRequest(from: history, with: option, stream: true)
        let bytes = try await getResponseBytes(from: request)
        return ResultStream { continuation in Task { do {
            for try await line in bytes.lines {
                let result = try retrieveResult(from: line)
                let delta = result.choices[0].delta
                if delta.role != nil { continue }
                guard delta.content != nil else { break }
                continuation.yield(result)
            }
        } catch { throw Error.generic(String(describing: error)) }
            continuation.finish()
        } }
    }
    
    public func getStringStreamResponse(from history: [Message], with option: Option = Option()) async throws -> StringStream {
        let request = prepareRequest(from: history, with: option, stream: true)
        let bytes = try await getResponseBytes(from: request)
        return StringStream { continuation in Task { do {
            for try await line in bytes.lines {
                let result = try retrieveResult(from: line)
                let delta = result.choices[0].delta
                if delta.role != nil { continue }
                guard let content = delta.content else { break }
                continuation.yield(content)
            }
        } catch { throw Error.generic(String(describing: error)) }
            continuation.finish()
        } }
    }
    
    public func retrieveResult(from string: String) throws -> ResultDelta {
        guard string.hasPrefix("data: ") else { fatalError("'data: ' prefix doesn't exist") }
        do {
            let result = try jsonDecoder.decode(ResultDelta.self, from: Data(string.dropFirst(6).utf8))
            return result
        } catch { throw ChatGPT.Error.decoding(String(describing: error)) }
    }
    
    public func retrieveMessage(from string: String) throws -> MessageDelta {
        guard string.hasPrefix("data: ") else { fatalError("'data: ' prefix doesn't exist") }
        do {
            let result = try jsonDecoder.decode(ResultDelta.self, from: Data(string.dropFirst(6).utf8))
            return result.choices[0].delta
        } catch { throw Error.decoding(String(describing: error)) }
    }
    
    public typealias ResultStream = AsyncThrowingStream<ResultDelta, Swift.Error>
    public typealias StringStream = AsyncThrowingStream<String, Swift.Error>
}

