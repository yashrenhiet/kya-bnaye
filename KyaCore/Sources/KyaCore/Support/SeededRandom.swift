/// A deterministic SplitMix64 random number generator.
///
/// The same seed always yields the same sequence on every platform and Swift
/// version, which makes seeded behaviour (e.g. deck building) golden-testable.
/// Reference algorithm: Steele, Lea & Flood, "Fast Splittable Pseudorandom
/// Number Generators" (2014), as in `splitmix64.c` by Sebastiano Vigna.
///
/// Not cryptographically secure. The stdlib's `random(in:using:)` and
/// `shuffled(using:)` accept this generator but their algorithms are not
/// guaranteed stable across Swift versions — use ``nextInt(below:)``,
/// ``nextDouble()`` and ``shuffle(_:)`` when output must be reproducible
/// forever.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// Creates a generator whose sequence is fully determined by `seed`.
    ///
    /// - Parameter seed: Any 64-bit value, including `0`.
    public init(seed: UInt64) {
        state = seed
    }

    /// Creates a generator from a signed seed (e.g. ``SwipeEvent/deckSeed``),
    /// reinterpreting its bits so every `Int` maps to a distinct seed.
    ///
    /// - Parameter seed: Any `Int` value, including negatives.
    public init(seed: Int) {
        self.init(seed: UInt64(bitPattern: Int64(seed)))
    }

    /// Advances the state and returns the next 64 pseudo-random bits.
    ///
    /// - Returns: The next value of the SplitMix64 sequence.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniformly distributed double in `0..<1`, built from the top 53 bits of
    /// ``next()``.
    ///
    /// - Returns: A value `>= 0` and `< 1`.
    public mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// A uniformly distributed integer in `0..<upperBound`, without modulo
    /// bias (Lemire's multiply-and-reject method).
    ///
    /// - Parameter upperBound: Exclusive upper bound; must be positive.
    /// - Returns: A value `>= 0` and `< upperBound`.
    public mutating func nextInt(below upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let bound = UInt64(upperBound)
        let threshold = (0 &- bound) % bound
        while true {
            let (high, low) = next().multipliedFullWidth(by: bound)
            if low >= threshold {
                return Int(high)
            }
        }
    }

    /// Shuffles `array` in place with a Fisher–Yates shuffle driven by
    /// ``nextInt(below:)`` — reproducible for a given seed and input order.
    ///
    /// - Parameter array: The array to shuffle.
    public mutating func shuffle<Element>(_ array: inout [Element]) {
        guard array.count > 1 else { return }
        for index in stride(from: array.count - 1, to: 0, by: -1) {
            let other = nextInt(below: index + 1)
            array.swapAt(index, other)
        }
    }
}
