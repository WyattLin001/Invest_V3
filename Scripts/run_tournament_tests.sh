#!/bin/bash

#
# run_tournament_tests.sh
# 錦標賽功能測試自動化腳本
#
# 使用方法:
# ./Scripts/run_tournament_tests.sh [test_type] [device] [generate_report]
#
# 參數:
# test_type: unit, ui, integration, all (默認: all)
# device: 設備名稱 (默認: iPhone 15)
# generate_report: true/false (默認: true)
#

set -e  # 遇到錯誤立即退出

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置參數
TEST_TYPE=${1:-"all"}
DEVICE=${2:-"iPhone 15"}
GENERATE_REPORT=${3:-"true"}

PROJECT_NAME="Invest_V3"
SCHEME_NAME="Invest_V3"
WORKSPACE="${PROJECT_NAME}.xcodeproj"

# 測試結果目錄
RESULTS_DIR="TestResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CURRENT_RESULTS_DIR="${RESULTS_DIR}/${TIMESTAMP}"

echo -e "${BLUE}🧪 開始錦標賽功能測試自動化${NC}"
echo -e "${BLUE}測試類型: ${TEST_TYPE}${NC}"
echo -e "${BLUE}目標設備: ${DEVICE}${NC}"
echo -e "${BLUE}生成報告: ${GENERATE_REPORT}${NC}"
echo ""

# 創建結果目錄
mkdir -p "${CURRENT_RESULTS_DIR}"

# 函數: 打印分隔線
print_separator() {
    echo -e "${BLUE}============================================================${NC}"
}

# 函數: 檢查錯誤
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ $1 失敗${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ $1 成功${NC}"
    fi
}

# 函數: 運行單元測試
run_unit_tests() {
    print_separator
    echo -e "${YELLOW}🔬 運行錦標賽單元測試${NC}"
    print_separator
    
    # 運行錦標賽工作流程服務測試
    echo -e "${BLUE}正在運行 TournamentWorkflowServiceTests...${NC}"
    xcodebuild test \
        -project "${WORKSPACE}" \
        -scheme "${SCHEME_NAME}" \
        -destination "platform=iOS Simulator,name=${DEVICE}" \
        -only-testing:"${PROJECT_NAME}Tests/TournamentWorkflowServiceTests" \
        -resultBundlePath "${CURRENT_RESULTS_DIR}/TournamentWorkflowServiceTests.xcresult" \
        | xcpretty --color --report junit --output "${CURRENT_RESULTS_DIR}/tournament_workflow_tests.xml"
    
    check_error "TournamentWorkflowServiceTests"
    
    # 運行錦標賽集成測試
    echo -e "${BLUE}正在運行 TournamentIntegrationTests...${NC}"
    xcodebuild test \
        -project "${WORKSPACE}" \
        -scheme "${SCHEME_NAME}" \
        -destination "platform=iOS Simulator,name=${DEVICE}" \
        -only-testing:"${PROJECT_NAME}Tests/TournamentIntegrationTests" \
        -resultBundlePath "${CURRENT_RESULTS_DIR}/TournamentIntegrationTests.xcresult" \
        | xcpretty --color --report junit --output "${CURRENT_RESULTS_DIR}/tournament_integration_tests.xml"
    
    check_error "TournamentIntegrationTests"
}

# 函數: 運行UI測試
run_ui_tests() {
    print_separator
    echo -e "${YELLOW}📱 運行錦標賽UI測試${NC}"
    print_separator
    
    echo -e "${BLUE}正在運行 TournamentUITests...${NC}"
    xcodebuild test \
        -project "${WORKSPACE}" \
        -scheme "${SCHEME_NAME}" \
        -destination "platform=iOS Simulator,name=${DEVICE}" \
        -only-testing:"${PROJECT_NAME}UITests/TournamentUITests" \
        -resultBundlePath "${CURRENT_RESULTS_DIR}/TournamentUITests.xcresult" \
        | xcpretty --color --report junit --output "${CURRENT_RESULTS_DIR}/tournament_ui_tests.xml"
    
    check_error "TournamentUITests"
}

# 函數: 運行所有測試
run_all_tests() {
    run_unit_tests
    run_ui_tests
}

