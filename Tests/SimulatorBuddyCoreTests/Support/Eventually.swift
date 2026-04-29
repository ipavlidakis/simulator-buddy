import Foundation

/// Repeatedly evaluates an async predicate until it passes or times out.
func eventually(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    intervalNanoseconds: UInt64 = 25_000_000,
    operation: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
        if await operation() {
            return true
        }

        try? await Task.sleep(nanoseconds: intervalNanoseconds)
    }

    return await operation()
}
