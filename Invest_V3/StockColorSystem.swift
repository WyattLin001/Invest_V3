import SwiftUI
import Foundation

// MARK: - 主題自適應顏色工具
struct ThemeAdaptiveColor {
    /// 創建主題自適應顏色
    static func create(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - 顏色提供者協議
protocol ColorProvider {
    func colorForStock(symbol: String) -> Color
    func colorForCash() -> Color
    func getAllColors() -> [(symbol: String, color: Color)]
}

// MARK: - 顏色配置
struct ColorConfiguration {
    static let predefinedStocks = [
        "2330", "0050", "2454", "2317", "2881", "2882", "2886", "2891", 
        "2395", "3711", "2412", "1303", "1301", "2382", "2308"
    ]
    
    // 淺色模式配置
    static let lightSaturationRange = 0.65...0.85
    static let lightLightnessRange = 0.45...0.65
    
    // 深色模式配置 (更高的亮度以提升可見度)
    static let darkSaturationRange = 0.70...0.90
    static let darkLightnessRange = 0.60...0.80
    
    static let maxColorCacheSize = 1000
    static let colorSimilarityThreshold = 0.15
    
    /// 根據當前主題獲取飽和度範圍（需要在 @MainActor 環境中調用）
    @MainActor
    static var currentSaturationRange: ClosedRange<Double> {
        ThemeManager.shared.isDarkMode ? darkSaturationRange : lightSaturationRange
    }
    
    /// 根據當前主題獲取亮度範圍（需要在 @MainActor 環境中調用）
    @MainActor 
    static var currentLightnessRange: ClosedRange<Double> {
        ThemeManager.shared.isDarkMode ? darkLightnessRange : lightLightnessRange
    }
}

// MARK: - 動態顏色生成器
class DynamicColorGenerator {
    private let existingColors: [Color]
    private let saturationRange: ClosedRange<Double>
    private let lightnessRange: ClosedRange<Double>
    
    init(existingColors: [Color] = [], 
         saturationRange: ClosedRange<Double> = ColorConfiguration.lightSaturationRange,
         lightnessRange: ClosedRange<Double> = ColorConfiguration.lightLightnessRange) {
        self.existingColors = existingColors
        self.saturationRange = saturationRange
        self.lightnessRange = lightnessRange
    }
    
    func generateColor(for symbol: String) -> Color {
        let baseColor = generateBaseColor(for: symbol)
        
        // 檢查顏色衝突，最多嘗試5次
        for attempt in 0..<5 {
            let adjustedColor = adjustColorIfNeeded(baseColor, attempt: attempt)
            if !isColorTooSimilar(adjustedColor) {
                return adjustedColor
            }
        }
        
        // 如果仍有衝突，返回基礎顏色（優先功能性而非完美性）
        return baseColor
    }
    
    private func generateBaseColor(for symbol: String) -> Color {
        let hash = symbol.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        
        // 使用不同的哈希位來生成飽和度和亮度
        let saturationSeed = abs(hash >> 8) % 100
        let lightnessSeed = abs(hash >> 16) % 100
        
        let saturation = saturationRange.lowerBound + 
                        (saturationRange.upperBound - saturationRange.lowerBound) * 
                        Double(saturationSeed) / 100.0
        
        let lightness = lightnessRange.lowerBound + 
                       (lightnessRange.upperBound - lightnessRange.lowerBound) * 
                       Double(lightnessSeed) / 100.0
        
        return Color(hue: hue, saturation: saturation, brightness: lightness)
    }
    
    private func adjustColorIfNeeded(_ color: Color, attempt: Int) -> Color {
        if attempt == 0 {
            return color
        }
        
        // 根據嘗試次數調整色相
        let hueShift = Double(attempt) * 0.1 // 每次嘗試偏移36度
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newHue = fmod(Double(hue) + hueShift, 1.0)
        return Color(hue: newHue, saturation: Double(saturation), brightness: Double(brightness))
    }
    
    private func isColorTooSimilar(_ newColor: Color) -> Bool {
        let threshold = ColorConfiguration.colorSimilarityThreshold
        
        for existingColor in existingColors {
            if calculateColorDistance(newColor, existingColor) < threshold {
                return true
            }
        }
        return false
    }
    
    private func calculateColorDistance(_ color1: Color, _ color2: Color) -> Double {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        uiColor2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
        
        // 簡化的顏色距離計算（基於HSB空間）
        let hueDiff = min(abs(h1 - h2), 1.0 - abs(h1 - h2)) // 處理色相環形特性
        let satDiff = abs(s1 - s2)
        let brightDiff = abs(b1 - b2)
        
        return sqrt(pow(Double(hueDiff), 2) + pow(Double(satDiff), 2) + pow(Double(brightDiff), 2))
    }
}

// MARK: - 顏色持久化管理器
class ColorPersistenceManager {
    private let userDefaults = UserDefaults.standard
    private let colorKey = "StockColorMapping"
    private let maxCacheSize = ColorConfiguration.maxColorCacheSize
    
    func saveColor(_ color: Color, for symbol: String) {
        var colorMapping = loadColorMapping()
        colorMapping[symbol] = colorToHex(color)
        
        // 清理過舊的緩存
        if colorMapping.count > maxCacheSize {
            let sortedKeys = Array(colorMapping.keys.sorted())
            let keysToRemove = sortedKeys.prefix(colorMapping.count - maxCacheSize)
            for key in keysToRemove {
                colorMapping.removeValue(forKey: key)
            }
        }
        
        userDefaults.set(colorMapping, forKey: colorKey)
        // print("🎨 [Persistence] 保存顏色: \(symbol) -> \(colorToHex(color))")
    }
    
    func loadColor(for symbol: String) -> Color? {
        let colorMapping = loadColorMapping()
        guard let hexString = colorMapping[symbol],
              let color = colorFromHex(hexString) else {
            return nil
        }
        // print("🎨 [Persistence] 讀取顏色: \(symbol) -> \(hexString)")
        return color
    }
    
    func getAllSavedColors() -> [String: Color] {
        let colorMapping = loadColorMapping()
        var result: [String: Color] = [:]
        
        for (symbol, hexString) in colorMapping {
            if let color = colorFromHex(hexString) {
                result[symbol] = color
            }
        }
        
        return result
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: colorKey)
        // print("🎨 [Persistence] 清除顏色緩存")
    }
    
    private func loadColorMapping() -> [String: String] {
        return userDefaults.object(forKey: colorKey) as? [String: String] ?? [:]
    }
    
    private func colorToHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X", 
                     Int(red * 255), 
                     Int(green * 255), 
                     Int(blue * 255))
    }
    
    private func colorFromHex(_ hex: String) -> Color? {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - 混合顏色提供者
class HybridColorProvider: ColorProvider, ObservableObject {
    static let shared = HybridColorProvider()
    
    private let predefinedColors: [String: Color]
    private let persistenceManager: ColorPersistenceManager
    private let dynamicGenerator: DynamicColorGenerator
    private let cashColor = ThemeAdaptiveColor.create(
        light: Color(red: 0.5, green: 0.5, blue: 0.5),  // 淺色模式：較深的灰色
        dark: Color(red: 0.8, green: 0.8, blue: 0.8)    // 深色模式：較淺的灰色
    )
    
    private init() {
        // 預定義顏色（深色模式適配）
        self.predefinedColors = [
            "2330": ThemeAdaptiveColor.create(
                light: Color(red: 0.9, green: 0.2, blue: 0.2),    // 台積電 - 紅色
                dark: Color(red: 1.0, green: 0.4, blue: 0.4)
            ),
            "0050": ThemeAdaptiveColor.create(
                light: Color(red: 0.2, green: 0.5, blue: 0.9),    // 台灣50 - 藍色
                dark: Color(red: 0.4, green: 0.7, blue: 1.0)
            ),
            "2454": ThemeAdaptiveColor.create(
                light: Color(red: 0.2, green: 0.7, blue: 0.2),    // 聯發科 - 綠色
                dark: Color(red: 0.4, green: 0.9, blue: 0.4)
            ),
            "2317": ThemeAdaptiveColor.create(
                light: Color(red: 0.7, green: 0.2, blue: 0.7),    // 鴻海 - 紫色
                dark: Color(red: 0.9, green: 0.4, blue: 0.9)
            ),
            "2881": ThemeAdaptiveColor.create(
                light: Color(red: 0.8, green: 0.6, blue: 0.1),    // 富邦金 - 黃色
                dark: Color(red: 1.0, green: 0.8, blue: 0.3)
            ),
            "2882": ThemeAdaptiveColor.create(
                light: Color(red: 0.1, green: 0.7, blue: 0.7),    // 國泰金 - 青色
                dark: Color(red: 0.3, green: 0.9, blue: 0.9)
            ),
            "2886": ThemeAdaptiveColor.create(
                light: Color(red: 0.7, green: 0.4, blue: 0.1),    // 兆豐金 - 棕色
                dark: Color(red: 0.9, green: 0.6, blue: 0.3)
            ),
            "2891": ThemeAdaptiveColor.create(
                light: Color(red: 0.5, green: 0.1, blue: 0.7),    // 中信金 - 深紫色
                dark: Color(red: 0.7, green: 0.3, blue: 0.9)
            ),
            "2395": ThemeAdaptiveColor.create(
                light: Color(red: 0.1, green: 0.3, blue: 0.7),    // 研華 - 深藍色
                dark: Color(red: 0.3, green: 0.5, blue: 0.9)
            ),
            "3711": ThemeAdaptiveColor.create(
                light: Color(red: 0.7, green: 0.1, blue: 0.3),    // 日月光投控 - 深紅色
                dark: Color(red: 0.9, green: 0.3, blue: 0.5)
            ),
            "2412": ThemeAdaptiveColor.create(
                light: Color(red: 0.3, green: 0.7, blue: 0.5),    // 中華電 - 淺綠色
                dark: Color(red: 0.5, green: 0.9, blue: 0.7)
            ),
            "1303": ThemeAdaptiveColor.create(
                light: Color(red: 0.6, green: 0.2, blue: 0.5),    // 南亞 - 粉紫色
                dark: Color(red: 0.8, green: 0.4, blue: 0.7)
            ),
            "1301": ThemeAdaptiveColor.create(
                light: Color(red: 0.2, green: 0.5, blue: 0.6),    // 台塑 - 淺藍色
                dark: Color(red: 0.4, green: 0.7, blue: 0.8)
            ),
            "2382": ThemeAdaptiveColor.create(
                light: Color(red: 0.7, green: 0.5, blue: 0.3),    // 廣達 - 淺棕色
                dark: Color(red: 0.9, green: 0.7, blue: 0.5)
            ),
            "2308": ThemeAdaptiveColor.create(
                light: Color(red: 0.4, green: 0.6, blue: 0.2),    // 台達電 - 淺綠色
                dark: Color(red: 0.6, green: 0.8, blue: 0.4)
            )
        ]
        
        self.persistenceManager = ColorPersistenceManager()
        
        // 初始化動態生成器，傳入現有顏色以避免衝突
        let allExistingColors = Array(predefinedColors.values) + Array(persistenceManager.getAllSavedColors().values)
        self.dynamicGenerator = DynamicColorGenerator(existingColors: allExistingColors)
        
        // print("🎨 [HybridColorProvider] 初始化完成，預定義顏色: \(predefinedColors.count)，緩存顏色: \(persistenceManager.getAllSavedColors().count)")
    }
    
    func colorForStock(symbol: String) -> Color {
        // 優先級1: 檢查預定義顏色
        if let predefinedColor = predefinedColors[symbol] {
            // print("🎨 [Hybrid] 使用預定義顏色: \(symbol)")
            return predefinedColor
        }
        
        // 優先級2: 檢查已保存的動態顏色
        if let savedColor = persistenceManager.loadColor(for: symbol) {
            // print("🎨 [Hybrid] 使用已保存顏色: \(symbol)")
            return savedColor
        }
        
        // 優先級3: 生成新的動態顏色並保存
        let newColor = dynamicGenerator.generateColor(for: symbol)
        persistenceManager.saveColor(newColor, for: symbol)
        // print("🎨 [Hybrid] 生成新顏色: \(symbol)")
        return newColor
    }
    
    func colorForCash() -> Color {
        return cashColor
    }
    
    func getAllColors() -> [(symbol: String, color: Color)] {
        var allColors: [(symbol: String, color: Color)] = []
        
        // 添加預定義顏色
        for (symbol, color) in predefinedColors {
            allColors.append((symbol: symbol, color: color))
        }
        
        // 添加動態保存的顏色
        for (symbol, color) in persistenceManager.getAllSavedColors() {
            if predefinedColors[symbol] == nil { // 避免重複
                allColors.append((symbol: symbol, color: color))
            }
        }
        
        return allColors.sorted { $0.symbol < $1.symbol }
    }
    
    func clearDynamicColors() {
        persistenceManager.clearCache()
        // print("🎨 [Hybrid] 清除所有動態顏色")
    }
}