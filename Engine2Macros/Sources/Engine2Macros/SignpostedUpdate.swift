import OSLog

/// Wraps a system's `update` body in a signposted interval named `update`.
///
/// The caller supplies the `OSSignposter` to use so signpost ownership stays
/// local to the system type instead of being pushed into a shared logging layer.
@available(macOS 12.0, *)
@attached(body)
public macro SignpostedUpdate(signposter: OSSignposter) =
    #externalMacro(module: "Engine2MacrosPlugin", type: "SignpostedUpdateMacro")
