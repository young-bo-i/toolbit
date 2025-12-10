import Foundation

// MARK: - 工具分类
enum ToolCategory: String, CaseIterable, Identifiable {
    case textTools
    case encoderDecoder
    case formatters
    case imageTools
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .textTools: return L10n.categoryTextTools
        case .encoderDecoder: return L10n.categoryEncoderDecoder
        case .formatters: return L10n.categoryFormatters
        case .imageTools: return L10n.categoryImageTools
        }
    }
    
    var icon: String {
        switch self {
        case .textTools:
            return "text.alignleft"
        case .encoderDecoder:
            return "arrow.left.arrow.right.circle"
        case .formatters:
            return "text.alignleft"
        case .imageTools:
            return "photo"
        }
    }
    
    var tools: [ToolType] {
        switch self {
        case .textTools:
            return [.characterCount, .stringDiff, .escape, .markdownPreview]
        case .encoderDecoder:
            return [.base64Text, .urlCoder, .qrCode, .svgConverter, .base64Image]
        case .formatters:
            return [.jsonFormatter, .sqlFormatter, .xmlFormatter]
        case .imageTools:
            return [.ocr]
        }
    }
}

// MARK: - 工具类型
enum ToolType: String, CaseIterable, Identifiable {
    case characterCount
    case stringDiff
    case escape
    case markdownPreview
    case base64Text
    case urlCoder
    case qrCode
    case svgConverter
    case base64Image
    case jsonFormatter
    case sqlFormatter
    case xmlFormatter
    case ocr
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .characterCount: return L10n.toolCharacterCount
        case .stringDiff: return L10n.toolStringDiff
        case .escape: return L10n.toolEscape
        case .markdownPreview: return L10n.toolMarkdownPreview
        case .base64Text: return L10n.toolBase64Text
        case .urlCoder: return L10n.toolUrlCoder
        case .qrCode: return L10n.toolQrCode
        case .svgConverter: return L10n.toolSvgConverter
        case .base64Image: return L10n.toolBase64Image
        case .jsonFormatter: return L10n.toolJsonFormatter
        case .sqlFormatter: return L10n.toolSqlFormatter
        case .xmlFormatter: return L10n.toolXmlFormatter
        case .ocr: return L10n.toolOcr
        }
    }
    
    var icon: String {
        switch self {
        case .characterCount:
            return "textformat.123"
        case .stringDiff:
            return "arrow.left.arrow.right.square"
        case .escape:
            return "arrow.left.arrow.right"
        case .markdownPreview:
            return "doc.richtext"
        case .base64Text:
            return "doc.text"
        case .urlCoder:
            return "link"
        case .qrCode:
            return "qrcode"
        case .svgConverter:
            return "square.on.square.badge.person.crop"
        case .base64Image:
            return "photo.on.rectangle"
        case .jsonFormatter:
            return "curlybraces"
        case .sqlFormatter:
            return "tablecells"
        case .xmlFormatter:
            return "chevron.left.forwardslash.chevron.right"
        case .ocr:
            return "text.viewfinder"
        }
    }
    
    var category: ToolCategory {
        switch self {
        case .characterCount, .stringDiff, .escape, .markdownPreview:
            return .textTools
        case .base64Text, .urlCoder, .qrCode, .svgConverter, .base64Image:
            return .encoderDecoder
        case .jsonFormatter, .sqlFormatter, .xmlFormatter:
            return .formatters
        case .ocr:
            return .imageTools
        }
    }
}
