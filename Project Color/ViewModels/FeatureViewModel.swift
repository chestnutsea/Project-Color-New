//
//  FeatureViewModel.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/9.
//

import Foundation
import CoreData
import Combine

final class FeatureViewModel: ObservableObject {
    @Published var features: [FeatureEntity] = []
    private let context = DataController.shared.context

    func fetch(for photo: PhotoEntity? = nil) {
        let request: NSFetchRequest<FeatureEntity> = FeatureEntity.fetchRequest()
        if let photo = photo {
            request.predicate = NSPredicate(format: "photo == %@", photo)
        }
        do {
            features = try context.fetch(request)
        } catch {
            print("❌ Failed to fetch features: \(error.localizedDescription)")
        }
    }

    func addFeature(to photo: PhotoEntity, modelSource: String, vector: Data, dimension: Int32) {
        let feature = FeatureEntity(context: context)
        feature.id = UUID()
        feature.modelSource = modelSource
        feature.vector = vector
        feature.dimension = dimension
        feature.photo = photo
        DataController.shared.saveContext()
        fetch(for: photo)
    }
}
