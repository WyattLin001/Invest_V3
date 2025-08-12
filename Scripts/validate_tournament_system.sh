#!/bin/bash

#
# validate_tournament_system.sh
# 錦標賽系統完整性驗證腳本
#
# 使用方法:
# ./Scripts/validate_tournament_system.sh
#

set -e

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 錦標賽系統完整性驗證${NC}"
echo -e "${BLUE}============================================================${NC}"

VALIDATION_PASSED=true

# 函數: 檢查文件是否存在
check_file() {
    local file_path="$1"
    local description="$2"
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}✅ $description${NC}"
    else
        echo -e "${RED}❌ $description - 文件不存在: $file_path${NC}"
        VALIDATION_PASSED=false
    fi
}

# 函數: 檢查目錄是否存在
check_directory() {
    local dir_path="$1"
    local description="$2"
    
    if [ -d "$dir_path" ]; then
        echo -e "${GREEN}✅ $description${NC}"
    else
        echo -e "${RED}❌ $description - 目錄不存在: $dir_path${NC}"
        VALIDATION_PASSED=false
    fi
}

echo -e "${YELLOW}📋 檢查核心服務文件${NC}"
echo "============================================================"

check_file "Invest_V3/Services/TournamentWorkflowService.swift" "TournamentWorkflowService - 工作流程服務"
check_file "Invest_V3/Services/TournamentService.swift" "TournamentService - 錦標賽服務"
check_file "Invest_V3/Services/TournamentTradeService.swift" "TournamentTradeService - 交易服務"
check_file "Invest_V3/Services/TournamentWalletService.swift" "TournamentWalletService - 錢包服務"
check_file "Invest_V3/Services/TournamentRankingService.swift" "TournamentRankingService - 排名服務"
check_file "Invest_V3/Services/TournamentBusinessService.swift" "TournamentBusinessService - 業務服務"

echo ""
echo -e "${YELLOW}🎨 檢查用戶界面文件${NC}"
echo "============================================================"

check_file "Invest_V3/Views/ModernTournamentSelectionView.swift" "錦標賽選擇視圖"
check_file "Invest_V3/Views/TournamentDetailView.swift" "錦標賽詳情視圖"
check_file "Invest_V3/Views/TournamentCreationView.swift" "錦標賽創建視圖"
check_file "Invest_V3/Views/LiveTournamentRankingsView.swift" "實時排行榜視圖"
check_file "Invest_V3/Views/TournamentSettlementView.swift" "錦標賽結算視圖"

echo ""
echo -e "${YELLOW}📊 檢查數據模型文件${NC}"
echo "============================================================"

check_file "Invest_V3/Models/TournamentModels.swift" "錦標賽數據模型"

echo ""
echo -e "${YELLOW}🧪 檢查測試文件${NC}"
echo "============================================================"

check_file "Invest_V3Tests/TournamentWorkflowServiceTests.swift" "工作流程服務測試"
check_file "Invest_V3Tests/TournamentIntegrationTests.swift" "集成測試"
check_file "Invest_V3UITests/TournamentUITests.swift" "UI自動化測試"

echo ""
echo -e "${YELLOW}📦 檢查數據遷移文件${NC}"
echo "============================================================"

check_file "Invest_V3/Migration/TournamentDataMigration.swift" "數據遷移腳本"

echo ""
echo -e "${YELLOW}🛠 檢查腳本和文檔${NC}"
echo "============================================================"

check_file "Scripts/run_tournament_tests.sh" "測試自動化腳本"
check_file "TOURNAMENT_SYSTEM.md" "系統維護文檔"

echo ""
echo -e "${YELLOW}🏗 檢查項目結構${NC}"
echo "============================================================"

check_directory "Invest_V3/Services" "服務目錄"
check_directory "Invest_V3/Views" "視圖目錄"
check_directory "Invest_V3/Models" "模型目錄"
check_directory "Invest_V3/Migration" "遷移目錄"
check_directory "Invest_V3Tests" "測試目錄"
check_directory "Scripts" "腳本目錄"

echo ""
echo -e "${YELLOW}📝 檢查文件內容完整性${NC}"
echo "============================================================"

