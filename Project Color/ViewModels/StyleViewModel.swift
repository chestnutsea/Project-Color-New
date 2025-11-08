//
//  StyleViewModel.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/9.
//

import Foundation
import CoreData
import Combine

final class StyleViewModel: ObservableObject {
    @Published var styles: [StyleEntity] = []
    private let context = DataController.shared.context

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
        DataController.shared.saveContext()
        fetchAll()
    }
}
