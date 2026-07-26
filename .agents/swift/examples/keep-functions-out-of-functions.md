# Keep Function Declarations at Type Scope

Never declare a helper function inside an initializer, method, accessor, or closure. A local `func` hides reusable
behavior inside one execution path, makes the surrounding function harder to scan, and leaves the helper without a
clear owner.

```swift
// Avoid: geometry validation is buried inside model initialization.
init(meshes: [MTKMesh]) {
    func containsUsableBytes(_ meshBuffer: MTKMeshBuffer, minimumByteCount: Int) -> Bool {
        // ...
    }

    // ...
}
```

Put the operation on the value it examines when that receiver is its natural owner:

```swift
extension MTKMeshBuffer {
    func containsUsableBytes(minimumByteCount: Int) -> Bool {
        // ...
    }
}
```

For a repository-owned type, keep the member in that type's owning file. For a framework or other externally owned
type, use a dedicated file named for that type under `Extension/`.

When no receiver naturally owns the behavior, prefer a private instance method on the coordinating type or a focused
collaborator with a real domain role. Do not replace a nested function with a static helper dumping ground. A local
closure remains appropriate only when closure identity, capture, or first-class passage is the actual design—not as a
different spelling for a hidden helper function.
