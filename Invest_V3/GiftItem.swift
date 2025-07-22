import Foundation

// MARK: - 禮物項目模型
struct GiftItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
    let price: Double
    let description: String
    
    init(id: UUID = UUID(), name: String, icon: String, price: Double, description: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.price = price
        self.description = description
    }
}

// MARK: - 預設禮物
extension GiftItem {
    static let defaultGifts = [
        GiftItem(name: "花束", icon: "💐", price: 1, description: "表達感謝"),
        GiftItem(name: "火箭", icon: "🚀", price: 5, description: "超級支持"),
        GiftItem(name: "黃金", icon: "🏆", price: 10, description: "最高榮譽")
    ]
} 