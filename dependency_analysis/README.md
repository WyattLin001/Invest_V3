# 📱 Invest_V3 Code Dependency Visualization

> **全面的 iOS Swift 專案依賴關係視覺化工具套件**
> 
> **專為 Invest_V3 台灣去中心化投資競賽平台設計**

## 🎯 工具概覽

這套工具提供了多種方式來分析和視覺化您的 iOS Swift 專案的代碼依賴關係：

### 🔍 **1. Swift 依賴分析器**
- **檔案**: `swift_dependency_analyzer.py`
- **功能**: 深度分析 Swift 檔案間的依賴關係
- **輸出**: JSON 數據、Markdown 報告、統計圖表

### 🎨 **2. Graphviz 圖表生成器** 
- **檔案**: `graphviz_generator.py`
- **功能**: 生成專業級的依賴關係圖表
- **輸出**: PNG/SVG/PDF 格式的視覺化圖表

### 📊 **3. 實時監控儀表板**
- **檔案**: `dependency_dashboard.py`
- **功能**: Web 介面的互動式依賴分析工具
- **特色**: 實時更新、多維度視覺化

### 🔧 **4. VS Code 整合**
- **檔案**: `vscode_integration.py`
- **功能**: 無縫整合到 VS Code 開發環境
- **特色**: 一鍵執行、偵錯支援

## 🚀 快速開始

### 方法一：一鍵執行（推薦）
```bash
# 1. 進入專案目錄
cd /path/to/Invest_V3

# 2. 執行主程式（互動模式）
python3 dependency_analysis/run_analysis.py

# 3. 或自動執行完整分析
python3 dependency_analysis/run_analysis.py --auto
```

### 方法二：手動安裝
```bash
# 1. 安裝依賴
bash dependency_analysis/install_dependencies.sh

# 2. 執行分析
python3 dependency_analysis/swift_dependency_analyzer.py

# 3. 生成圖表
python3 dependency_analysis/graphviz_generator.py

# 4. 啟動儀表板
python3 dependency_analysis/dependency_dashboard.py
```

### 方法三：VS Code 整合
```bash
# 1. 設定 VS Code 整合
python3 dependency_analysis/vscode_integration.py

# 2. 在 VS Code 中按 Ctrl+Shift+P
# 3. 執行任務：Tasks: Run Task > Invest_V3: 完整依賴分析
```

## 📊 生成的報告

分析完成後，您會在 `dependency_reports/` 目錄中找到：

### 📄 數據報告
- `dependency_analysis.json` - 完整的結構化數據
- `dependency_report.md` - 易讀的 Markdown 報告

### 🎨 視覺化圖表
- `invest_v3_overview.svg` - 專案概覽圖
- `invest_v3_architecture.svg` - 架構層級圖
- `invest_v3_module_*.svg` - 各模組詳細圖
- `invest_v3_complexity.svg` - 複雜度分析圖
- `dependency_network.png` - 依賴網路圖
- `architecture_layers.png` - 層級分布圖
- `complexity_heatmap.png` - 複雜度熱力圖
- `dependency_matrix.png` - 依賴矩陣

### 🔧 原始檔案
- `invest_v3_dependencies.dot` - Graphviz 原始檔
- 可用於進階自訂和編輯

## 🎯 Invest_V3 專案特色

### 📱 iOS 架構支援
- **MVVM 模式檢測** - 自動識別 ViewModel 模式
- **SwiftUI 組件分析** - 分析 View 和 ViewModel 關係
- **Service 層分析** - 識別業務邏輯服務

### 🏗️ 模組化架構
根據 Invest_V3 的業務模組自動分類：
- **Authentication** - 使用者認證模組
- **Trading** - 交易和投資組合
- **Chat** - 聊天和群組功能
- **Article** - 文章和內容管理
- **Wallet** - 錢包和支付
- **Settings** - 設定和個人資料

### 🎨 品牌配色
使用 Invest_V3 官方配色方案：
- **主要綠色**: #00B900 (投資成功/正面)
- **次要橙色**: #FD7E14 (警告/重要)
- **模組化配色**: 每個模組都有專屬顏色

## 📋 系統需求

### 🐍 Python 環境
- **Python 3.8+** (必需)
- **虛擬環境** (推薦)

### 📦 核心套件
```bash
# 自動安裝的套件
pip install networkx matplotlib pandas seaborn
pip install graphviz plotly dash
```

### 🔧 系統套件
```bash
# macOS (使用 Homebrew)
brew install graphviz

# Linux (Ubuntu/Debian)
sudo apt-get install graphviz

# Windows
# 請下載並安裝 Graphviz 官方安裝包
```

## 🎛️ 進階配置

