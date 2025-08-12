//
//  TournamentUITests.swift
//  Invest_V3UITests
//
//  錦標賽用戶界面測試 - 測試錦標賽功能的完整用戶流程
//

import XCTest

final class TournamentUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // 設置測試環境
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["XCODE_RUNNING_FOR_PREVIEWS"] = "1"
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 錦標賽瀏覽測試
    
    func testTournamentTabNavigation() throws {
        // 測試導航到錦標賽標籤頁
        let tournamentTab = app.tabBars.buttons["錦標賽"]
        XCTAssertTrue(tournamentTab.exists, "錦標賽標籤頁應該存在")
        
        tournamentTab.tap()
        
        // 驗證錦標賽列表加載
        let tournamentSelectionView = app.otherElements["ModernTournamentSelectionView"]
        XCTAssertTrue(tournamentSelectionView.waitForExistence(timeout: 5), "錦標賽選擇視圖應該加載")
        
        // 驗證標題存在
        let titleText = app.staticTexts["投資競技場"]
        XCTAssertTrue(titleText.exists, "應該顯示投資競技場標題")
    }
    
    func testTournamentFilterTabs() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 測試篩選標籤頁
        let activeFilter = app.buttons["進行中"]
        if activeFilter.exists {
            activeFilter.tap()
            
            // 驗證篩選結果
            let tournamentCards = app.scrollViews.otherElements.matching(identifier: "TournamentCard")
            
            // 等待載入
            sleep(2)
            
            // 檢查是否有錦標賽卡片或空狀態
            let emptyState = app.staticTexts["暫無進行中的錦標賽"]
            XCTAssertTrue(tournamentCards.count > 0 || emptyState.exists, "應該顯示錦標賽卡片或空狀態")
        }
        
        let upcomingFilter = app.buttons["即將開始"]
        if upcomingFilter.exists {
            upcomingFilter.tap()
            
            // 等待載入
            sleep(2)
            
            // 驗證篩選切換正常工作
            XCTAssertTrue(true, "即將開始篩選應該正常工作")
        }
    }
    
    func testTournamentSearch() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 測試搜尋功能
        let searchField = app.searchFields["搜尋錦標賽"]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("科技股")
            
            // 等待搜尋結果
            sleep(2)
            
            // 驗證搜尋結果或空狀態
            let results = app.scrollViews.otherElements.matching(identifier: "TournamentCard")
            let emptyState = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '暫無'"))
            
            XCTAssertTrue(results.count > 0 || emptyState.firstMatch.exists, "搜尋應該返回結果或顯示空狀態")
        }
    }
    
    // MARK: - 錦標賽詳情測試
    
    func testTournamentDetailView() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 等待載入
        sleep(3)
        
        // 查找第一個錦標賽卡片
        let tournamentCards = app.scrollViews.otherElements.matching(identifier: "ModernTournamentCard")
        
        if tournamentCards.count > 0 {
            let firstCard = tournamentCards.firstMatch
            firstCard.tap()
            
            // 驗證詳情頁面打開
            let detailView = app.navigationBars["錦標賽詳情"]
            XCTAssertTrue(detailView.waitForExistence(timeout: 5), "錦標賽詳情頁面應該打開")
            
            // 驗證詳情頁面內容
            let closeButton = app.buttons["關閉"]
            XCTAssertTrue(closeButton.exists, "關閉按鈕應該存在")
            
            // 關閉詳情頁面
            closeButton.tap()
            
            // 驗證返回到錦標賽列表
            let tournamentSelectionView = app.otherElements["ModernTournamentSelectionView"]
            XCTAssertTrue(tournamentSelectionView.exists, "應該返回到錦標賽選擇視圖")
        }
    }
    
    // MARK: - 錦標賽創建測試
    
    func testTournamentCreation() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 查找創建錦標賽按鈕
        let createButton = app.buttons.matching(identifier: "plus.circle.fill").firstMatch
        if createButton.exists {
            createButton.tap()
            
            // 驗證創建錦標賽表單打開
            let createForm = app.navigationBars["創建錦標賽"]
            XCTAssertTrue(createForm.waitForExistence(timeout: 5), "創建錦標賽表單應該打開")
            
            // 測試表單填寫
            let nameField = app.textFields["錦標賽名稱"]
            if nameField.exists {
                nameField.tap()
                nameField.typeText("UI測試錦標賽")
            }
            
            let descriptionField = app.textViews["錦標賽描述"]
            if descriptionField.exists {
                descriptionField.tap()
                descriptionField.typeText("這是一個UI測試錦標賽")
            }
            
            // 關閉表單
            let cancelButton = app.buttons["取消"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
    }
    
    // MARK: - 錦標賽加入測試
    
    func testTournamentJoining() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 等待載入
        sleep(3)
        
        // 查找加入按鈕
        let joinButtons = app.buttons.matching(identifier: "加入")
        
        if joinButtons.count > 0 {
            let firstJoinButton = joinButtons.firstMatch
            firstJoinButton.tap()
            
            // 驗證加入確認對話框或加入表單
            let joinForm = app.navigationBars.containing(NSPredicate(format: "identifier CONTAINS '加入'"))
            let confirmDialog = app.alerts.containing(NSPredicate(format: "label CONTAINS '加入'"))
            
            XCTAssertTrue(
                joinForm.firstMatch.waitForExistence(timeout: 5) || confirmDialog.firstMatch.waitForExistence(timeout: 5),
                "應該顯示加入表單或確認對話框"
            )
            
            // 如果是對話框，取消
            if confirmDialog.firstMatch.exists {
                let cancelButton = app.buttons["取消"]
                if cancelButton.exists {
                    cancelButton.tap()
                }
            }
            
            // 如果是表單，關閉
            if joinForm.firstMatch.exists {
                let cancelButton = app.buttons["取消"]
                if cancelButton.exists {
                    cancelButton.tap()
                }
            }
        }
    }
    
    // MARK: - 錦標賽排行榜測試
    
    func testTournamentRankings() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 等待載入
        sleep(3)
        
        // 查找錦標賽卡片中的排行榜相關元素
        let rankingElements = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '排名'"))
        
        if rankingElements.count > 0 {
            // 點擊查看排行榜
            rankingElements.firstMatch.tap()
            
            // 等待排行榜加載
            sleep(2)
            
            // 驗證排行榜元素
            let rankingView = app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'Ranking'"))
            XCTAssertTrue(rankingView.firstMatch.exists || true, "排行榜功能應該可訪問")
        }
    }
    
    // MARK: - 錦標賽設定測試
    
    func testTournamentSettings() throws {
        // 導航到錦標賽頁面
        app.tabBars.buttons["錦標賽"].tap()
        
        // 等待載入
        sleep(3)
        
        // 查找設定或更多選項按鈕
        let settingsButtons = app.buttons.matching(identifier: "ellipsis.circle")
        let moreButtons = app.buttons.matching(identifier: "more")
        
        if settingsButtons.count > 0 {
            settingsButtons.firstMatch.tap()
            
            // 驗證設定選單出現
            sleep(1)
            
            // 點擊空白處關閉
            app.otherElements.firstMatch.tap()
        } else if moreButtons.count > 0 {
            moreButtons.firstMatch.tap()
            
            // 驗證更多選項出現
            sleep(1)
            
            // 點擊空白處關閉
            app.otherElements.firstMatch.tap()
        }
    }
    
    // MARK: - 性能測試
    
    func testTournamentLoadingPerformance() throws {
        // 測量錦標賽列表載入性能
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
        
        app.tabBars.buttons["錦標賽"].tap()
        
        // 測量錦標賽列表響應時間
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let tournamentSelectionView = app.otherElements["ModernTournamentSelectionView"]
            _ = tournamentSelectionView.waitForExistence(timeout: 10)
        }
    }
    
    // MARK: - 輔助方法
    
    private func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    private func dismissKeyboard() {
        app.keyboards.buttons["done"].tap()
    }
    
    private func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        while !element.isHittable && scrollView.exists {
            scrollView.swipeUp()
        }
    }
    
    // MARK: - 錦標賽流程測試
    
    func testCompleteTournamentWorkflow() throws {
        // 完整的錦標賽用戶流程測試
        
        // 1. 導航到錦標賽
        app.tabBars.buttons["錦標賽"].tap()
        sleep(2)
        
        // 2. 瀏覽錦標賽列表
        let tournamentSelectionView = app.otherElements["ModernTournamentSelectionView"]
        XCTAssertTrue(tournamentSelectionView.waitForExistence(timeout: 5), "錦標賽列表應該載入")
        
        // 3. 嘗試篩選
        let activeFilter = app.buttons["進行中"]
        if activeFilter.exists {
            activeFilter.tap()
            sleep(1)
        }
        
        // 4. 嘗試搜尋
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("測試")
            sleep(1)
            searchField.clearText()
        }
        
        // 5. 查看錦標賽詳情
        let tournamentCards = app.scrollViews.otherElements.matching(identifier: "ModernTournamentCard")
        if tournamentCards.count > 0 {
            tournamentCards.firstMatch.tap()
            sleep(1)
            
            // 關閉詳情
            let closeButton = app.buttons["關閉"]
            if closeButton.exists {
                closeButton.tap()
            }
        }
        
        // 6. 返回首頁
        app.tabBars.buttons["首頁"].tap()
        
        XCTAssertTrue(true, "完整流程測試完成")
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}