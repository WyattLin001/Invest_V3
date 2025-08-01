# n8n AI 投資文章自動化整合指南

## 📋 概述

本指南將詳細說明如何設置和配置 n8n 工作流程，實現 AI 投資文章的自動生成、審核和發布流程。

## 🔧 系統架構

```mermaid
graph TD
    A[每日 7AM 觸發器] --> B[設定新聞源]
    B --> C[拉取 RSS 新聞]
    C --> D[整合新聞摘要]
    D --> E[AI 生成投資分析]
    E --> F[文章後處理]
    F --> G[創建 AI 文章到 Supabase]
    G --> H[Slack 審核通知]
    H --> I[等待人工審核]
    I --> J[Webhook 處理審核結果]
    J --> K[更新文章狀態]
    K --> L[iOS App 顯示]
```

## ⚙️ 環境變數配置

在 n8n 中設置以下環境變數：

```bash
# Supabase 配置
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# AI 作者配置
AI_AUTHOR_ID=uuid-of-ai-author-account
AI_AUTHOR_NAME=AI 投資分析師

# OpenAI 配置
OPENAI_API_KEY=your-openai-api-key
OPENAI_MODEL=gpt-4

# Slack 配置
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_CHANNEL=#股圈-內容審核
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token

# 應用程式配置
APP_URL=https://your-app-domain.com
WEBHOOK_BASE_URL=https://your-n8n-instance.com
```

## 🔄 工作流程節點詳解

### 1. 每日觸發器 (Schedule Trigger)
```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "field": "days",
          "value": 1
        }
      ]
    },
    "triggerAtHour": 7,
    "triggerAtMinute": 0
  },
  "name": "每日 7AM 觸發",
  "type": "n8n-nodes-base.scheduleTrigger"
}
```

**用途**: 每天早上 7 點自動觸發工作流程
**配置重點**: 
- 設定台灣時區 (Asia/Taipei)
- 確保觸發時間符合市場開盤前的需求

### 2. 新聞源設定 (Function Node)
```javascript
// 設定多個新聞來源
const newsSources = [
  {
    name: "鉅亨網",
    url: "https://news.cnyes.com/rss/tw",
    category: "台股"
  },
  {
    name: "經濟日報",
    url: "https://money.udn.com/rssfeed/news/1001/5591",
    category: "財經"
  },
  {
    name: "工商時報",
    url: "https://ctee.com.tw/feed",
    category: "產業"
  }
];

// 輪流選擇新聞源或隨機選擇
const selectedSource = newsSources[Math.floor(Math.random() * newsSources.length)];

return [
  {
    json: {
      source: selectedSource.name,
      url: selectedSource.url,
      category: selectedSource.category,
      timestamp: new Date().toISOString()
    }
  }
];
```

### 3. RSS 新聞抓取 (RSS Feed Read)
```json
{
  "parameters": {
    "resource": "feedItems",
    "operation": "getAll",
    "url": "={{ $json.url }}",
    "limit": 5,
    "options": {
      "ignoreSSL": true
    }
  },
  "name": "拉取 RSS 新聞",
  "type": "n8n-nodes-base.rssFeedRead"
}
```

**配置重點**:
- 限制抓取數量避免過載
- 處理 SSL 憑證問題
- 支援中文內容編碼

### 4. 新聞摘要整合 (Function Node)
```javascript
// 整合多篇新聞為 AI 分析用的素材
const items = $input.all();
let newsContent = "";
let keywords = new Set();

items.forEach((item, index) => {
  const news = item.json;
  newsContent += `
新聞 ${index + 1}:
標題: ${news.title}
摘要: ${news.contentSnippet || news.description}
發布時間: ${news.pubDate}
來源: ${news.creator || '未知'}
連結: ${news.link}

---
`;

  // 提取關鍵字
  const titleWords = news.title.match(/[\u4e00-\u9fa5]+/g) || [];
  titleWords.forEach(word => {
    if (word.length >= 2) keywords.add(word);
  });
});

// 計算字數和預估閱讀時間
const wordCount = newsContent.length;
const readTime = Math.max(1, Math.ceil(wordCount / 300)) + " 分鐘";

return [
  {
    json: {
      newsContent: newsContent,
      keywords: Array.from(keywords).slice(0, 10),
      wordCount: wordCount,
      readTime: readTime,
      sourceCount: items.length,
      processedAt: new Date().toISOString()
    }
  }
];
```