### 命令列選項
```bash
# 基礎分析器
python3 swift_dependency_analyzer.py \
  --project-path /path/to/project \
  --output-dir custom_reports \
  --format all

# Graphviz 生成器
python3 graphviz_generator.py \
  --project-path /path/to/project \
  --format svg \
  --engine dot

# 實時儀表板
python3 dependency_dashboard.py \
  --project-path /path/to/project \
  --port 8080 \
  --debug
```

### 自訂配置
您可以編輯分析器腳本來調整：
- 架構層級定義
- 模組分類規則
- 複雜度計算公式
- 視覺化配色方案

## 🔍 分析指標

### 📊 專案度量
- **總檔案數** - Swift 檔案統計
- **依賴關係數** - 檔案間依賴總數
- **代碼行數** - 有效代碼行統計
- **平均複雜度** - 循環複雜度平均值
- **依賴密度** - 每檔案平均依賴數

### ⚠️ 問題檢測
- **循環依賴** - 檢測並標示循環引用
- **高複雜度檔案** - 識別需要重構的檔案
- **高依賴檔案** - 找出耦合度過高的檔案
- **孤立檔案** - 發現未被引用的檔案

### 🏗️ 架構分析
- **層級分離** - 檢查架構層級是否清晰
- **模組內聚** - 分析模組內部耦合度
- **跨層依賴** - 識別違反架構原則的依賴

## 🎨 視覺化特色

### 🌈 智能配色
- **模組色彩編碼** - 每個業務模組有專屬顏色
- **複雜度漸層** - 用顏色深淺表示複雜度
- **狀態指示** - 用不同色彩表示檔案狀態

### 📐 多種佈局
- **階層佈局** (dot) - 適合顯示架構層級
- **力導向佈局** (neato) - 適合網路關係
- **圓形佈局** (circo) - 適合循環結構
- **徑向佈局** (twopi) - 適合中心化結構

### 🔍 互動功能
- **縮放平移** - 自由探索大型圖表
- **節點詳情** - 滑鼠懸停顯示詳細信息
- **篩選功能** - 按模組、複雜度等篩選
- **實時更新** - 代碼變更時自動重新分析

## 💡 使用技巧

### 🎯 最佳實踐
1. **定期分析** - 建議每週執行一次完整分析
2. **持續監控** - 使用儀表板追蹤變化趨勢
3. **重構指引** - 根據複雜度報告優化代碼
4. **架構檢查** - 確保依賴方向符合設計原則

### 🔧 自訂建議
1. **調整閾值** - 根據專案特性調整複雜度閾值
2. **模組規則** - 自訂模組分類規則
3. **排除檔案** - 排除測試檔案或第三方代碼
4. **格式選擇** - 大型專案建議使用 SVG 格式

## 🐛 故障排除

### 常見問題

**Q: 執行時提示找不到 Graphviz**
```bash
# macOS
brew install graphviz

# Linux
sudo apt-get install graphviz
```

**Q: Python 套件安裝失敗**
```bash
# 升級 pip
pip3 install --upgrade pip

# 重新執行安裝腳本
bash dependency_analysis/install_dependencies.sh
```

**Q: 儀表板無法啟動**
```bash
# 檢查埠號是否被佔用
lsof -i :8050

# 使用其他埠號
python3 dependency_dashboard.py --port 8051
```

**Q: 圖表顯示空白**
- 檢查專案路徑是否正確
- 確認有 Swift 檔案存在
- 檢查檔案權限

### 日誌檢查
所有工具都會輸出詳細的執行日誌，出現問題時請檢查：
- 終端輸出訊息
- 錯誤堆疊追蹤
- 生成的 JSON 報告

## 🤝 貢獻指南

歡迎對工具進行改進！您可以：

1. **回報問題** - 在專案中創建 Issue
2. **功能建議** - 提出新功能想法
3. **代碼貢獻** - 提交 Pull Request
4. **文件改進** - 完善使用說明

### 開發環境設定
```bash
# 1. 克隆專案
git clone <repository-url>

# 2. 建立虛擬環境
python3 -m venv venv
source venv/bin/activate

# 3. 安裝開發依賴
pip install -r requirements-dev.txt

# 4. 執行測試
python -m pytest tests/
```

## 📞 技術支援

如需技術支援或有任何問題：

1. **查看文件** - 首先查看本 README 和相關文件
2. **檢查日誌** - 查看錯誤訊息和執行日誌
3. **社群支援** - 在專案討論區發起討論
4. **專業支援** - 聯繫 Invest_V3 開發團隊

## 📄 授權條款

本工具採用 MIT 授權條款，詳見 LICENSE 檔案。

---

**🎯 Template by Chang Ho Chien | HC AI 說人話channel | v1.0.0**  
**📺 Tutorial**: https://youtu.be/8Q1bRZaHH24

Made with ❤️ for the Invest_V3 Taiwan Investment Platform
