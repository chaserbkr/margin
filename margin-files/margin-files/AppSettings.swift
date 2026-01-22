import Foundation
import Security

// MARK: - Margin Plan

enum MarginPlan: String, CaseIterable, Codable {
    case free = "free"
    case pro = "pro"
    case team = "team"

    var displayName: String {
        switch self {
        case .free: return "Free plan"
        case .pro: return "Pro plan"
        case .team: return "Team plan"
        }
    }
}

// MARK: - AI Provider

enum AIProvider: String, CaseIterable, Codable {
    case openAI
    case anthropic
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }
    
    var keychainKey: String {
        switch self {
        case .openAI: return "com.margin.openai-api-key"
        case .anthropic: return "com.margin.anthropic-api-key"
        }
    }
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: "aiEnabled") }
    }

    @Published var aiProvider: AIProvider {
        didSet { UserDefaults.standard.set(aiProvider.rawValue, forKey: "aiProvider") }
    }

    @Published var defaultLayoutMode: LayoutMode {
        didSet { UserDefaults.standard.set(defaultLayoutMode.rawValue, forKey: "defaultLayoutMode") }
    }

    @Published var defaultTypeSystem: TypeSystem {
        didSet { UserDefaults.standard.set(defaultTypeSystem.rawValue, forKey: "defaultTypeSystem") }
    }
    
    @Published var baseFontSize: CGFloat {
        didSet { UserDefaults.standard.set(baseFontSize, forKey: "baseFontSize") }
    }
    
    @Published var lineHeightMultiple: CGFloat {
        didSet { UserDefaults.standard.set(lineHeightMultiple, forKey: "lineHeightMultiple") }
    }

    // User profile
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    @Published var userPlan: MarginPlan {
        didSet { UserDefaults.standard.set(userPlan.rawValue, forKey: "userPlan") }
    }

    init() {
        self.aiEnabled = UserDefaults.standard.bool(forKey: "aiEnabled")

        if let providerRaw = UserDefaults.standard.string(forKey: "aiProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            self.aiProvider = provider
        } else {
            self.aiProvider = .openAI
        }

        if let layoutRaw = UserDefaults.standard.string(forKey: "defaultLayoutMode"),
           let layout = LayoutMode(rawValue: layoutRaw) {
            self.defaultLayoutMode = layout
        } else {
            self.defaultLayoutMode = .write
        }

        if let typeRaw = UserDefaults.standard.string(forKey: "defaultTypeSystem"),
           let typeSystem = TypeSystem(rawValue: typeRaw) {
            self.defaultTypeSystem = typeSystem
        } else {
            self.defaultTypeSystem = .editorialSerif
        }
        
        // Font size (default 18px)
        let savedFontSize = UserDefaults.standard.double(forKey: "baseFontSize")
        self.baseFontSize = savedFontSize > 0 ? savedFontSize : 18.0
        
        // Line height (default 1.65)
        let savedLineHeight = UserDefaults.standard.double(forKey: "lineHeightMultiple")
        self.lineHeightMultiple = savedLineHeight > 0 ? savedLineHeight : 1.65

        // User profile defaults
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? NSFullUserName()

        if let planRaw = UserDefaults.standard.string(forKey: "userPlan"),
           let plan = MarginPlan(rawValue: planRaw) {
            self.userPlan = plan
        } else {
            self.userPlan = .free
        }
    }
    
    // MARK: - Keychain API Key Management
    
    func getAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: provider.keychainKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    func setAPIKey(_ key: String, for provider: AIProvider) {
        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: provider.keychainKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new key
        guard let data = key.data(using: .utf8) else { return }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: provider.keychainKey,
            kSecValueData as String: data
        ]
        
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    func deleteAPIKey(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: provider.keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