### 5. AI 內容生成 (OpenAI Node)
```json
{
  "parameters": {
    "resource": "text",
    "operation": "message",
    "model": "gpt-4",
    "options": {
      "temperature": 0.7,
      "maxTokens": 1500,
      "topP": 1,
      "frequencyPenalty": 0.1,
      "presencePenalty": 0.1
    },
    "prompt": "你是一位專業的投資分析師，請基於以下新聞內容，撰寫一篇專業的投資分析文章：\n\n新聞內容：\n{{ $json.newsContent }}\n\n請按以下格式撰寫：\n\n# 標題（吸引人且專業）\n\n## 市場概況\n[分析當前市場狀況]\n\n## 重點關注\n[列出值得關注的重點]\n\n## 投資建議\n[提供客觀的投資觀點，避免直接建議]\n\n## 風險提醒\n[必須包含風險警示]\n\n要求：\n1. 語調專業客觀\n2. 內容具有實用價值\n3. 避免過度樂觀或悲觀\n4. 必須包含風險警示\n5. 字數控制在 800-1200 字\n6. 使用繁體中文"
  },
  "name": "AI 生成投資分析",
  "type": "n8n-nodes-base.openAi"
}
```

**重要配置**:
- **Temperature**: 0.7 (保持創意但不過於隨機)
- **MaxTokens**: 1500 (控制文章長度)
- **提示詞工程**: 確保輸出格式和品質

### 6. 文章後處理 (Function Node)
```javascript
const aiContent = $json.message.content;

// 解析 AI 生成的內容
const lines = aiContent.split('\n');
let title = "";
let content = aiContent;
let summary = "";

// 提取標題
for (let line of lines) {
  if (line.startsWith('# ')) {
    title = line.replace('# ', '').trim();
    break;
  }
}

// 如果沒找到標題，使用預設格式
if (!title) {
  title = `AI 市場分析 - ${new Date().toLocaleDateString('zh-TW')}`;
}

// 生成摘要（取前 200 字）
const plainText = content.replace(/#{1,6}\s/g, '').replace(/\*\*/g, '');
summary = plainText.substring(0, 200).trim();
if (summary.length === 200) {
  summary += "...";
}

// 提取和過濾關鍵字
const extractedKeywords = [];
const keywordRegex = /[\u4e00-\u9fa5]{2,}/g;
const matches = content.match(keywordRegex) || [];

// 常見投資相關關鍵字
const investmentKeywords = ['股市', '投資', '分析', '市場', '股票', '基金', '風險', '獲利', '趨勢', '經濟'];
matches.forEach(word => {
  if (investmentKeywords.includes(word) && !extractedKeywords.includes(word)) {
    extractedKeywords.push(word);
  }
});

// 補充預設關鍵字
if (extractedKeywords.length < 3) {
  extractedKeywords.push('AI分析', '投資洞察', '市場趨勢');
}

// 計算成本（粗略估算）
const inputTokens = Math.ceil(($('AI 生成投資分析').json.prompt?.length || 0) / 4);
const outputTokens = Math.ceil(aiContent.length / 4);
const estimatedCost = (inputTokens * 0.00003 + outputTokens * 0.00006).toFixed(4);

return [
  {
    json: {
      title: title,
      content: content,
      summary: summary,
      keywords: extractedKeywords.slice(0, 5),
      word_count: content.length,
      read_time: Math.max(1, Math.ceil(content.length / 300)) + " 分鐘",
      generation_cost: estimatedCost,
      created_at: new Date().toISOString(),
      article_id: null // 將在 Supabase 創建後填入
    }
  }
];
```

### 7. 創建 AI 文章 (Supabase Node)
```json
{
  "parameters": {
    "schema": "public",
    "table": "articles",
    "operation": "insert",
    "records": [
      {
        "title": "={{ $json.title }}",
        "author": "{{ $env.AI_AUTHOR_NAME }}",
        "author_id": "{{ $env.AI_AUTHOR_ID }}",
        "summary": "={{ $json.summary }}",
        "full_content": "={{ $json.content }}",
        "body_md": "={{ $json.content }}",
        "category": "每日市場分析",
        "read_time": "={{ $json.read_time }}",
        "is_free": false,
        "status": "draft",
        "source": "ai",
        "keywords": "={{ $json.keywords }}",
        "likes_count": 0,
        "comments_count": 0,
        "shares_count": 0
      }
    ],
    "options": {
      "returnFields": "id,title,created_at"
    }
  },
  "name": "創建 AI 文章",
  "type": "n8n-nodes-base.supabase"
}
```