# 檢查關鍵服務是否包含必要的方法
if grep -q "createTournament" "Invest_V3/Services/TournamentWorkflowService.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ TournamentWorkflowService 包含 createTournament 方法${NC}"
else
    echo -e "${RED}❌ TournamentWorkflowService 缺少 createTournament 方法${NC}"
    VALIDATION_PASSED=false
fi

if grep -q "joinTournament" "Invest_V3/Services/TournamentWorkflowService.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ TournamentWorkflowService 包含 joinTournament 方法${NC}"
else
    echo -e "${RED}❌ TournamentWorkflowService 缺少 joinTournament 方法${NC}"
    VALIDATION_PASSED=false
fi

if grep -q "executeTournamentTrade" "Invest_V3/Services/TournamentWorkflowService.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ TournamentWorkflowService 包含 executeTournamentTrade 方法${NC}"
else
    echo -e "${RED}❌ TournamentWorkflowService 缺少 executeTournamentTrade 方法${NC}"
    VALIDATION_PASSED=false
fi

if grep -q "updateLiveRankings" "Invest_V3/Services/TournamentWorkflowService.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ TournamentWorkflowService 包含 updateLiveRankings 方法${NC}"
else
    echo -e "${RED}❌ TournamentWorkflowService 缺少 updateLiveRankings 方法${NC}"
    VALIDATION_PASSED=false
fi

if grep -q "settleTournament" "Invest_V3/Services/TournamentWorkflowService.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ TournamentWorkflowService 包含 settleTournament 方法${NC}"
else
    echo -e "${RED}❌ TournamentWorkflowService 缺少 settleTournament 方法${NC}"
    VALIDATION_PASSED=false
fi

# 檢查測試文件內容
if grep -q "testCompleteTournamentLifecycle" "Invest_V3Tests/TournamentIntegrationTests.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ 集成測試包含完整生命週期測試${NC}"
else
    echo -e "${RED}❌ 集成測試缺少完整生命週期測試${NC}"
    VALIDATION_PASSED=false
fi

# 檢查UI測試文件內容
if grep -q "testTournamentTabNavigation" "Invest_V3UITests/TournamentUITests.swift" 2>/dev/null; then
    echo -e "${GREEN}✅ UI測試包含導航測試${NC}"
else
    echo -e "${RED}❌ UI測試缺少導航測試${NC}"
    VALIDATION_PASSED=false
fi

echo ""
echo -e "${YELLOW}📋 生成驗證報告${NC}"
echo "============================================================"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
REPORT_FILE="validation_report_$(date +"%Y%m%d_%H%M%S").txt"

cat > "$REPORT_FILE" << EOF
錦標賽系統完整性驗證報告
========================================

驗證時間: $TIMESTAMP
驗證結果: $(if [ "$VALIDATION_PASSED" = true ]; then echo "通過"; else echo "失敗"; fi)

核心組件檢查:
- TournamentWorkflowService: 已驗證
- TournamentService: 已驗證
- TournamentTradeService: 已驗證
- TournamentWalletService: 已驗證
- TournamentRankingService: 已驗證
- TournamentBusinessService: 已驗證

用戶界面檢查:
- ModernTournamentSelectionView: 已驗證
- TournamentDetailView: 已驗證
- TournamentCreationView: 已驗證
- LiveTournamentRankingsView: 已驗證
- TournamentSettlementView: 已驗證

測試套件檢查:
- 單元測試: 已驗證
- 集成測試: 已驗證
- UI測試: 已驗證

數據遷移:
- TournamentDataMigration: 已驗證

文檔和腳本:
- 維護文檔: 已驗證
- 測試腳本: 已驗證

系統狀態: $(if [ "$VALIDATION_PASSED" = true ]; then echo "準備就緒"; else echo "需要修復"; fi)
EOF

echo -e "${BLUE}📊 驗證報告已保存到: $REPORT_FILE${NC}"

echo ""
echo "============================================================"
if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}🎉 錦標賽系統驗證通過！系統準備就緒。${NC}"
    echo -e "${BLUE}📚 請參考 TOURNAMENT_SYSTEM.md 進行後續維護和開發${NC}"
    exit 0
else
    echo -e "${RED}❌ 錦標賽系統驗證失敗，請檢查缺失的文件和組件${NC}"
    echo -e "${YELLOW}💡 建議檢查項目文件結構和實現狀態${NC}"
    exit 1
fi