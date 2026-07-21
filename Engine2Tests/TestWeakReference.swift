/// Test-only weak owner used to observe object lifetime without retaining it.
final class TestWeakReference<Object: AnyObject> {
    weak var value: Object?

    init(_ value: Object?) {
        self.value = value
    }
}
