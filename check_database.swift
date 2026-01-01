import Foundation
import CoreData

// 检查 Core Data 数据库中的照片数据
print("🔍 检查 Core Data 数据库...")

// 这里需要实际的数据库路径
// 通常在: ~/Library/Developer/CoreSimulator/Devices/{UUID}/data/Containers/Data/Application/{UUID}/Library/Application Support/

print("请在 Xcode 中运行以下代码来检查数据库：")
print("""
let request = PhotoAnalysisEntity.fetchRequest()
let count = try? viewContext.count(for: request)
print("📊 数据库中的照片总数: \\(count ?? 0)")

let results = try? viewContext.fetch(request)
if let photos = results {
    for photo in photos.prefix(3) {
        print("📷 照片: \\(photo.assetLocalIdentifier ?? "nil")")
        print("   - dominantColors: \\(photo.dominantColors != nil ? "有" : "无")")
        print("   - thumbnailData: \\(photo.thumbnailData != nil ? "有" : "无")")
    }
}
""")
