import Foundation

/// A monotonic token for an async load that must not commit after it has been
/// superseded.
///
/// Every load begins a new generation. A response may only write to the model
/// when the generation it began with is still the newest: two overlapping
/// loads, or an A -> B -> A sequence, then cannot let an older answer land
/// last and restore the previous list.
struct LoadGeneration: Equatable, Sendable {
    private(set) var current = 0

    /// Starts a load and returns the token it must present to commit.
    mutating func begin() -> Int {
        current += 1
        return current
    }

    /// Invalidates every load in flight without starting a new one, so a
    /// workspace reset cannot leave an old answer eligible to commit.
    mutating func invalidate() {
        current += 1
    }

    /// Whether `generation` is still the newest load.
    func isCurrent(_ generation: Int) -> Bool {
        generation == current
    }
}