**重要配置**:
- **狀態**: 預設為 "draft" 等待審核
- **來源**: 標記為 "ai" 識別
- **作者ID**: 使用環境變數中的 AI 作者 ID
- **返回欄位**: 獲取新創建的文章 ID

### 8. Slack 審核通知 (Slack Node)
```json
{
  "parameters": {
    "channel": "{{ $env.SLACK_CHANNEL }}",
    "text": "🤖 AI 投資分析已自動生成，請審核：",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*📝 新的 AI 投資分析待審核*\n\n*標題：* {{ $('文章後處理').json.title }}\n*分類：* 每日市場分析\n*字數：* {{ $('文章後處理').json.word_count }} 字\n*閱讀時間：* {{ $('文章後處理').json.read_time }}\n*生成時間：* {{ $('文章後處理').json.created_at }}\n*文章 ID：* {{ $('創建 AI 文章').json.id }}"
        }
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*摘要：*\n{{ $('文章後處理').json.summary }}"
        }
      },
      {
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "✅ 通過發布"
            },
            "style": "primary",
            "value": "approve_{{ $('創建 AI 文章').json.id }}",
            "action_id": "approve_article",
            "url": "{{ $env.WEBHOOK_BASE_URL }}/webhook/slack-review"
          },
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "❌ 拒絕發布"
            },
            "style": "danger",
            "value": "reject_{{ $('創建 AI 文章').json.id }}",
            "action_id": "reject_article",
            "url": "{{ $env.WEBHOOK_BASE_URL }}/webhook/slack-review"
          },
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "👀 預覽文章"
            },
            "url": "{{ $env.APP_URL }}/articles/{{ $('創建 AI 文章').json.id }}",
            "action_id": "preview_article"
          }
        ]
      }
    ],
    "otherOptions": {
      "includeLinkToWorkflow": false
    }
  },
  "name": "Slack 審核通知",
  "type": "n8n-nodes-base.slack"
}
```

## 🔗 審核 Webhook 設置

### 創建 Slack 審核 Webhook
在 n8n 中創建一個新的工作流程來處理 Slack 的審核響應：

```json
{
  "name": "Slack 審核 Webhook 處理器",
  "nodes": [
    {
      "parameters": {
        "path": "slack-review",
        "options": {}
      },
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "position": [240, 300]
    },
    {
      "parameters": {
        "functionCode": "// 解析 Slack 負載\nconst payload = JSON.parse($json.body.payload);\nconst action = payload.actions[0];\nconst user = payload.user;\nconst articleId = action.value.split('_')[1];\nconst approved = action.action_id === 'approve_article';\n\nreturn [\n  {\n    json: {\n      articleId: articleId,\n      approved: approved,\n      moderator: user.name,\n      moderatorId: user.id,\n      responseUrl: payload.response_url,\n      timestamp: new Date().toISOString()\n    }\n  }\n];"
      },
      "name": "解析審核結果",
      "type": "n8n-nodes-base.function",
      "position": [460, 300]
    },
    {
      "parameters": {
        "schema": "public",
        "table": "articles",
        "operation": "update",
        "filterType": "manual",
        "matchingColumns": [
          {
            "column": "id",
            "value": "={{ $json.articleId }}"
          }
        ],
        "columnsUi": {
          "columnToMatchOn": [
            {
              "column": "status",
              "value": "={{ $json.approved ? 'published' : 'archived' }}"
            },
            {
              "column": "updated_at",
              "value": "={{ $json.timestamp }}"
            }
          ]
        }
      },
      "name": "更新文章狀態",
      "type": "n8n-nodes-base.supabase",
      "position": [680, 300]
    },
    {
      "parameters": {
        "url": "={{ $json.responseUrl }}",
        "sendBody": true,
        "bodyContentType": "json",
        "jsonBody": "{\n  \"text\": \"文章審核結果\",\n  \"response_type\": \"in_channel\",\n  \"replace_original\": true,\n  \"blocks\": [\n    {\n      \"type\": \"section\",\n      \"text\": {\n        \"type\": \"mrkdwn\",\n        \"text\": \"{{ $json.approved ? '✅ *文章已通過審核並發布*' : '❌ *文章已拒絕發布*' }}\\n\\n*審核者：* {{ $json.moderator }}\\n*處理時間：* {{ $json.timestamp }}\\n*狀態：* {{ $json.approved ? '已發布' : '已歸檔' }}\"\n      }\n    }\n  ]\n}",
        "options": {}
      },
      "name": "回應 Slack",
      "type": "n8n-nodes-base.httpRequest",
      "position": [900, 300]
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [
          {
            "node": "解析審核結果",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "解析審核結果": {
      "main": [
        [
          {
            "node": "更新文章狀態",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "更新文章狀態": {
      "main": [
        [
          {
            "node": "回應 Slack",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  }
}
```

