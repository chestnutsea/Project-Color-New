//
//  ColorModels.swift
//  Project Color
//
//  Created by ChatGPT on 2025/11/8.
//

import CoreData
import Foundation

struct ColorSwatch: Identifiable, Hashable, Codable {
    var id: UUID
    var hex: String
    var l: Double
    var a: Double
    var b: Double
    var ratio: Double

    init(id: UUID = UUID(), hex: String, l: Double, a: Double, b: Double, ratio: Double) {
        self.id = id
        self.hex = hex
        self.l = l
        self.a = a
        self.b = b
        self.ratio = ratio
    }

    init(entity: ColorSwatchEntity) {
        self.id = entity.id ?? UUID()
        self.hex = entity.hex ?? ""
        self.l = entity.l
        self.a = entity.a
        self.b = entity.b
        self.ratio = entity.ratio
    }

    func update(_ entity: ColorSwatchEntity) {
        entity.id = id
        entity.hex = hex
        entity.l = l
        entity.a = a
        entity.b = b
        entity.ratio = ratio
    }
}

struct ColorStyle: Identifiable, Hashable, Codable {
    var id: UUID
    var label: String
    var confidence: Double
    var sourceModel: String

    init(id: UUID = UUID(), label: String, confidence: Double, sourceModel: String) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.sourceModel = sourceModel
    }

    init(entity: StyleEntity) {
        self.id = entity.id ?? UUID()
        self.label = entity.label ?? ""
        self.confidence = entity.confidence
        self.sourceModel = entity.sourceModel ?? ""
    }

    func update(_ entity: StyleEntity) {
        entity.id = id
        entity.label = label
        entity.confidence = confidence
        entity.sourceModel = sourceModel
    }
}

struct PhotoFeature: Identifiable, Hashable, Codable {
    var id: UUID
    var modelSource: String
    var dimension: Int
    var vector: [Float]

    init(id: UUID = UUID(), modelSource: String, dimension: Int, vector: [Float]) {
        self.id = id
        self.modelSource = modelSource
        self.dimension = dimension
        self.vector = vector
    }

    init(entity: FeatureEntity) {
        self.id = entity.id ?? UUID()
        self.modelSource = entity.modelSource ?? ""
        self.dimension = Int(entity.dimension)
        self.vector = PhotoFeature.decodeVector(from: entity.vector)
    }

    func update(_ entity: FeatureEntity) {
        entity.id = id
        entity.modelSource = modelSource
        entity.dimension = Int16(dimension)
        entity.vector = PhotoFeature.encode(vector: vector)
    }

    static func encode(vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    static func decodeVector(from data: Data?) -> [Float] {
        guard let data = data else { return [] }
        let count = data.count / MemoryLayout<Float>.stride
        return data.withUnsafeBytes { rawBuffer in
            guard let pointer = rawBuffer.bindMemory(to: Float.self).baseAddress else {
                return []
            }
            return Array(UnsafeBufferPointer(start: pointer, count: count))
        }
    }
}

