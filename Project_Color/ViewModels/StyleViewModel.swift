//
//  StyleViewModel.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import Foundation
import CoreData
import Combine

final class StyleViewModel: ObservableObject {
    @Published var styles: [StyleEntity] = []
    private let context = CoreDataManager.shared.viewContext

    func fetchAll() {
        let request: NSFetchRequest<StyleEntity> = StyleEntity.fetchRequest()
        do {
            styles = try context.fetch(request)
        } catch {
            print("❌ Failed to fetch styles: \(error.localizedDescription)")
        }
    }

    func addStyle(label: String, confidence: Double, sourceModel: String, to photo: PhotoEntity) {
        let style = StyleEntity(context: context)
        style.id = UUID()
        style.label = label
        style.confidence = confidence
        style.sourceModel = sourceModel
        style.addToPhotos(photo)
        try? CoreDataManager.shared.save(context: context)
        fetchAll()
    }
}
