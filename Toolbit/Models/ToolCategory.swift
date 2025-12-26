import Foundation

// MARK: - 工具分类
enum ToolCategory: String, CaseIterable, Identifiable {
    case textTools
    case encoderDecoder
    case formatters
    case imageTools
    case statistics
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .textTools: return L10n.categoryTextTools
        case .encoderDecoder: return L10n.categoryEncoderDecoder
        case .formatters: return L10n.categoryFormatters
        case .imageTools: return L10n.categoryImageTools
        case .statistics: return L10n.categoryStatistics
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
        case .statistics:
            return "chart.bar.xaxis"
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
        case .statistics:
            return [.activityTracker]
        }
    }
}

// MARK: - 工具类型
enum ToolType: String, CaseIterable, Identifiable {
    case home
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
    case activityTracker
    
    var id: String { rawValue }
    
    /// 不包含首页的所有工具
    static var allTools: [ToolType] {
        allCases.filter { $0 != .home }
    }
    
    var displayName: String {
        switch self {
        case .home: return "首页"
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
        case .activityTracker: return L10n.toolActivityTracker
        }
    }
    
    var subtitle: String {
        switch self {
        case .home: return ""
        case .characterCount: return "统计字符、单词、行数"
        case .stringDiff: return "对比两段文本的差异"
        case .escape: return "转义和反转义特殊字符"
        case .markdownPreview: return "实时预览 Markdown"
        case .base64Text: return "Base64 编码解码"
        case .urlCoder: return "URL 编码解码"
        case .qrCode: return "生成和识别二维码"
        case .svgConverter: return "SVG 转 PNG 图片"
        case .base64Image: return "图片与 Base64 互转"
        case .jsonFormatter: return "格式化和压缩 JSON"
        case .sqlFormatter: return "格式化 SQL 语句"
        case .xmlFormatter: return "格式化 XML 文档"
        case .ocr: return "识别图片中的文字"
        case .activityTracker: return "追踪键盘鼠标活动"
        }
    }
    
    var icon: String {
        switch self {
        case .home:
            return "house.fill"
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
        case .activityTracker:
            return "keyboard.badge.eye"
        }
    }
    
    var color: Color {
        switch self {
        case .home: return .blue
        case .characterCount: return .blue
        case .stringDiff: return .purple
        case .escape: return .orange
        case .markdownPreview: return .pink
        case .base64Text: return .green
        case .urlCoder: return .cyan
        case .qrCode: return .indigo
        case .svgConverter: return .orange
        case .base64Image: return .teal
        case .jsonFormatter: return .yellow
        case .sqlFormatter: return .purple
        case .xmlFormatter: return .green
        case .ocr: return .red
        case .activityTracker: return .mint
        }
    }
    
    var category: ToolCategory {
        switch self {
        case .home:
            return .textTools // 首页不属于任何分类，这里随便给一个
        case .characterCount, .stringDiff, .escape, .markdownPreview:
            return .textTools
        case .base64Text, .urlCoder, .qrCode, .svgConverter, .base64Image:
            return .encoderDecoder
        case .jsonFormatter, .sqlFormatter, .xmlFormatter:
            return .formatters
        case .ocr:
            return .imageTools
        case .activityTracker:
            return .statistics
        }
    }
}

import SwiftUI
