import Foundation

// MARK: - AI Command Types

enum AICommand: String, CaseIterable {
    case summarize
    case outline
    case rewriteClarity = "rewrite clarity"
    case rewriteCalm = "rewrite calm"
    case extractDecisions = "extract decisions"
    case nextSteps = "next steps"
    
    var displayName: String {
        switch self {
        case .summarize: return "Summarize"
        case .outline: return "Create Outline"
        case .rewriteClarity: return "Rewrite for Clarity"
        case .rewriteCalm: return "Rewrite Calmly"
        case .extractDecisions: return "Extract Decisions"
        case .nextSteps: return "Identify Next Steps"
        }
    }
    
    var description: String {
        switch self {
        case .summarize: return "Create a concise summary"
        case .outline: return "Generate a structured outline"
        case .rewriteClarity: return "Improve clarity and readability"
        case .rewriteCalm: return "Soften tone, reduce urgency"
        case .extractDecisions: return "Pull out key decisions"
        case .nextSteps: return "List actionable next steps"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .summarize:
            return "You are a skilled editor. Summarize the following text concisely while preserving key information. Keep the summary brief and focused."
        case .outline:
            return "You are an organizational expert. Create a clear, hierarchical outline from the following text. Use simple formatting with main points and sub-points."
        case .rewriteClarity:
            return "You are an expert editor focused on clarity. Rewrite the following text to be clearer and more direct. Simplify complex sentences, remove jargon, and improve flow. Maintain the original meaning and tone."
        case .rewriteCalm:
            return "You are a thoughtful editor. Rewrite the following text with a calmer, more measured tone. Reduce urgency, soften harsh language, and maintain professionalism while keeping the core message."
        case .extractDecisions:
            return "You are an analytical assistant. Identify and list all decisions, conclusions, or determinations mentioned in the following text. Present them as a clear, bulleted list."
        case .nextSteps:
            return "You are a project management expert. Identify actionable next steps from the following text. Present them as a clear, prioritized list of tasks or actions to take."
        }
    }
    
    static func find(matching query: String) -> [AICommand] {
        let lowercased = query.lowercased()
        return allCases.filter { command in
            command.rawValue.contains(lowercased) ||
            command.displayName.lowercased().contains(lowercased)
        }
    }
}

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    func execute(command: AICommand, on text: String) async throws -> String
    func cancel()
}

// MARK: - AI Service

class AIService: AIServiceProtocol {
    private let settings: AppSettings
    private var currentTask: Task<String, Error>?
    
    init(settings: AppSettings) {
        self.settings = settings
    }
    
    func execute(command: AICommand, on text: String) async throws -> String {
        guard settings.aiEnabled else {
            throw AIError.disabled
        }
        
        guard let apiKey = settings.getAPIKey(for: settings.aiProvider), !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let task = Task<String, Error> {
            switch settings.aiProvider {
            case .openAI:
                return try await executeOpenAI(command: command, text: text, apiKey: apiKey)
            case .anthropic:
                return try await executeAnthropic(command: command, text: text, apiKey: apiKey)
            }
        }
        
        currentTask = task
        return try await task.value
    }
    
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - OpenAI Implementation
    
    private func executeOpenAI(command: AICommand, text: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": command.systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Anthropic Implementation
    
    private func executeAnthropic(command: AICommand, text: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-3-sonnet-20240229",
            "max_tokens": 2000,
            "system": command.systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIError.invalidResponse
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case disabled
    case missingAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI assistance is disabled. Enable it in Settings."
        case .missingAPIKey:
            return "API key not configured. Add your API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the AI service."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        case .cancelled:
            return "Request was cancelled."
        }
    }
}
