//
//  RotatableGrid3D.swift
//  RubicCubeSolver
//
//  Created by Mateusz Kosikowski on 08/07/2025.
//
import Foundation

/// A generic NxNxN grid/container that can rotate layers or arbitrary axes, shuffling contained elements.
public struct RotatableGrid3D<Element> {
    public let size: Int
    private var storage: [Element] // Always size^3 elements, z-major order (z changes fastest)

    public init(size: Int = 3, repeating repeatedValue: Element) {
        precondition(size > 0, "Grid size must be positive")
        self.size = size
        self.storage = Array(repeating: repeatedValue, count: size * size * size)
    }

    public init(size: Int = 3, _ elements: [Element]) {
        precondition(size > 0, "Grid size must be positive")
        precondition(elements.count == size * size * size, "A NxNxN grid requires exactly N^3 elements, got \(elements.count)")
        self.size = size
        self.storage = elements
    }

    /// Get or set an element at position (x, y, z), 0...(size-1) for each
    public subscript(x: Int, y: Int, z: Int) -> Element {
        get { storage[index(x, y, z)] }
        set { storage[index(x, y, z)] = newValue }
    }
    /// Get or set by SIMD3<Int>
    public subscript(pos: SIMD3<Int>) -> Element {
        get { self[pos.x, pos.y, pos.z] }
        set { self[pos.x, pos.y, pos.z] = newValue }
    }
    /// Flat access
    public subscript(index: Int) -> Element {
        get { storage[index] }
        set { storage[index] = newValue }
    }

    /// Utility: 3D (x,y,z) to flat index
    private func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        precondition((0..<size).contains(x) && (0..<size).contains(y) && (0..<size).contains(z))
        return z * size * size + y * size + x
    }

    /// Utility: flat index to 3D position
    public func position(for index: Int) -> SIMD3<Int> {
        let z = index / (size * size)
        let y = (index % (size * size)) / size
        let x = index % size
        return SIMD3<Int>(x, y, z)
    }

    /// Returns storage as a flat array
    public var elements: [Element] { storage }

    /// Rotates a layer (0 to size-1) around the given axis (.x, .y, .z), clockwise or counterclockwise
    public mutating func rotateLayer(axis: Axis, layer: Int, clockwise: Bool = true) {
        precondition((0..<size).contains(layer), "Layer must be between 0 and \(size - 1)")
        // Gather all indices in the specified layer
        var indices: [Int] = []
        for i in 0..<storage.count {
            let pos = position(for: i)
            switch axis {
            case .x: if pos.x == layer { indices.append(i) }
            case .y: if pos.y == layer { indices.append(i) }
            case .z: if pos.z == layer { indices.append(i) }
            }
        }
        // Map old positions to new positions in the layer
        var mapping: [Int: Int] = [:] // oldIndex -> newIndex
        for i in indices {
            let pos = position(for: i)
            // size x size 2D grid, rotate in the plane perpendicular to axis
            let newPos: SIMD3<Int>
            switch axis {
            case .x:
                // Rotate (y,z) plane
                newPos = clockwise ? SIMD3(pos.x, size - 1 - pos.z, pos.y) : SIMD3(pos.x, pos.z, size - 1 - pos.y)
            case .y:
                // Rotate (x,z) plane
                newPos = clockwise ? SIMD3(size - 1 - pos.z, pos.y, pos.x) : SIMD3(pos.z, pos.y, size - 1 - pos.x)
            case .z:
                // Rotate (x,y) plane
                newPos = clockwise ? SIMD3(size - 1 - pos.y, pos.x, pos.z) : SIMD3(pos.y, size - 1 - pos.x, pos.z)
            }
            let newIndex = index(newPos.x, newPos.y, newPos.z)
            mapping[i] = newIndex
        }
        // Perform the swap using a copy
        let copy = storage
        for (oldIndex, newIndex) in mapping {
            storage[newIndex] = copy[oldIndex]
        }
    }

    /// Supported axes for rotation
    public enum Axis { case x, y, z }
}