## 🔐 Slack App 配置

### 1. 創建 Slack App
```bash
# 前往 https://api.slack.com/apps
# 點擊 "Create New App" > "From scratch"
```

### 2. 配置權限 (OAuth & Permissions)
```
Bot Token Scopes:
- chat:write
- chat:write.public
- channels:read
- groups:read
- users:read

User Token Scopes:
- channels:read
- groups:read
```

### 3. 啟用 Interactive Components
```
Request URL: https://your-n8n-instance.com/webhook/slack-review
```

### 4. 安裝到工作區
```bash
# 在 "Install App" 頁面點擊 "Install to Workspace"
# 複製 Bot User OAuth Token 到環境變數 SLACK_BOT_TOKEN
```

## 📊 監控和調試

### 1. n8n 執行記錄
```bash
# 檢查工作流程執行狀態
GET /api/v1/executions

# 查看特定執行的詳細記錄
GET /api/v1/executions/{executionId}
```

### 2. 錯誤處理節點
在關鍵節點後添加錯誤處理：

```javascript
// 錯誤處理 Function Node
try {
  // 主要邏輯
  const result = processData($json);
  return [{ json: result }];
} catch (error) {
  // 錯誤通知
  const errorData = {
    error: error.message,
    node: 'AI 內容生成',
    timestamp: new Date().toISOString(),
    input: $json
  };
  
  // 發送錯誤通知到 Slack
  return [{ json: errorData }];
}
```

### 3. 成功率監控
添加統計節點追蹤成功率：

```javascript
// 統計 Function Node
const stats = {
  workflow: 'AI 文章生成',
  status: 'success', // or 'error'
  execution_time: new Date().toISOString(),
  article_id: $json.id,
  word_count: $json.word_count,
  generation_cost: $json.generation_cost
};

// 保存到監控表或發送到監控服務
return [{ json: stats }];
```

## 🚀 部署步驟

### 1. 準備環境變數
```bash
# 在 n8n 設定中添加所有必要的環境變數
# Settings > Environment variables
```

### 2. 匯入工作流程
```bash
# 使用提供的 JSON 檔案匯入工作流程
# Workflows > Import from file > 選擇 JSON 檔案
```

### 3. 測試配置
```bash
# 手動執行一次工作流程
# 檢查每個節點的輸出
# 確認 Slack 通知正常接收
```

### 4. 啟用排程
```bash
# 確認觸發器設定正確
# 啟用工作流程自動執行
```

## 🔧 故障排除

### 常見問題及解決方案

1. **RSS 抓取失敗**
   ```
   解決: 檢查 RSS URL 是否有效，嘗試不同的新聞源
   ```

2. **AI 生成超時**
   ```
   解決: 降低 maxTokens 設定，或使用更快的模型
   ```

3. **Slack 通知失敗**
   ```
   解決: 確認 Bot Token 權限，檢查頻道名稱
   ```

4. **Supabase 連接問題**
   ```
   解決: 驗證 API Key 和 URL，檢查資料表結構
   ```

---

## 📞 技術支援

如遇到設定問題，請檢查：
1. 所有環境變數是否正確設定
2. Slack App 權限是否完整
3. Supabase 資料表結構是否已更新
4. n8n 版本是否支援所使用的節點

完成設定後，系統將每日自動生成高品質的 AI 投資分析文章！🚀