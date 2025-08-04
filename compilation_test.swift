// Test key Swift syntax from our files
import Foundation
import SwiftUI

// Test our main enums compile without conflicts
enum TrendDirection {
    case up, down, flat
}

enum InvestmentGrade: String {
    case excellent = "優秀"
    case good = "良好"
    case average = "一般"
    case belowAverage = "待改進"
    case poor = "不佳"
}

enum LayoutTrendDirection {
    case up, down, neutral
}

// Test our structs compile without conflicts
struct TestData {
    let trend: TrendDirection
    let grade: InvestmentGrade
    let layoutTrend: LayoutTrendDirection
}

print("✅ All type definitions compile successfully")