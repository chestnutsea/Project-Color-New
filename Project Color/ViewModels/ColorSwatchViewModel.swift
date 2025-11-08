//
//  ColorSwatchViewModel.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/9.
//

import Foundation
import CoreData
import Combine

final class ColorSwatchViewModel: ObservableObject {
    @Published var swatches: [ColorSwatchEntity] = []
    private let context = DataController.shared.context

    func fetch(for photo: PhotoEntity? = nil) {
        let request: NSFetchRequest<ColorSwatchEntity> = ColorSwatchEntity.fetchRequest()
        if let photo = photo {
            request.predicate = NSPredicate(format: "photo == %@", photo)
        }
        do {
            swatches = try context.fetch(request)
        } catch {
            print("❌ Failed to fetch color swatches: \(error.localizedDescription)")
        }
    }

    func addColor(to photo: PhotoEntity, hex: String, l: Double, a: Double, b: Double, ratio: Double) {
        let color = ColorSwatchEntity(context: context)
        color.id = UUID()
        color.hex = hex
        color.l = l
        color.a = a
        color.b = b
        color.ratio = ratio
        color.photo = photo
        DataController.shared.saveContext()
        fetch(for: photo)
    }
}
