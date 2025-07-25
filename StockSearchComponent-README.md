# Vue 3 台股搜尋組件使用說明

## 📦 安裝依賴

```bash
npm install @vueuse/core
# 或
yarn add @vueuse/core
```

## 🚀 基本使用

```vue
<template>
  <div>
    <StockSearchComponent 
      @stock-selected="handleStockSelected"
      :immediate="true"
    />
  </div>
</template>

<script setup>
import StockSearchComponent from './StockSearchComponent.vue'

const handleStockSelected = ({ stock, symbol, fullText }) => {
  console.log('選擇的股票:', { stock, symbol, fullText })
  // 處理選擇的股票...
}
</script>
```

## 🔧 Props 配置

| 屬性 | 類型 | 預設值 | 說明 |
|------|------|--------|------|
| `apiUrl` | String | `'http://localhost:5001/api/taiwan-stocks/search'` | API 端點 |
| `placeholder` | String | `'請輸入股票代號或公司名稱...'` | 輸入框提示文字 |
| `maxResults` | Number | `20` | 最大搜尋結果數量 |
| `debounceDelay` | Number | `250` | 防抖動延遲時間（毫秒） |
| `immediate` | Boolean | `false` | 是否預載熱門股票 |

## 📡 Events

### `@stock-selected`

當用戶選擇股票時觸發，回傳參數：

```javascript
{
  stock: {
    symbol: "2330",
    name: "台積電",
    // ... 其他股票資訊
  },
  symbol: "2330",          // 股票代號
  fullText: "2330 台積電"   // 完整顯示文字
}
```

## ✨ 主要功能改進

### 1. VueUse 整合
- ✅ 使用 `useDebounceFn` 替代手動防抖動
- ✅ 使用 `useClickOutside` 改善外部點擊處理
- ✅ 自動清理定時器和事件監聽器

### 2. 用戶體驗提升
- ✅ 輸入框只顯示股票代號，保持簡潔
- ✅ 錯誤訊息獨立顯示區域
- ✅ 加入 `aria-busy` 無障礙屬性
- ✅ `immediate` 模式預載熱門股票

### 3. 性能優化
- ✅ 簡化 API 回應處理邏輯
- ✅ 優化搜尋結果快取機制
- ✅ 減少不必要的 DOM 操作

### 4. 樣式改進
- ✅ 高亮對比度優化（從黃色改為橙色）
- ✅ 陰影效果柔化
- ✅ 加入錯誤狀態視覺指示

## 🎯 使用範例

### 基本搜尋
```vue
<StockSearchComponent 
  @stock-selected="onStockSelect"
/>
```

### 預載熱門股票
```vue
<StockSearchComponent 
  :immediate="true"
  @stock-selected="onStockSelect"
/>
```

### 自定義配置
```vue
<StockSearchComponent 
  api-url="https://api.example.com/stocks/search"
  :max-results="10"
  :debounce-delay="300"
  placeholder="搜尋台股..."
  @stock-selected="onStockSelect"
/>
```

## 🔧 開發說明

### API 回應格式

組件支援多種 API 回應格式：

```javascript
// 格式 1: 直接陣列
[
  { symbol: "2330", name: "台積電" },
  // ...
]

// 格式 2: stocks 欄位
{
  stocks: [
    { symbol: "2330", name: "台積電" },
    // ...
  ]
}

// 格式 3: data 欄位
{
  data: [
    { symbol: "2330", name: "台積電" },
    // ...
  ]
}
```

### 鍵盤快捷鍵
- `↑/↓` 箭頭鍵：選擇建議項目
- `Enter`：確認選擇
- `ESC`：關閉建議列表

### 響應式設計
- 桌面版：600px 最大寬度
- 行動版：自適應寬度，防止 iOS 縮放

## 🔄 版本差異

| 版本 | 主要特色 |
|------|----------|
| 原版 | 手動防抖動、setTimeout 外部點擊處理 |
| 優化版 | VueUse 整合、性能提升、用戶體驗改善 |

## 📝 備註

1. 確保後端 API 支援 CORS 跨域請求
2. 推薦使用 HTTPS 連線提升安全性
3. 考慮加入請求快取機制以減少 API 調用
4. 可根據需求自定義樣式主題