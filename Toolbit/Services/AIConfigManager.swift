import Foundation

/// AI 大模型配置管理器
/// 配置数据保存在 UserDefaults 中，自动更新后数据会保留
@MainActor
class AIConfigManager: ObservableObject {
    static let shared = AIConfigManager()
    
    // MARK: - 配置键
    private enum Keys {
        static let endpoint = "ai_endpoint"
        static let apiKey = "ai_api_key"
        static let modelId = "ai_model_id"
        static let isEnabled = "ai_enabled"
    }
    
    // MARK: - 发布的属性
    @Published var endpoint: String {
        didSet { save() }
    }
    
    @Published var apiKey: String {
        didSet { save() }
    }
    
    @Published var modelId: String {
        didSet { save() }
    }
    
    @Published var isEnabled: Bool {
        didSet { save() }
    }
    
    // MARK: - 预设模型
    struct PresetModel: Identifiable, Hashable {
        let id: String
        let name: String
        let defaultEndpoint: String
        
        static let presets: [PresetModel] = [
            PresetModel(id: "gpt-4", name: "GPT-4", defaultEndpoint: "https://api.openai.com/v1"),
            PresetModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", defaultEndpoint: "https://api.openai.com/v1"),
            PresetModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", defaultEndpoint: "https://api.openai.com/v1"),
            PresetModel(id: "claude-3-opus", name: "Claude 3 Opus", defaultEndpoint: "https://api.anthropic.com/v1"),
            PresetModel(id: "claude-3-sonnet", name: "Claude 3 Sonnet", defaultEndpoint: "https://api.anthropic.com/v1"),
            PresetModel(id: "claude-3-haiku", name: "Claude 3 Haiku", defaultEndpoint: "https://api.anthropic.com/v1"),
            PresetModel(id: "deepseek-chat", name: "DeepSeek Chat", defaultEndpoint: "https://api.deepseek.com/v1"),
            PresetModel(id: "deepseek-coder", name: "DeepSeek Coder", defaultEndpoint: "https://api.deepseek.com/v1"),
            PresetModel(id: "qwen-turbo", name: "通义千问 Turbo", defaultEndpoint: "https://dashscope.aliyuncs.com/api/v1"),
            PresetModel(id: "qwen-plus", name: "通义千问 Plus", defaultEndpoint: "https://dashscope.aliyuncs.com/api/v1"),
            PresetModel(id: "custom", name: "自定义", defaultEndpoint: ""),
        ]
    }
    
    // MARK: - 初始化
    private init() {
        // 从 UserDefaults 加载配置
        self.endpoint = UserDefaults.standard.string(forKey: Keys.endpoint) ?? ""
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""
        self.modelId = UserDefaults.standard.string(forKey: Keys.modelId) ?? ""
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
    }
    
    // MARK: - 保存配置
    private func save() {
        UserDefaults.standard.set(endpoint, forKey: Keys.endpoint)
        UserDefaults.standard.set(apiKey, forKey: Keys.apiKey)
        UserDefaults.standard.set(modelId, forKey: Keys.modelId)
        UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
    }
    
    // MARK: - 验证配置
    var isConfigured: Bool {
        !endpoint.isEmpty && !apiKey.isEmpty && !modelId.isEmpty
    }
    
    // MARK: - 重置配置
    func reset() {
        endpoint = ""
        apiKey = ""
        modelId = ""
        isEnabled = false
    }
    
    // MARK: - 应用预设
    func applyPreset(_ preset: PresetModel) {
        if !preset.defaultEndpoint.isEmpty {
            endpoint = preset.defaultEndpoint
        }
        modelId = preset.id
    }
    
    // MARK: - 测试连接（预留接口）
    func testConnection() async -> Result<String, Error> {
        guard isConfigured else {
            return .failure(AIConfigError.notConfigured)
        }
        
        // TODO: 实现实际的连接测试
        // 这里可以发送一个简单的请求来验证配置是否正确
        
        return .success("连接测试成功")
    }
}

// MARK: - 错误类型
enum AIConfigError: LocalizedError {
    case notConfigured
    case invalidEndpoint
    case invalidApiKey
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 配置不完整，请填写所有必要字段"
        case .invalidEndpoint:
            return "无效的 API 端点地址"
        case .invalidApiKey:
            return "无效的 API 密钥"
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        }
    }
}

