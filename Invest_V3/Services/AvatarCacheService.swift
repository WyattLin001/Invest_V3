//
//  AvatarCacheService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  頭像快取管理服務 - 提供高效的頭像載入和快取機制
//

import Foundation
import UIKit
import CryptoKit

/// 頭像快取服務
/// 負責頭像的下載、快取、清理和管理
class AvatarCacheService: ObservableObject {
    
    // MARK: - 單例模式
    static let shared = AvatarCacheService()
    
    // MARK: - 屬性
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7天
    
    // MARK: - 初始化
    private init() {
        // 設置快取目錄
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("AvatarCache")
        
        // 創建快取目錄
        createCacheDirectoryIfNeeded()
        
        // 配置記憶體快取
        cache.countLimit = 50 // 最多快取50張頭像
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB記憶體限制
        
        // 監聽記憶體警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 應用程式進入後台時清理過期快取
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupExpiredCache),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        print("✅ [AvatarCacheService] 初始化完成")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 公開方法
    
    /// 載入頭像（先從快取，再從網路）
    /// - Parameters:
    ///   - url: 頭像URL
    ///   - completion: 完成回調
    func loadAvatar(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = cacheKeyForURL(url)
        
        // 1. 首先檢查記憶體快取
        if let cachedImage = cache.object(forKey: cacheKey as NSString) {
            print("✅ [AvatarCacheService] 從記憶體快取載入頭像: \(url.lastPathComponent)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // 2. 檢查磁碟快取
        if let diskImage = loadFromDiskCache(cacheKey: cacheKey) {
            print("✅ [AvatarCacheService] 從磁碟快取載入頭像: \(url.lastPathComponent)")
            // 存入記憶體快取
            cache.setObject(diskImage, forKey: cacheKey as NSString)
            DispatchQueue.main.async {
                completion(diskImage)
            }
            return
        }
        
        // 3. 從網路下載
        print("🌐 [AvatarCacheService] 從網路下載頭像: \(url)")
        downloadAvatar(from: url, cacheKey: cacheKey, completion: completion)
    }
    
    /// 預載入頭像（異步，不回調）
    /// - Parameter url: 頭像URL
    func preloadAvatar(from url: URL) {
        loadAvatar(from: url) { _ in
            // 預載入不需要回調處理
        }
    }
    
    /// 清除特定頭像快取
    /// - Parameter url: 頭像URL
    func clearCache(for url: URL) {
        let cacheKey = cacheKeyForURL(url)
        cache.removeObject(forKey: cacheKey as NSString)
        removeDiskCache(cacheKey: cacheKey)
        print("🗑️ [AvatarCacheService] 已清除頭像快取: \(url.lastPathComponent)")
    }
    
    /// 清除所有快取
    func clearAllCache() {
        cache.removeAllObjects()
        clearDiskCache()
        print("🗑️ [AvatarCacheService] 已清除所有頭像快取")
    }
    
    /// 獲取快取統計信息
    func getCacheStatistics() -> AvatarCacheStatistics {
        let diskCacheSize = getDiskCacheSize()
        let fileCount = getDiskCacheFileCount()
        
        return AvatarCacheStatistics(
            memoryCount: cache.countLimit,
            memorySizeBytes: Int(cache.totalCostLimit),
            diskSizeBytes: diskCacheSize,
            diskFileCount: fileCount
        )
    }
    
    // MARK: - 私有方法
    
    /// 創建快取目錄
    private func createCacheDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("❌ [AvatarCacheService] 創建快取目錄失敗: \(error)")
        }
    }
    
    /// 生成快取鍵
    private func cacheKeyForURL(_ url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// 從磁碟快取載入
    private func loadFromDiskCache(cacheKey: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 檢查檔案是否過期
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let age = Date().timeIntervalSince(creationDate)
                if age > maxCacheAge {
                    // 檔案過期，刪除
                    try fileManager.removeItem(at: fileURL)
                    return nil
                }
            }
        } catch {
            print("⚠️ [AvatarCacheService] 檢查檔案屬性失敗: \(error)")
        }
        
