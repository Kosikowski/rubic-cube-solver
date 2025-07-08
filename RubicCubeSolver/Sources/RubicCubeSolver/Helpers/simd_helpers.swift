//
//  simd_helpers.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 08/07/2025.
//

import Foundation
import simd

// MARK: - simd_float4x4 Extensions for common transforms

extension simd_float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }

    init(rotationAbout axis: SIMD3<Float>, angle: Float) {
        let a = normalize(axis)
        let x = a.x, y = a.y, z = a.z
        let c = cos(angle)
        let s = sin(angle)
        let mc = 1 - c

        self.init(SIMD4<Float>(c + mc * x * x, mc * x * y + z * s, mc * x * z - y * s, 0),
                  SIMD4<Float>(mc * x * y - z * s, c + mc * y * y, mc * y * z + x * s, 0),
                  SIMD4<Float>(mc * x * z + y * s, mc * y * z - x * s, c + mc * z * z, 0),
                  SIMD4<Float>(0, 0, 0, 1))
    }

    init(perspectiveFov fovY: Float, aspectRatio: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovY * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange

        self.init(SIMD4<Float>(xScale, 0, 0, 0),
                  SIMD4<Float>(0, yScale, 0, 0),
                  SIMD4<Float>(0, 0, zScale, -1),
                  SIMD4<Float>(0, 0, wzScale, 0))
    }

    init(lookAtEye eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) {
        let z = simd_normalize(eye - center)
        let x = simd_normalize(simd_cross(up, z))
        let y = simd_cross(z, x)

        let t = SIMD3<Float>(
            -simd_dot(x, eye),
            -simd_dot(y, eye),
            -simd_dot(z, eye)
        )

        self.init(SIMD4<Float>(x.x, y.x, z.x, 0),
                  SIMD4<Float>(x.y, y.y, z.y, 0),
                  SIMD4<Float>(x.z, y.z, z.z, 0),
                  SIMD4<Float>(t.x, t.y, t.z, 1))
    }
}
