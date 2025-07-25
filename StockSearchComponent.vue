<template>
  <div ref="containerRef" class="stock-search-container">
    <div class="search-header">
      <h1>🔍 台灣股票搜尋</h1>
      <p>輸入股票代號或公司名稱，例如：2330、台積電、0050、元大</p>
    </div>

    <div class="search-input-wrapper">
      <div class="search-icon">🔍</div>
      <input
        ref="inputRef"
        v-model="query"
        type="text"
        class="search-input"
        :class="{ 'has-error': error }"
        :placeholder="placeholder"
        @keydown="handleKeyDown"
        @focus="handleFocus"
        autocomplete="off"
        spellcheck="false"
        :aria-busy="isLoading"
      />
      <div v-if="isLoading" class="loading-indicator">
        <div class="loading-spinner"></div>
      </div>
    </div>

    <!-- 錯誤訊息獨立顯示 -->
    <div v-if="error" class="error-message">
      ⚠️ {{ error }}
    </div>

    <div v-show="showSuggestions" class="suggestions-container">
      <div ref="suggestionsRef">
        <div v-if="suggestions.length === 0 && query && !isLoading" class="no-results">
          <div>😔 找不到相關股票</div>
          <div style="margin-top: 8px; font-size: 11px;">
            試試輸入：2330、台積電、0050、元大
          </div>
        </div>
        <div
          v-else
          v-for="(stock, index) in suggestions"
          :key="`${stock.symbol}-${index}`"
          :class="['suggestion-item', { active: index === selectedIndex }]"
          @click="selectSuggestion(index)"
        >
          <div class="suggestion-main">
            <div class="suggestion-symbol" v-html="highlightMatch(stock.symbol, query)"></div>
            <div class="suggestion-name" v-html="highlightMatch(stock.name, query)"></div>
          </div>
          <div class="suggestion-full">{{ stock.symbol }}</div>
        </div>
      </div>
    </div>

    <div class="search-stats">{{ searchStats }}</div>
    <div class="keyboard-hint">
      💡 使用 ↑↓ 鍵選擇，Enter 確認，ESC 關閉
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, nextTick } from 'vue'
import { useDebounceFn, useClickOutside } from '@vueuse/core'

// Props
const props = defineProps({
  apiUrl: {
    type: String,
    default: 'http://localhost:5001/api/taiwan-stocks/search'
  },
  placeholder: {
    type: String,
    default: '請輸入股票代號或公司名稱...'
  },
  maxResults: {
    type: Number,
    default: 20
  },
  debounceDelay: {
    type: Number,
    default: 250
  },
  immediate: {
    type: Boolean,
    default: false
  }
})

// Emits
const emit = defineEmits(['stockSelected'])

// Reactive state
const query = ref('')
const suggestions = ref([])
const selectedIndex = ref(-1)
const isLoading = ref(false)
const showSuggestions = ref(false)
const error = ref(null)
const searchStats = ref('')

// Refs
const inputRef = ref(null)
const suggestionsRef = ref(null)
const containerRef = ref(null)

// 點擊外部關閉建議列表
useClickOutside(containerRef, () => {
  showSuggestions.value = false
})

