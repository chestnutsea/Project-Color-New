//
//  StyleEntity+CoreDataProperties.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/8.
//
//

public import Foundation
public import CoreData


public typealias StyleEntityCoreDataPropertiesSet = NSSet

extension StyleEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StyleEntity> {
        return NSFetchRequest<StyleEntity>(entityName: "StyleEntity")
    }

    @NSManaged public var confidence: Double
    @NSManaged public var id: UUID?
    @NSManaged public var label: String?
    @NSManaged public var sourceModel: String?
    @NSManaged public var photos: NSSet?

}

// MARK: Generated accessors for photos
extension StyleEntity {

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: PhotoEntity)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: PhotoEntity)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSSet)

}

extension StyleEntity : Identifiable {

}
