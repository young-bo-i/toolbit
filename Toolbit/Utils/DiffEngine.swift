import Foundation

// MARK: - Diff 类型定义
enum DiffType {
    case equal      // 相同
    case insert     // 新增
    case delete     // 删除
    case modified   // 修改（用于行级别）
}

struct DiffLine: Identifiable, Equatable {
    let id = UUID()
    let type: DiffType
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let leftText: String?
    let rightText: String?
    let inlineChanges: [InlineChange]?
    
    static func == (lhs: DiffLine, rhs: DiffLine) -> Bool {
        lhs.id == rhs.id
    }
}

struct InlineChange: Identifiable {
    let id = UUID()
    let type: DiffType
    let text: String
    let range: Range<String.Index>?
}

// MARK: - Diff 引擎
class DiffEngine {
    
    /// 计算两个文本的行级别差异
    static func computeLineDiff(oldText: String, newText: String) -> [DiffLine] {
        let oldLines = oldText.components(separatedBy: "\n")
        let newLines = newText.components(separatedBy: "\n")
        
        // 使用 Myers diff 算法的简化版本
        let lcs = longestCommonSubsequence(oldLines, newLines)
        
        var result: [DiffLine] = []
        var oldIndex = 0
        var newIndex = 0
        var lcsIndex = 0
        
        var leftLineNum = 1
        var rightLineNum = 1
        
        while oldIndex < oldLines.count || newIndex < newLines.count {
            if lcsIndex < lcs.count {
                let (lcsOldIdx, lcsNewIdx) = lcs[lcsIndex]
                
                // 处理删除的行（在旧文本中但不在 LCS 中）
                while oldIndex < lcsOldIdx {
                    result.append(DiffLine(
                        type: .delete,
                        leftLineNumber: leftLineNum,
                        rightLineNumber: nil,
                        leftText: oldLines[oldIndex],
                        rightText: nil,
                        inlineChanges: nil
                    ))
                    oldIndex += 1
                    leftLineNum += 1
                }
                
                // 处理新增的行（在新文本中但不在 LCS 中）
                while newIndex < lcsNewIdx {
                    result.append(DiffLine(
                        type: .insert,
                        leftLineNumber: nil,
                        rightLineNumber: rightLineNum,
                        leftText: nil,
                        rightText: newLines[newIndex],
                        inlineChanges: nil
                    ))
                    newIndex += 1
                    rightLineNum += 1
                }
                
                // 处理相同的行
                if oldIndex < oldLines.count && newIndex < newLines.count {
                    result.append(DiffLine(
                        type: .equal,
                        leftLineNumber: leftLineNum,
                        rightLineNumber: rightLineNum,
                        leftText: oldLines[oldIndex],
                        rightText: newLines[newIndex],
                        inlineChanges: nil
                    ))
                    oldIndex += 1
                    newIndex += 1
                    leftLineNum += 1
                    rightLineNum += 1
                }
                
                lcsIndex += 1
            } else {
                // 处理剩余的删除行
                while oldIndex < oldLines.count {
                    result.append(DiffLine(
                        type: .delete,
                        leftLineNumber: leftLineNum,
                        rightLineNumber: nil,
                        leftText: oldLines[oldIndex],
                        rightText: nil,
                        inlineChanges: nil
                    ))
                    oldIndex += 1
                    leftLineNum += 1
                }
                
                // 处理剩余的新增行
                while newIndex < newLines.count {
                    result.append(DiffLine(
                        type: .insert,
                        leftLineNumber: nil,
                        rightLineNumber: rightLineNum,
                        leftText: nil,
                        rightText: newLines[newIndex],
                        inlineChanges: nil
                    ))
                    newIndex += 1
                    rightLineNum += 1
                }
            }
        }
        
        // 合并相邻的删除和新增为修改
        return mergeAdjacentChanges(result)
    }
    
    /// 计算最长公共子序列
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        let m = a.count
        let n = b.count
        
        // 边界情况：如果任一数组为空，返回空结果
        guard m > 0 && n > 0 else { return [] }
        
