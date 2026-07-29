import MetalKit

extension MTKMeshBuffer {
    /// Whether this buffer exposes an in-bounds nonempty slice large enough for one required use.
    func containsUsableBytes(minimumByteCount: Int) -> Bool {
        guard minimumByteCount > 0,
              offset >= 0,
              length >= minimumByteCount
        else {
            return false
        }

        let sliceEnd = offset.addingReportingOverflow(length)
        return !sliceEnd.overflow && sliceEnd.partialValue <= buffer.length
    }
}
