//
//  simd_extensions.swift
//  RubicCube
//
//  Created by Mateusz Kosikowski on 08/07/2025.
//

import Foundation
import simd

// MARK: - simd_float4x4 Extensions for common transforms

extension simd_float4x4 {
    /// Creates a translation matrix from a translation vector.
    ///
    /// - Parameter t: The translation vector.
    ///
    /// Use this initializer to create a matrix that moves objects by a specified amount in 3D space.
    ///
    /// Example:
    /// ```swift
    /// let translation = SIMD3<Float>(1, 2, 3)
    /// let matrix = simd_float4x4(translation: translation)
    /// ```
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }

    /// Creates a rotation matrix from a quaternion. - A version of existing initialiser for better readability
    ///
    /// - Parameter q: The quaternion representing a rotation.
    ///
    /// Use this initializer when you have an orientation stored as a quaternion (e.g., from 3D physics or animation systems) and need a 4x4 matrix for rendering or transformation.
    ///
    /// Example:
    /// ```swift
    /// let q = simd_quatf(angle: .pi, axis: SIMD3<Float>(0,1,0))
    /// let matrix = simd_float4x4(quaternion: q)
    /// ```
    init(quaternion q: simd_quatf) {
        self = simd_float4x4(q)
    }

    /// Creates a rotation matrix for a rotation around a specified axis by a given angle (in radians).
    ///
    /// - Parameters:
    ///   - axis: The axis to rotate around.
    ///   - angle: The angle in radians.
    ///
    /// Useful for rotating objects by a fixed angle around a known axis (e.g., turning an object around the Y-axis).
    ///
    /// Example:
    /// ```swift
    /// let axis = SIMD3<Float>(0, 1, 0) // Y-axis
    /// let matrix = simd_float4x4(rotationAbout: axis, angle: .pi/2)
    /// ```
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

    /// Creates a perspective projection matrix.
    ///
    /// - Parameters:
    ///   - fovY: Field of view in the Y direction (in radians).
    ///   - aspectRatio: The aspect ratio of the viewport.
    ///   - nearZ: The distance to the near clipping plane.
    ///   - farZ: The distance to the far clipping plane.
    ///
    /// Use this to set up camera projection for 3D rendering (e.g., OpenGL/Metal/Vulkan pipeline setups).
    ///
    /// Example:
    /// ```swift
    /// let projection = simd_float4x4(perspectiveFov: .pi/3, aspectRatio: 16.0/9.0, nearZ: 0.1, farZ: 100)
    /// ```
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

    /// Creates a view matrix that transforms world coordinates to camera coordinates using the look-at pattern.
    ///
    /// - Parameters:
    ///   - eye: The camera position.
    ///   - center: The point the camera is looking at.
    ///   - up: The up direction.
    ///
    /// Typically used for camera positioning in 3D scenes—follows the classic look-at convention.
    ///
    /// Example:
    /// ```swift
    /// let eye = SIMD3<Float>(0, 0, 10)
    /// let center = SIMD3<Float>(0, 0, 0)
    /// let up = SIMD3<Float>(0, 1, 0)
    /// let viewMatrix = simd_float4x4(lookAtEye: eye, center: center, up: up)
    /// ```
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