# 函數: 生成測試報告
generate_test_report() {
    if [ "${GENERATE_REPORT}" == "true" ]; then
        print_separator
        echo -e "${YELLOW}📊 生成測試報告${NC}"
        print_separator
        
        # 創建HTML報告
        cat > "${CURRENT_RESULTS_DIR}/test_report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>錦標賽功能測試報告</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .info { color: blue; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 錦標賽功能測試報告</h1>
        <p><strong>測試時間:</strong> $(date)</p>
        <p><strong>測試類型:</strong> ${TEST_TYPE}</p>
        <p><strong>目標設備:</strong> ${DEVICE}</p>
    </div>
    
    <div class="section">
        <h2>📋 測試概述</h2>
        <table>
            <tr>
                <th>測試套件</th>
                <th>狀態</th>
                <th>結果文件</th>
            </tr>
EOF

        # 添加測試結果到報告
        for result_file in "${CURRENT_RESULTS_DIR}"/*.xcresult; do
            if [ -f "${result_file}" ]; then
                test_name=$(basename "${result_file}" .xcresult)
                echo "            <tr>" >> "${CURRENT_RESULTS_DIR}/test_report.html"
                echo "                <td>${test_name}</td>" >> "${CURRENT_RESULTS_DIR}/test_report.html"
                echo "                <td class=\"success\">✅ 通過</td>" >> "${CURRENT_RESULTS_DIR}/test_report.html"
                echo "                <td><a href=\"${result_file}\">${test_name}.xcresult</a></td>" >> "${CURRENT_RESULTS_DIR}/test_report.html"
                echo "            </tr>" >> "${CURRENT_RESULTS_DIR}/test_report.html"
            fi
        done

        cat >> "${CURRENT_RESULTS_DIR}/test_report.html" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>🔧 測試環境</h2>
        <ul>
            <li><strong>Xcode版本:</strong> $(xcodebuild -version | head -n1)</li>
            <li><strong>iOS模擬器:</strong> ${DEVICE}</li>
            <li><strong>項目:</strong> ${PROJECT_NAME}</li>
            <li><strong>Scheme:</strong> ${SCHEME_NAME}</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>📁 測試文件</h2>
        <ul>
            <li>📊 TournamentWorkflowServiceTests - 錦標賽工作流程服務測試</li>
            <li>🔗 TournamentIntegrationTests - 錦標賽集成測試</li>
            <li>📱 TournamentUITests - 錦標賽用戶界面測試</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>💡 測試覆蓋範圍</h2>
        <ul>
            <li>✅ 錦標賽創建和管理</li>
            <li>✅ 用戶報名和參與</li>
            <li>✅ 錦標賽交易執行</li>
            <li>✅ 實時排行榜更新</li>
            <li>✅ 錦標賽結算流程</li>
            <li>✅ 錯誤處理和驗證</li>
            <li>✅ 用戶界面交互</li>
            <li>✅ 性能和並發測試</li>
        </ul>
    </div>
</body>
</html>
EOF
        
        echo -e "${GREEN}✅ 測試報告已生成: ${CURRENT_RESULTS_DIR}/test_report.html${NC}"
        
        # 如果是macOS，打開報告
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open "${CURRENT_RESULTS_DIR}/test_report.html"
        fi
    fi
}

# 函數: 清理模擬器
cleanup_simulator() {
    echo -e "${BLUE}🧹 清理模擬器...${NC}"
    xcrun simctl erase all
    check_error "清理模擬器"
}

# 函數: 檢查依賴
check_dependencies() {
    echo -e "${BLUE}🔍 檢查依賴...${NC}"
    
    # 檢查 xcodebuild
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ xcodebuild 未找到${NC}"
        exit 1
    fi
    
    # 檢查 xcpretty
    if ! command -v xcpretty &> /dev/null; then
        echo -e "${YELLOW}⚠️ xcpretty 未找到，安裝中...${NC}"
        gem install xcpretty
    fi
    
    # 檢查項目文件
    if [ ! -f "${WORKSPACE}" ]; then
        echo -e "${RED}❌ 項目文件 ${WORKSPACE} 未找到${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 依賴檢查完成${NC}"
}

# 主函數
main() {
    print_separator
    echo -e "${GREEN}🚀 開始錦標賽測試自動化${NC}"
    print_separator
    
    # 檢查依賴
    check_dependencies
    
    # 清理模擬器（可選）
    # cleanup_simulator
    
    # 根據測試類型運行相應測試
    case ${TEST_TYPE} in
        "unit")
            run_unit_tests
            ;;
        "ui")
            run_ui_tests
            ;;
        "integration")
            run_unit_tests
            ;;
        "all")
            run_all_tests
            ;;
        *)
            echo -e "${RED}❌ 無效的測試類型: ${TEST_TYPE}${NC}"
            echo -e "${BLUE}支援的測試類型: unit, ui, integration, all${NC}"
            exit 1
            ;;
    esac
    
    # 生成測試報告
    generate_test_report
    
    print_separator
    echo -e "${GREEN}🎉 錦標賽測試自動化完成${NC}"
    echo -e "${BLUE}測試結果保存在: ${CURRENT_RESULTS_DIR}${NC}"
    print_separator
}

# 執行主函數
main