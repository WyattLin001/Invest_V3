//
//  SlackWebhookService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/1.
//  Slack Webhook 服務 - 處理 AI 文章審核的 Slack 互動
//

import Foundation
import Supabase

// MARK: - Slack 互動負載模型
struct SlackInteractionPayload: Codable {
    let type: String
    let user: SlackUser
    let actions: [SlackAction]
    let channel: SlackChannel
    let message: SlackMessage?
    let responseUrl: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case user
        case actions
        case channel
        case message
        case responseUrl = "response_url"
    }
}

struct SlackUser: Codable {
    let id: String
    let username: String
    let name: String
}

struct SlackAction: Codable {
    let actionId: String
    let value: String
    let text: SlackText
    let style: String?
    
    enum CodingKeys: String, CodingKey {
        case actionId = "action_id"
        case value
        case text
        case style
    }
}

struct SlackText: Codable {
    let type: String
    let text: String
}

struct SlackChannel: Codable {
    let id: String
    let name: String
}

struct SlackMessage: Codable {
    let text: String
    let ts: String
}

// MARK: - Slack 回應模型
struct SlackResponse: Codable {
    let text: String
    let responseType: String
    let replaceOriginal: Bool
    let blocks: [SlackBlock]?
    
    enum CodingKeys: String, CodingKey {
        case text
        case responseType = "response_type"
        case replaceOriginal = "replace_original"
        case blocks
    }
}

struct SlackBlock: Codable {
    let type: String
    let text: SlackText?
}

// MARK: - Slack Webhook 服務
@MainActor
class SlackWebhookService: ObservableObject {
    static let shared = SlackWebhookService()
    
    // MARK: - Properties
    private let supabaseService = SupabaseService.shared
    private let aiAuthorService = AIAuthorService.shared
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 處理 Slack 互動請求
    func handleSlackInteraction(_ payload: SlackInteractionPayload) async throws -> SlackResponse {
        print("🔄 [SlackWebhookService] 處理 Slack 互動: \(payload.actions.first?.actionId ?? "unknown")")
        
        guard let action = payload.actions.first else {
            throw SlackWebhookError.invalidAction
        }
        
        switch action.actionId {
        case "approve_article":
            return try await handleApproveArticle(action: action, user: payload.user, responseUrl: payload.responseUrl)
            
        case "reject_article":
            return try await handleRejectArticle(action: action, user: payload.user, responseUrl: payload.responseUrl)
            
        default:
            throw SlackWebhookError.unknownAction(action.actionId)
        }
    }
    
    // MARK: - 私有方法
    
    /// 處理文章通過審核
    private func handleApproveArticle(action: SlackAction, user: SlackUser, responseUrl: String) async throws -> SlackResponse {
        let articleId = extractArticleId(from: action.value)
        
        guard let articleUUID = UUID(uuidString: articleId) else {
            throw SlackWebhookError.invalidArticleId
        }
        
        do {
            // 更新文章狀態為已發布
            let updatedArticle = try await supabaseService.reviewAndPublishAIArticle(
                articleUUID,
                approved: true,
                moderatorNotes: "由 \(user.name) 通過 Slack 審核通過"
            )
            
            // 記錄審核活動
            try await logReviewActivity(
                articleId: articleUUID,
                action: "approved",
                moderator: user.name,
                moderatorId: user.id
            )
            
            print("✅ [SlackWebhookService] 文章已審核通過: \(updatedArticle.title)")
            
            return SlackResponse(
                text: "文章審核結果",
                responseType: "in_channel",
                replaceOriginal: true,
                blocks: [
                    SlackBlock(
                        type: "section",
                        text: SlackText(
                            type: "mrkdwn",
                            text: "✅ *文章已通過審核並發布*\n\n*標題：* \(updatedArticle.title)\n*審核者：* \(user.name)\n*發布時間：* \(formatDate(updatedArticle.updatedAt))\n*狀態：* 已發布"
                        )
                    )
                ]
            )
            
        } catch {
            print("❌ [SlackWebhookService] 審核通過失敗: \(error.localizedDescription)")
            throw SlackWebhookError.approvalFailed(error.localizedDescription)
        }
    }
    
