import React, { useState, useEffect, useRef, useCallback } from 'react';
import './StockSearch.css'; // 對應的 CSS 檔案

const StockSearch = ({
  apiUrl = 'http://localhost:5001/api/taiwan-stocks/search',
  placeholder = '請輸入股票代號或公司名稱...',
  maxResults = 20,
  debounceDelay = 250,
  onStockSelected = null
}) => {
  // 狀態管理
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const [isLoading, setIsLoading] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [error, setError] = useState(null);
  const [searchStats, setSearchStats] = useState('');

  // Refs
  const inputRef = useRef(null);
  const suggestionsRef = useRef(null);
  const debounceTimerRef = useRef(null);

  // 防抖搜尋
  const debouncedSearch = useCallback((searchQuery) => {
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    debounceTimerRef.current = setTimeout(() => {
      if (searchQuery.trim()) {
        searchStocks(searchQuery.trim());
      } else {
        setSuggestions([]);
        setShowSuggestions(false);
        setSearchStats('');
      }
    }, debounceDelay);
  }, [debounceDelay]);

  // API 搜尋
  const searchStocks = async (searchQuery) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${apiUrl}?q=${encodeURIComponent(searchQuery)}&limit=${maxResults}`
      );

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();
      const stocks = normalizeApiResponse(data);
      
      setSuggestions(stocks);
      setShowSuggestions(true);
      setSelectedIndex(-1);
      setSearchStats(stocks.length > 0 ? `找到 ${stocks.length} 筆相關股票` : '');

    } catch (err) {
      console.error('搜尋失敗:', err);
      setError('搜尋失敗，請稍後重試');
      setSuggestions([]);
      setShowSuggestions(true);
      setSearchStats('');
    } finally {
      setIsLoading(false);
    }
  };

  // 標準化 API 回應
  const normalizeApiResponse = (data) => {
    if (Array.isArray(data)) {
      return data;
    } else if (data.stocks && Array.isArray(data.stocks)) {
      return data.stocks;
    } else if (data.data && Array.isArray(data.data)) {
      return data.data;
    } else {
      return [];
    }
  };

  // 高亮關鍵字
  const highlightMatch = (text, searchQuery) => {
    if (!searchQuery || !text) return text;
    
    const regex = new RegExp(`(${escapeRegex(searchQuery)})`, 'gi');
    const parts = text.split(regex);
    
    return parts.map((part, index) => 
      regex.test(part) ? 
        <span key={index} className="highlight">{part}</span> : 
        part
    );
  };

  const escapeRegex = (string) => {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  };

  // 輸入處理
  const handleInputChange = (e) => {
    const value = e.target.value;
    setQuery(value);
    setSelectedIndex(-1);
    debouncedSearch(value);
  };

  // 鍵盤事件處理
  const handleKeyDown = (e) => {
    if (!showSuggestions || suggestions.length === 0) return;

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex(prev => Math.min(prev + 1, suggestions.length - 1));
        break;
        
      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex(prev => Math.max(prev - 1, -1));
        break;
        
      case 'Enter':
        e.preventDefault();
        if (selectedIndex >= 0) {
          selectSuggestion(selectedIndex);
        }
        break;
        
      case 'Escape':
        setShowSuggestions(false);
        inputRef.current?.blur();
        break;
    }
  };

  // 選擇建議
  const selectSuggestion = (index) => {
    if (index < 0 || index >= suggestions.length) return;

    const stock = suggestions[index];
    const symbol = stock.symbol || stock.code || '';
    const name = stock.name || '';
    const fullText = `${symbol} ${name}`;

    setQuery(fullText);
    setShowSuggestions(false);
    setSearchStats(`已選擇: ${fullText}`);

    // 回調函數
    if (onStockSelected) {
      onStockSelected({ stock, fullText });
    }
  };

  // 滾動到選中項目
  useEffect(() => {
    if (selectedIndex >= 0 && suggestionsRef.current) {
      const selectedElement = suggestionsRef.current.children[selectedIndex];
      if (selectedElement) {
        selectedElement.scrollIntoView({
          block: 'nearest',
          behavior: 'smooth'
        });
      }
    }
  }, [selectedIndex]);

  // 清理定時器
  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
    };
  }, []);

  return (
    <div className="stock-search-container">
      <div className="search-header">
        <h1>🔍 台灣股票搜尋</h1>
        <p>輸入股票代號或公司名稱，例如：2330、台積電、0050、元大</p>
      </div>

      <div className="search-input-wrapper">
        <div className="search-icon">🔍</div>
        <input
          ref={inputRef}
          type="text"
          className="search-input"
          placeholder={placeholder}
          value={query}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          onBlur={() => setTimeout(() => setShowSuggestions(false), 150)}
          autoComplete="off"
          spellCheck="false"
        />
        {isLoading && (
          <div className="loading-indicator">
            <div className="loading-spinner"></div>
          </div>
        )}
      </div>

      {showSuggestions && (
        <div className="suggestions-container">
          <div ref={suggestionsRef}>
            {error ? (
              <div className="no-results">
                <div>⚠️ {error}</div>
              </div>
            ) : suggestions.length === 0 && query ? (
              <div className="no-results">
                <div>😔 找不到相關股票</div>
                <div style={{ marginTop: '8px', fontSize: '11px' }}>
                  試試輸入：2330、台積電、0050、元大
                </div>
              </div>
            ) : (
              suggestions.map((stock, index) => {
                const symbol = stock.symbol || stock.code || '';
                const name = stock.name || '';
                
                return (
                  <div
                    key={`${symbol}-${index}`}
                    className={`suggestion-item ${index === selectedIndex ? 'active' : ''}`}
                    onClick={() => selectSuggestion(index)}
                  >
                    <div className="suggestion-main">
                      <div className="suggestion-symbol">
                        {highlightMatch(symbol, query)}
                      </div>
                      <div className="suggestion-name">
                        {highlightMatch(name, query)}
                      </div>
                    </div>
                    <div className="suggestion-full">{symbol}</div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      <div className="search-stats">{searchStats}</div>
      <div className="keyboard-hint">
        💡 使用 ↑↓ 鍵選擇，Enter 確認，ESC 關閉
      </div>
    </div>
  );
};

export default StockSearch;