// Methods
const searchStocks = async (searchQuery) => {
  if (!searchQuery) {
    suggestions.value = []
    showSuggestions.value = false
    searchStats.value = ''
    error.value = null
    return
  }

  isLoading.value = true
  error.value = null

  try {
    const response = await fetch(
      `${props.apiUrl}?q=${encodeURIComponent(searchQuery)}&limit=${props.maxResults}`
    )

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`)
    }

    const data = await response.json()
    // 簡化 API 回應處理 - 優先使用 stocks 欄位
    const stocks = data.stocks || data.data || (Array.isArray(data) ? data : [])
    
    suggestions.value = stocks
    showSuggestions.value = true
    selectedIndex.value = -1
    searchStats.value = stocks.length > 0 ? `找到 ${stocks.length} 筆相關股票` : ''

  } catch (err) {
    console.error('搜尋失敗:', err)
    error.value = '搜尋失敗，請稍後重試'
    suggestions.value = []
    showSuggestions.value = false
    searchStats.value = ''
  } finally {
    isLoading.value = false
  }
}

// 預載熱門股票（immediate mode）
const loadPopularStocks = async () => {
  try {
    const response = await fetch(`${props.apiUrl}?limit=${props.maxResults}`)
    if (response.ok) {
      const data = await response.json()
      const stocks = data.stocks || data.data || (Array.isArray(data) ? data : [])
      suggestions.value = stocks
      searchStats.value = `顯示熱門股票 ${stocks.length} 支`
    }
  } catch (err) {
    console.warn('載入熱門股票失敗:', err)
  }
}

// 使用 VueUse 的防抖動函數
const debouncedSearch = useDebounceFn((searchQuery) => {
  searchStocks(searchQuery)
}, props.debounceDelay)

const highlightMatch = (text, searchQuery) => {
  if (!searchQuery || !text) return text
  
  const regex = new RegExp(`(${escapeRegex(searchQuery)})`, 'gi')
  return text.replace(regex, '<span class="highlight">$1</span>')
}

const escapeRegex = (string) => {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

const handleKeyDown = (e) => {
  if (!showSuggestions.value || suggestions.value.length === 0) return

  switch (e.key) {
    case 'ArrowDown':
      e.preventDefault()
      selectedIndex.value = Math.min(selectedIndex.value + 1, suggestions.value.length - 1)
      scrollToSelected()
      break
      
    case 'ArrowUp':
      e.preventDefault()
      selectedIndex.value = Math.max(selectedIndex.value - 1, -1)
      scrollToSelected()
      break
      
    case 'Enter':
      e.preventDefault()
      if (selectedIndex.value >= 0) {
        selectSuggestion(selectedIndex.value)
      }
      break
      
    case 'Escape':
      showSuggestions.value = false
      inputRef.value?.blur()
      break
  }
}

const handleFocus = () => {
  if (suggestions.value.length > 0) {
    showSuggestions.value = true
  }
}

const selectSuggestion = (index) => {
  if (index < 0 || index >= suggestions.value.length) return

  const stock = suggestions.value[index]
  const symbol = stock.symbol
  
  // 優化：只填入股票代號，保持輸入框純粹
  query.value = symbol
  showSuggestions.value = false
  searchStats.value = `已選擇: ${symbol} ${stock.name}`

  // 發出事件，包含完整股票資訊
  emit('stockSelected', { 
    stock, 
    symbol,
    fullText: `${symbol} ${stock.name}`
  })
}

const scrollToSelected = async () => {
  await nextTick()
  
  if (selectedIndex.value >= 0 && suggestionsRef.value) {
    const selectedElement = suggestionsRef.value.children[selectedIndex.value]
    if (selectedElement) {
      selectedElement.scrollIntoView({
        block: 'nearest',
        behavior: 'smooth'
      })
    }
  }
}

// Watchers
watch(query, (newQuery) => {
  const trimmedQuery = newQuery.trim()
  selectedIndex.value = -1
  
  if (!trimmedQuery) {
    suggestions.value = []
    showSuggestions.value = false
    searchStats.value = ''
    error.value = null
    // 如果 immediate 模式且清空輸入，顯示熱門股票
    if (props.immediate) {
      loadPopularStocks()
    }
  } else {
    debouncedSearch(trimmedQuery)
  }
})

// Lifecycle
onMounted(() => {
  // immediate 模式預載熱門股票
  if (props.immediate) {
    loadPopularStocks()
  }
})
</script>

<style scoped>
* {
  box-sizing: border-box;
}

.stock-search-container {
  max-width: 600px;
  margin: 0 auto;
  position: relative;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.search-header {
  text-align: center;
  margin-bottom: 30px;
}

.search-header h1 {
  color: #2c3e50;
  margin-bottom: 10px;
  font-size: 24px;
}

.search-header p {
  color: #7f8c8d;
  font-size: 14px;
  margin: 0;
}

.search-input-wrapper {
  position: relative;
  margin-bottom: 10px;
}

.search-input {
  width: 100%;
  padding: 16px 20px 16px 50px;
  font-size: 16px;
  border: 2px solid #e1e8ed;
  border-radius: 12px;
  outline: none;
  transition: all 0.3s ease;
  background-color: white;
  box-shadow: 0 2px 10px rgba(0,0,0,0.08);
}

.search-input:focus {
  border-color: #3498db;
  box-shadow: 0 4px 20px rgba(52, 152, 219, 0.15);
}

.search-input.has-error {
  border-color: #e74c3c;
  box-shadow: 0 4px 20px rgba(231, 76, 60, 0.15);
}

.search-icon {
  position: absolute;
  left: 16px;
  top: 50%;
  transform: translateY(-50%);
  color: #95a5a6;
  font-size: 18px;
}

.loading-indicator {
  position: absolute;
  right: 16px;
  top: 50%;
  transform: translateY(-50%);
}

.loading-spinner {
  width: 20px;
  height: 20px;
  border: 2px solid #f3f3f3;
  border-top: 2px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

.error-message {
  color: #e74c3c;
  font-size: 14px;
  margin-bottom: 10px;
  padding: 8px 16px;
  background-color: #fdf2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.suggestions-container {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: white;
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.12);
  max-height: 400px;
  overflow-y: auto;
  z-index: 1000;
  border: 1px solid #e1e8ed;
}

.suggestion-item {
  padding: 16px 20px;
  cursor: pointer;
  border-bottom: 1px solid #f8f9fa;
  transition: background-color 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.suggestion-item:last-child {
  border-bottom: none;
}

.suggestion-item:hover {
  background-color: #f8f9fa;
}

.suggestion-item.active {
  background-color: #3498db;
  color: white;
}

.suggestion-main {
  display: flex;
  flex-direction: column;
  flex: 1;
}

.suggestion-symbol {
  font-weight: 600;
  font-size: 16px;
  color: #2c3e50;
  margin-bottom: 2px;
}

.suggestion-item.active .suggestion-symbol {
  color: white;
}

.suggestion-name {
  font-size: 14px;
  color: #7f8c8d;
}

.suggestion-item.active .suggestion-name {
  color: rgba(255,255,255,0.9);
}

.suggestion-full {
  font-size: 14px;
  color: #95a5a6;
  margin-left: 10px;
}

.suggestion-item.active .suggestion-full {
  color: rgba(255,255,255,0.8);
}

:deep(.highlight) {
  background-color: #f39c12;
  color: #2c3e50;
  padding: 1px 3px;
  border-radius: 3px;
  font-weight: 700;
}

.suggestion-item.active :deep(.highlight) {
  background-color: rgba(255,255,255,0.25);
  color: white;
  font-weight: 700;
}

.no-results {
  padding: 20px;
  text-align: center;
  color: #7f8c8d;
  font-style: italic;
}

.search-stats {
  margin-top: 10px;
  font-size: 12px;
  color: #95a5a6;
  text-align: center;
}

.keyboard-hint {
  margin-top: 10px;
  font-size: 12px;
  color: #bdc3c7;
  text-align: center;
}

/* 響應式設計 */
@media (max-width: 600px) {
  .stock-search-container {
    margin: 0 10px;
  }
  
  .search-input {
    padding: 14px 16px 14px 45px;
    font-size: 16px; /* 防止 iOS 縮放 */
  }
  
  .suggestions-container {
    max-height: 300px;
  }
}
</style>