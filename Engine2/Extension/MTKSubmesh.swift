import MetalKit

extension MTKSubmesh {
    /// Required byte count for this indexed draw, or `nil` when its index representation cannot be bounded safely.
    var requiredIndexByteCount: Int? {
        let bytesPerIndex: Int
        switch indexType {
        case .uint16:
            bytesPerIndex = MemoryLayout<UInt16>.stride

        case .uint32:
            bytesPerIndex = MemoryLayout<UInt32>.stride

        @unknown default:
            return nil
        }

        let result = indexCount.multipliedReportingOverflow(by: bytesPerIndex)
        return result.overflow ? nil : result.partialValue
    }
}