    /// 處理文章拒絕審核
    private func handleRejectArticle(action: SlackAction, user: SlackUser, responseUrl: String) async throws -> SlackResponse {
        let articleId = extractArticleId(from: action.value)
        
        guard let articleUUID = UUID(uuidString: articleId) else {
            throw SlackWebhookError.invalidArticleId
        }
        
        do {
            // 更新文章狀態為已歸檔
            let updatedArticle = try await supabaseService.reviewAndPublishAIArticle(
                articleUUID,
                approved: false,
                moderatorNotes: "由 \(user.name) 通過 Slack 審核拒絕"
            )
            
            // 記錄審核活動
            try await logReviewActivity(
                articleId: articleUUID,
                action: "rejected",
                moderator: user.name,
                moderatorId: user.id
            )
            
            print("❌ [SlackWebhookService] 文章已審核拒絕: \(updatedArticle.title)")
            
            return SlackResponse(
                text: "文章審核結果",
                responseType: "in_channel",
                replaceOriginal: true,
                blocks: [
                    SlackBlock(
                        type: "section",
                        text: SlackText(
                            type: "mrkdwn",
                            text: "❌ *文章已拒絕發布*\n\n*標題：* \(updatedArticle.title)\n*審核者：* \(user.name)\n*處理時間：* \(formatDate(updatedArticle.updatedAt))\n*狀態：* 已歸檔"
                        )
                    )
                ]
            )
            
        } catch {
            print("❌ [SlackWebhookService] 審核拒絕失敗: \(error.localizedDescription)")
            throw SlackWebhookError.rejectionFailed(error.localizedDescription)
        }
    }
    
    /// 從 action value 中提取文章 ID
    private func extractArticleId(from value: String) -> String {
        // value 格式: "approve_article_id" 或 "reject_article_id"
        let components = value.components(separatedBy: "_")
        return components.count > 1 ? components.dropFirst().joined(separator: "_") : value
    }
    
    /// 記錄審核活動
    private func logReviewActivity(articleId: UUID, action: String, moderator: String, moderatorId: String) async throws {
        print("📋 [SlackWebhookService] 記錄審核活動: \(articleId) - \(action) by \(moderator)")
        
        // 這裡可以擴展為將審核記錄保存到資料庫
        // 目前只記錄到系統日誌
    }
    
    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Slack Webhook 錯誤類型
enum SlackWebhookError: LocalizedError {
    case invalidPayload
    case invalidAction
    case unknownAction(String)
    case invalidArticleId
    case approvalFailed(String)
    case rejectionFailed(String)
    case authenticationFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "無效的 Slack 負載數據"
        case .invalidAction:
            return "無效的操作"
        case .unknownAction(let actionId):
            return "未知的操作: \(actionId)"
        case .invalidArticleId:
            return "無效的文章 ID"
        case .approvalFailed(let message):
            return "文章審核通過失敗: \(message)"
        case .rejectionFailed(let message):
            return "文章審核拒絕失敗: \(message)"
        case .authenticationFailed:
            return "身份驗證失敗"
        case .networkError(let message):
            return "網路錯誤: \(message)"
        }
    }
}

// MARK: - Webhook 路由處理器
struct SlackWebhookHandler {
    static func handleWebhookRequest(_ requestData: Data) async throws -> SlackResponse {
        do {
            // 解析 Slack 負載
            let payload = try JSONDecoder().decode(SlackInteractionPayload.self, from: requestData)
            
            // 處理互動
            return try await SlackWebhookService.shared.handleSlackInteraction(payload)
            
        } catch {
            print("❌ [SlackWebhookHandler] 處理 webhook 請求失敗: \(error.localizedDescription)")
            throw SlackWebhookError.invalidPayload
        }
    }
}