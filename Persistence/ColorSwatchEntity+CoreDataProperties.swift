//
//  ColorSwatchEntity+CoreDataProperties.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/8.
//
//

public import Foundation
public import CoreData


public typealias ColorSwatchEntityCoreDataPropertiesSet = NSSet

extension ColorSwatchEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ColorSwatchEntity> {
        return NSFetchRequest<ColorSwatchEntity>(entityName: "ColorSwatchEntity")
    }

    @NSManaged public var a: Double
    @NSManaged public var hex: String?
    @NSManaged public var id: UUID?
    @NSManaged public var l: Double
    @NSManaged public var ratio: Double
    @NSManaged public var b: Double
    @NSManaged public var photo: PhotoEntity?

}

extension ColorSwatchEntity : Identifiable {

}
