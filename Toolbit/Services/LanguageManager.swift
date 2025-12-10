import SwiftUI
import Foundation

// MARK: - 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return L10n.settingsFollowSystem
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }
}

// MARK: - 语言管理器
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let languageKey = "AppLanguage"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            applyLanguage()
        }
    }
    
    @Published var needsRestart: Bool = false
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
        applyLanguage()
    }
    
    private func applyLanguage() {
        if currentLanguage != .system {
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    func setLanguage(_ language: AppLanguage) {
        if language != currentLanguage {
            currentLanguage = language
            needsRestart = true
        }
    }
}

// MARK: - 本地化文本
struct L10n {
    // 菜单
    static var menuAbout: String { NSLocalizedString("menu.about", value: "关于 Toolbit", comment: "") }
    static var menuCheckUpdate: String { NSLocalizedString("menu.checkUpdate", value: "检查更新...", comment: "") }
    
    // 设置
    static var settingsTitle: String { NSLocalizedString("settings.title", value: "设置", comment: "") }
    static var settingsLanguageTitle: String { NSLocalizedString("settings.languageTitle", value: "语言设置", comment: "") }
    static var settingsLanguage: String { NSLocalizedString("settings.language", value: "语言", comment: "") }
    static var settingsFollowSystem: String { NSLocalizedString("settings.followSystem", value: "跟随系统", comment: "") }
    static var settingsUpdate: String { NSLocalizedString("settings.update", value: "更新设置", comment: "") }
    static var settingsAutoCheck: String { NSLocalizedString("settings.autoCheck", value: "启动时自动检查更新", comment: "") }
    static var settingsAbout: String { NSLocalizedString("settings.about", value: "关于", comment: "") }
    static var settingsVersion: String { NSLocalizedString("settings.version", value: "版本", comment: "") }
    static var settingsBuild: String { NSLocalizedString("settings.build", value: "构建号", comment: "") }
    static var settingsLastCheck: String { NSLocalizedString("settings.lastCheck", value: "上次检查", comment: "") }
    static var settingsRestartHint: String { NSLocalizedString("settings.restartHint", value: "重启应用后生效", comment: "") }
    
    // 分类
    static var categoryTextTools: String { NSLocalizedString("category.textTools", value: "文本工具", comment: "") }
    static var categoryEncoderDecoder: String { NSLocalizedString("category.encoderDecoder", value: "编解码器", comment: "") }
    static var categoryFormatters: String { NSLocalizedString("category.formatters", value: "格式化工具", comment: "") }
    static var categoryImageTools: String { NSLocalizedString("category.imageTools", value: "图片工具", comment: "") }
    
    // 工具
    static var toolCharacterCount: String { NSLocalizedString("tool.characterCount", value: "字符统计", comment: "") }
    static var toolStringDiff: String { NSLocalizedString("tool.stringDiff", value: "字符串对比", comment: "") }
    static var toolEscape: String { NSLocalizedString("tool.escape", value: "转义/反转义", comment: "") }
    static var toolMarkdownPreview: String { NSLocalizedString("tool.markdownPreview", value: "Markdown预览", comment: "") }
    static var toolBase64Text: String { NSLocalizedString("tool.base64Text", value: "Base64文本", comment: "") }
    static var toolUrlCoder: String { NSLocalizedString("tool.urlCoder", value: "URL编解码", comment: "") }
    static var toolQrCode: String { NSLocalizedString("tool.qrCode", value: "二维码", comment: "") }
    static var toolSvgConverter: String { NSLocalizedString("tool.svgConverter", value: "SVG转图片", comment: "") }
    static var toolBase64Image: String { NSLocalizedString("tool.base64Image", value: "Base64图片", comment: "") }
    static var toolJsonFormatter: String { NSLocalizedString("tool.jsonFormatter", value: "JSON", comment: "") }
    static var toolSqlFormatter: String { NSLocalizedString("tool.sqlFormatter", value: "SQL", comment: "") }
    static var toolXmlFormatter: String { NSLocalizedString("tool.xmlFormatter", value: "XML", comment: "") }
    static var toolOcr: String { NSLocalizedString("tool.ocr", value: "OCR文字识别", comment: "") }
    
    // 操作
    static var actionPaste: String { NSLocalizedString("action.paste", value: "粘贴", comment: "") }
    static var actionCopy: String { NSLocalizedString("action.copy", value: "复制", comment: "") }
    static var actionClear: String { NSLocalizedString("action.clear", value: "清空", comment: "") }
    static var actionFormat: String { NSLocalizedString("action.format", value: "格式化", comment: "") }
    static var actionCompress: String { NSLocalizedString("action.compress", value: "压缩", comment: "") }
    static var actionEncode: String { NSLocalizedString("action.encode", value: "编码", comment: "") }
    static var actionDecode: String { NSLocalizedString("action.decode", value: "解码", comment: "") }
    static var actionGenerate: String { NSLocalizedString("action.generate", value: "生成", comment: "") }
    static var actionRecognize: String { NSLocalizedString("action.recognize", value: "识别", comment: "") }
    static var actionSave: String { NSLocalizedString("action.save", value: "保存", comment: "") }
    static var actionSwap: String { NSLocalizedString("action.swap", value: "交换", comment: "") }
    
    // 标签
    static var labelInput: String { NSLocalizedString("label.input", value: "输入", comment: "") }
    static var labelOutput: String { NSLocalizedString("label.output", value: "输出", comment: "") }
    static var labelResult: String { NSLocalizedString("label.result", value: "结果", comment: "") }
    static var labelPreview: String { NSLocalizedString("label.preview", value: "预览", comment: "") }
    
    // 提示
    static var messageCopied: String { NSLocalizedString("message.copied", value: "已复制到剪贴板", comment: "") }
    static var messageSaved: String { NSLocalizedString("message.saved", value: "保存成功", comment: "") }
    static var messageCleared: String { NSLocalizedString("message.cleared", value: "已清空", comment: "") }
}
