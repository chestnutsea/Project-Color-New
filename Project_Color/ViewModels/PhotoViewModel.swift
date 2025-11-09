//
//  PhotoViewModel.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import Foundation
import CoreData
import Combine

final class PhotoViewModel: ObservableObject {
    @Published var photos: [PhotoEntity] = []
    private let context = CoreDataManager.shared.viewContext

    func fetchAll() {
        let request: NSFetchRequest<PhotoEntity> = PhotoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PhotoEntity.timestamp, ascending: false)]
        do {
            photos = try context.fetch(request)
        } catch {
            print("❌ Failed to fetch photos: \(error.localizedDescription)")
        }
    }

    func add(assetLocalId: String, toneCategory: String) {
        let newPhoto = PhotoEntity(context: context)
        newPhoto.id = UUID()
        newPhoto.assetLocalId = assetLocalId
        newPhoto.timestamp = Date()
        newPhoto.toneCategory = toneCategory
        try? CoreDataManager.shared.save(context: context)
        fetchAll()
    }

    func delete(_ photo: PhotoEntity) {
        context.delete(photo)
        try? CoreDataManager.shared.save(context: context)
        fetchAll()
    }
}
