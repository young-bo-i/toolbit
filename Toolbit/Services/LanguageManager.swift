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
        case .system: return "跟随系统"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }
    
    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.current.language.languageCode?.identifier ?? "zh-Hans"
        case .en: return "en"
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
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
            objectWillChange.send()
        }
    }
    
    // 用于触发视图刷新的 ID
    @Published var refreshID = UUID()
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        // 触发刷新
        refreshID = UUID()
    }
    
    // 获取当前语言的 Bundle
    var bundle: Bundle {
        let localeId = currentLanguage.localeIdentifier
        if let path = Bundle.main.path(forResource: localeId, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // 回退到简体中文
        if let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }
    
    // 本地化字符串
    func localized(_ key: String, defaultValue: String) -> String {
        return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }
}

// MARK: - 本地化文本（动态获取）
struct L10n {
    private static var manager: LanguageManager { LanguageManager.shared }
    
    // 菜单
    static var menuAbout: String { manager.localized("menu.about", defaultValue: "关于 Toolbit") }
    static var menuCheckUpdate: String { manager.localized("menu.checkUpdate", defaultValue: "检查更新...") }
    static var menuFile: String { manager.localized("menu.file", defaultValue: "文件") }
    static var menuEdit: String { manager.localized("menu.edit", defaultValue: "编辑") }
    static var menuView: String { manager.localized("menu.view", defaultValue: "视图") }
    static var menuWindow: String { manager.localized("menu.window", defaultValue: "窗口") }
    static var menuHelp: String { manager.localized("menu.help", defaultValue: "帮助") }
    
    // 设置
    static var settingsTitle: String { manager.localized("settings.title", defaultValue: "设置") }
    static var settingsLanguageTitle: String { manager.localized("settings.languageTitle", defaultValue: "语言设置") }
    static var settingsLanguage: String { manager.localized("settings.language", defaultValue: "语言") }
    static var settingsFollowSystem: String { manager.localized("settings.followSystem", defaultValue: "跟随系统") }
    static var settingsUpdate: String { manager.localized("settings.update", defaultValue: "更新设置") }
    static var settingsAutoCheck: String { manager.localized("settings.autoCheck", defaultValue: "启动时自动检查更新") }
    static var settingsAbout: String { manager.localized("settings.about", defaultValue: "关于") }
    static var settingsVersion: String { manager.localized("settings.version", defaultValue: "版本") }
    static var settingsBuild: String { manager.localized("settings.build", defaultValue: "构建号") }
    static var settingsLastCheck: String { manager.localized("settings.lastCheck", defaultValue: "上次检查") }
    static var settingsRestartHint: String { manager.localized("settings.restartHint", defaultValue: "部分菜单需重启生效") }
    
    // 分类
    static var categoryTextTools: String { manager.localized("category.textTools", defaultValue: "文本工具") }
    static var categoryEncoderDecoder: String { manager.localized("category.encoderDecoder", defaultValue: "编解码器") }
    static var categoryFormatters: String { manager.localized("category.formatters", defaultValue: "格式化工具") }
    static var categoryImageTools: String { manager.localized("category.imageTools", defaultValue: "图片工具") }
    
    // 工具
    static var toolCharacterCount: String { manager.localized("tool.characterCount", defaultValue: "字符统计") }
    static var toolStringDiff: String { manager.localized("tool.stringDiff", defaultValue: "字符串对比") }
    static var toolEscape: String { manager.localized("tool.escape", defaultValue: "转义/反转义") }
    static var toolMarkdownPreview: String { manager.localized("tool.markdownPreview", defaultValue: "Markdown预览") }
    static var toolBase64Text: String { manager.localized("tool.base64Text", defaultValue: "Base64文本") }
    static var toolUrlCoder: String { manager.localized("tool.urlCoder", defaultValue: "URL编解码") }
    static var toolQrCode: String { manager.localized("tool.qrCode", defaultValue: "二维码") }
    static var toolSvgConverter: String { manager.localized("tool.svgConverter", defaultValue: "SVG转图片") }
    static var toolBase64Image: String { manager.localized("tool.base64Image", defaultValue: "Base64图片") }
    static var toolJsonFormatter: String { manager.localized("tool.jsonFormatter", defaultValue: "JSON") }
    static var toolSqlFormatter: String { manager.localized("tool.sqlFormatter", defaultValue: "SQL") }
    static var toolXmlFormatter: String { manager.localized("tool.xmlFormatter", defaultValue: "XML") }
    static var toolOcr: String { manager.localized("tool.ocr", defaultValue: "OCR文字识别") }
    
    // 操作
    static var actionPaste: String { manager.localized("action.paste", defaultValue: "粘贴") }
    static var actionCopy: String { manager.localized("action.copy", defaultValue: "复制") }
    static var actionClear: String { manager.localized("action.clear", defaultValue: "清空") }
    static var actionFormat: String { manager.localized("action.format", defaultValue: "格式化") }
    static var actionCompress: String { manager.localized("action.compress", defaultValue: "压缩") }
    static var actionEncode: String { manager.localized("action.encode", defaultValue: "编码") }
    static var actionDecode: String { manager.localized("action.decode", defaultValue: "解码") }
    static var actionGenerate: String { manager.localized("action.generate", defaultValue: "生成") }
    static var actionRecognize: String { manager.localized("action.recognize", defaultValue: "识别") }
    static var actionSave: String { manager.localized("action.save", defaultValue: "保存") }
    static var actionSwap: String { manager.localized("action.swap", defaultValue: "交换") }
    
    // 标签
    static var labelInput: String { manager.localized("label.input", defaultValue: "输入") }
    static var labelOutput: String { manager.localized("label.output", defaultValue: "输出") }
    static var labelResult: String { manager.localized("label.result", defaultValue: "结果") }
    static var labelPreview: String { manager.localized("label.preview", defaultValue: "预览") }
    
    // 提示
    static var messageCopied: String { manager.localized("message.copied", defaultValue: "已复制到剪贴板") }
    static var messageSaved: String { manager.localized("message.saved", defaultValue: "保存成功") }
    static var messageCleared: String { manager.localized("message.cleared", defaultValue: "已清空") }
}

// MARK: - 环境键
struct LanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: UUID = UUID()
}

extension EnvironmentValues {
    var languageRefreshID: UUID {
        get { self[LanguageEnvironmentKey.self] }
        set { self[LanguageEnvironmentKey.self] = newValue }
    }
}
