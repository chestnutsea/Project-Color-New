//
//  FeatureEntity+CoreDataProperties.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/8.
//
//

public import Foundation
public import CoreData


public typealias FeatureEntityCoreDataPropertiesSet = NSSet

extension FeatureEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FeatureEntity> {
        return NSFetchRequest<FeatureEntity>(entityName: "FeatureEntity")
    }

    @NSManaged public var dimension: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var modelSource: String?
    @NSManaged public var vector: Data?
    @NSManaged public var photo: PhotoEntity?

}

extension FeatureEntity : Identifiable {

}
