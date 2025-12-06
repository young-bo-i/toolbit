import Foundation

// MARK: - 工具分类
enum ToolCategory: String, CaseIterable, Identifiable {
    case textTools = "文本工具"
    case encoderDecoder = "编解码器"
    case formatters = "格式化工具"
    case imageTools = "图片工具"
    
    var id: String { rawValue }
    
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
    case characterCount = "字符统计"
    case stringDiff = "字符串对比"
    case escape = "转义/反转义"
    case markdownPreview = "Markdown预览"
    case base64Text = "Base64文本"
    case urlCoder = "URL编解码"
    case qrCode = "二维码"
    case svgConverter = "SVG转图片"
    case base64Image = "Base64图片"
    case jsonFormatter = "JSON"
    case sqlFormatter = "SQL"
    case xmlFormatter = "XML"
    case ocr = "OCR文字识别"
    
    var id: String { rawValue }
    
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
    
    var description: String {
        switch self {
        case .characterCount:
            return "统计文本中的字符、单词、行数等"
        case .stringDiff:
            return "对比两段文本的差异"
        case .escape:
            return "对特殊字符进行转义和反转义"
        case .markdownPreview:
            return "实时预览Markdown文档"
        case .base64Text:
            return "文本的Base64编码与解码"
        case .urlCoder:
            return "URL百分号编码与解码"
        case .qrCode:
            return "生成和识别二维码"
        case .svgConverter:
            return "将SVG代码转换为PNG图片"
        case .base64Image:
            return "图片与Base64编码互转"
        case .jsonFormatter:
            return "格式化和美化JSON数据"
        case .sqlFormatter:
            return "格式化和美化SQL语句"
        case .xmlFormatter:
            return "格式化和美化XML数据"
        case .ocr:
            return "从图片中识别并提取文字"
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