        // 載入圖片
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    /// 網路下載頭像
    private func downloadAvatar(from url: URL, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [AvatarCacheService] 下載頭像失敗: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let data = data,
                  let image = UIImage(data: data) else {
                print("❌ [AvatarCacheService] 無法解析頭像數據")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 存入快取
            self.cache.setObject(image, forKey: cacheKey as NSString)
            self.saveToDiskCache(image: image, cacheKey: cacheKey)
            
            print("✅ [AvatarCacheService] 成功下載並快取頭像: \(url.lastPathComponent)")
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
    
    /// 存入磁碟快取
    private func saveToDiskCache(image: UIImage, cacheKey: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("❌ [AvatarCacheService] 存入磁碟快取失敗: \(error)")
        }
    }
    
    /// 移除磁碟快取
    private func removeDiskCache(cacheKey: String) {
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("⚠️ [AvatarCacheService] 移除磁碟快取失敗: \(error)")
        }
    }
    
    /// 清除磁碟快取
    private func clearDiskCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("❌ [AvatarCacheService] 清除磁碟快取失敗: \(error)")
        }
    }
    
    /// 獲取磁碟快取大小
    private func getDiskCacheSize() -> Int {
        var totalSize = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in contents {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let size = attributes[.size] as? Int {
                    totalSize += size
                }
            }
        } catch {
            print("⚠️ [AvatarCacheService] 計算磁碟快取大小失敗: \(error)")
        }
        
        return totalSize
    }
    
    /// 獲取磁碟快取檔案數量
    private func getDiskCacheFileCount() -> Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            print("⚠️ [AvatarCacheService] 計算磁碟快取檔案數量失敗: \(error)")
            return 0
        }
    }
    
    // MARK: - 通知處理
    
    @objc private func clearMemoryCache() {
        cache.removeAllObjects()
        print("🧹 [AvatarCacheService] 記憶體警告 - 已清除記憶體快取")
    }
    
    @objc private func cleanupExpiredCache() {
        Task {
            await cleanupExpiredCacheAsync()
        }
    }
    
    /// 異步清理過期快取
    private func cleanupExpiredCacheAsync() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            var expiredFiles: [URL] = []
            
            for fileURL in contents {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    let age = Date().timeIntervalSince(creationDate)
                    if age > maxCacheAge {
                        expiredFiles.append(fileURL)
                    }
                }
            }
            
            // 刪除過期檔案
            for fileURL in expiredFiles {
                try fileManager.removeItem(at: fileURL)
            }
            
            if !expiredFiles.isEmpty {
                print("🧹 [AvatarCacheService] 已清理 \(expiredFiles.count) 個過期快取檔案")
            }
            
        } catch {
            print("❌ [AvatarCacheService] 清理過期快取失敗: \(error)")
        }
    }
}

// MARK: - 快取統計資料結構
struct AvatarCacheStatistics {
    let memoryCount: Int
    let memorySizeBytes: Int
    let diskSizeBytes: Int
    let diskFileCount: Int
    
    var formattedMemorySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(memorySizeBytes), countStyle: .memory)
    }
    
    var formattedDiskSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskSizeBytes), countStyle: .file)
    }
}

// MARK: - SwiftUI 擴展
extension AvatarCacheService {
    
    /// SwiftUI 專用的頭像載入方法
    /// - Parameter url: 頭像URL
    /// - Returns: AsyncImage 可用的載入器
    func asyncImageLoader(for url: URL) -> AsyncImageLoader {
        return AsyncImageLoader(url: url, cacheService: self)
    }
}

// MARK: - AsyncImage 載入器
class AsyncImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    
    private let url: URL
    private let cacheService: AvatarCacheService
    
    init(url: URL, cacheService: AvatarCacheService) {
        self.url = url
        self.cacheService = cacheService
        loadImage()
    }
    
    private func loadImage() {
        isLoading = true
        
        cacheService.loadAvatar(from: url) { [weak self] image in
            DispatchQueue.main.async {
                self?.image = image
                self?.isLoading = false
            }
        }
    }
    
    func reload() {
        cacheService.clearCache(for: url)
        loadImage()
    }
}