        // 创建 DP 表
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        // 回溯找出 LCS 的索引对
        var result: [(Int, Int)] = []
        var i = m
        var j = n
        
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return result.reversed()
    }
    
    /// 合并相邻的删除和新增为修改行
    private static func mergeAdjacentChanges(_ lines: [DiffLine]) -> [DiffLine] {
        var result: [DiffLine] = []
        var i = 0
        
        while i < lines.count {
            let current = lines[i]
            
            // 查找连续的删除
            if current.type == .delete {
                var deleteLines: [DiffLine] = [current]
                var j = i + 1
                
                while j < lines.count && lines[j].type == .delete {
                    deleteLines.append(lines[j])
                    j += 1
                }
                
                // 查找紧随其后的连续新增
                var insertLines: [DiffLine] = []
                while j < lines.count && lines[j].type == .insert {
                    insertLines.append(lines[j])
                    j += 1
                }
                
                // 如果有配对的删除和新增，合并为修改
                let pairCount = min(deleteLines.count, insertLines.count)
                
                for k in 0..<pairCount {
                    let deleteLine = deleteLines[k]
                    let insertLine = insertLines[k]
                    
                    // 计算行内差异
                    let inlineChanges = computeInlineChanges(
                        oldText: deleteLine.leftText ?? "",
                        newText: insertLine.rightText ?? ""
                    )
                    
                    result.append(DiffLine(
                        type: .modified,
                        leftLineNumber: deleteLine.leftLineNumber,
                        rightLineNumber: insertLine.rightLineNumber,
                        leftText: deleteLine.leftText,
                        rightText: insertLine.rightText,
                        inlineChanges: inlineChanges
                    ))
                }
                
                // 添加剩余的删除行
                for k in pairCount..<deleteLines.count {
                    result.append(deleteLines[k])
                }
                
                // 添加剩余的新增行
                for k in pairCount..<insertLines.count {
                    result.append(insertLines[k])
                }
                
                i = j
            } else {
                result.append(current)
                i += 1
            }
        }
        
        return result
    }
    
    /// 计算两行文本的字符级别差异
    static func computeInlineChanges(oldText: String, newText: String) -> [InlineChange] {
        let oldChars = Array(oldText)
        let newChars = Array(newText)
        
        // 使用字符级别的 LCS
        let lcs = characterLCS(oldChars, newChars)
        
        var changes: [InlineChange] = []
        var oldIdx = 0
        var newIdx = 0
        var lcsIdx = 0
        
        while oldIdx < oldChars.count || newIdx < newChars.count {
            if lcsIdx < lcs.count {
                let (lcsOldIdx, lcsNewIdx) = lcs[lcsIdx]
                
                // 删除的字符
                if oldIdx < lcsOldIdx {
                    let deletedChars = String(oldChars[oldIdx..<lcsOldIdx])
                    changes.append(InlineChange(type: .delete, text: deletedChars, range: nil))
                    oldIdx = lcsOldIdx
                }
                
                // 新增的字符
                if newIdx < lcsNewIdx {
                    let insertedChars = String(newChars[newIdx..<lcsNewIdx])
                    changes.append(InlineChange(type: .insert, text: insertedChars, range: nil))
                    newIdx = lcsNewIdx
                }
                
                // 相同的字符
                if oldIdx < oldChars.count && newIdx < newChars.count {
                    changes.append(InlineChange(type: .equal, text: String(oldChars[oldIdx]), range: nil))
                    oldIdx += 1
                    newIdx += 1
                }
                
                lcsIdx += 1
            } else {
                // 剩余删除
                if oldIdx < oldChars.count {
                    let deletedChars = String(oldChars[oldIdx...])
                    changes.append(InlineChange(type: .delete, text: deletedChars, range: nil))
                    oldIdx = oldChars.count
                }
                
                // 剩余新增
                if newIdx < newChars.count {
                    let insertedChars = String(newChars[newIdx...])
                    changes.append(InlineChange(type: .insert, text: insertedChars, range: nil))
                    newIdx = newChars.count
                }
            }
        }
        
        // 合并连续的相同类型
        return mergeConsecutiveChanges(changes)
    }
    
    /// 字符级别的 LCS
    private static func characterLCS(_ a: [Character], _ b: [Character]) -> [(Int, Int)] {
        let m = a.count
        let n = b.count
        
        // 边界情况：如果任一数组为空，返回空结果
        guard m > 0 && n > 0 else { return [] }
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        var result: [(Int, Int)] = []
        var i = m
        var j = n
        
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return result.reversed()
    }
    
    /// 合并连续的相同类型变更
    private static func mergeConsecutiveChanges(_ changes: [InlineChange]) -> [InlineChange] {
        guard !changes.isEmpty else { return [] }
        
        var result: [InlineChange] = []
        var currentType = changes[0].type
        var currentText = changes[0].text
        
        for i in 1..<changes.count {
            if changes[i].type == currentType {
                currentText += changes[i].text
            } else {
                result.append(InlineChange(type: currentType, text: currentText, range: nil))
                currentType = changes[i].type
                currentText = changes[i].text
            }
        }
        
        result.append(InlineChange(type: currentType, text: currentText, range: nil))
        
        return result
    }
}

// MARK: - 统计信息
struct DiffStats {
    let totalLines: Int
    let addedLines: Int
    let deletedLines: Int
    let modifiedLines: Int
    let unchangedLines: Int
    
    init(from diffLines: [DiffLine]) {
        var added = 0
        var deleted = 0
        var modified = 0
        var unchanged = 0
        
        for line in diffLines {
            switch line.type {
            case .insert:
                added += 1
            case .delete:
                deleted += 1
            case .modified:
                modified += 1
            case .equal:
                unchanged += 1
            }
        }
        
        self.addedLines = added
        self.deletedLines = deleted
        self.modifiedLines = modified
        self.unchangedLines = unchanged
        self.totalLines = added + deleted + modified + unchanged
    }
}

