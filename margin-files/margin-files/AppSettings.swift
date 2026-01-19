import Foundation
import Security

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
            self.defaultLayoutMode = .essay
        }
        
        if let typeRaw = UserDefaults.standard.string(forKey: "defaultTypeSystem"),
           let typeSystem = TypeSystem(rawValue: typeRaw) {
            self.defaultTypeSystem = typeSystem
        } else {
            self.defaultTypeSystem = .editorialSerif
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
