import KyaCore
import Testing

@Suite("SeededGenerator")
struct SeededGeneratorTests {
    private func take(_ count: Int, seed: UInt64) -> [UInt64] {
        var generator = SeededGenerator(seed: seed)
        return (0..<count).map { _ in generator.next() }
    }

    @Test("seed 42 yields the SplitMix64 reference sequence")
    func referenceValuesForSeed42() {
        #expect(
            take(5, seed: 42) == [
                0xBDD7_3226_2FEB_6E95,
                0x28EF_E333_B266_F103,
                0x4752_6757_130F_9F52,
                0x581C_E1FF_0E4A_E394,
                0x09BC_585A_2448_23F2,
            ])
    }

    @Test("seed 0 yields the published SplitMix64 first value")
    func referenceValueForSeed0() {
        #expect(take(1, seed: 0) == [0xE220_A839_7B1D_CDAF])
    }

    @Test("the same seed always yields the same sequence")
    func sameSeedSameSequence() {
        #expect(take(100, seed: 7) == take(100, seed: 7))
    }

    @Test("different seeds yield different sequences")
    func differentSeedsDiffer() {
        #expect(take(10, seed: 1) != take(10, seed: 2))
    }

    @Test("a signed seed reinterprets its bit pattern")
    func signedSeed() {
        var signed = SeededGenerator(seed: -1)
        var unsigned = SeededGenerator(seed: UInt64.max)
        #expect(signed.next() == unsigned.next())
        #expect(take(1, seed: UInt64.max) == [16_490_336_266_968_443_936])
    }

    @Test("nextDouble is in 0..<1 and matches the 53-bit reference")
    func nextDouble() {
        var generator = SeededGenerator(seed: 42)
        #expect(generator.nextDouble() == 0.7415648787718233)
        for _ in 0..<1_000 {
            let value = generator.nextDouble()
            #expect(value >= 0 && value < 1)
        }
    }

    @Test("nextInt(below:) is in range and matches the reference")
    func nextIntBelow() {
        var generator = SeededGenerator(seed: 42)
        #expect((0..<8).map { _ in generator.nextInt(below: 10) } == [7, 1, 2, 3, 0, 8, 2, 8])
        for bound in 1...50 {
            let value = generator.nextInt(below: bound)
            #expect(value >= 0 && value < bound)
        }
    }

    @Test("shuffle is a deterministic permutation")
    func shuffle() {
        var generator = SeededGenerator(seed: 42)
        var values = Array(0..<10)
        generator.shuffle(&values)
        #expect(values == [8, 3, 6, 5, 4, 0, 9, 2, 1, 7])
        #expect(values.sorted() == Array(0..<10))
    }

    @Test("shuffling zero or one element consumes no randomness")
    func shuffleTrivial() {
        var generator = SeededGenerator(seed: 42)
        var empty: [Int] = []
        var single = [1]
        generator.shuffle(&empty)
        generator.shuffle(&single)
        #expect(empty.isEmpty)
        #expect(single == [1])
        #expect(generator.next() == 0xBDD7_3226_2FEB_6E95)
    }

    @Test("works with stdlib APIs taking a RandomNumberGenerator")
    func stdlibInterop() {
        var first = SeededGenerator(seed: 9)
        var second = SeededGenerator(seed: 9)
        #expect(
            Int.random(in: 0..<1_000, using: &first) == Int.random(in: 0..<1_000, using: &second))
    }
}
