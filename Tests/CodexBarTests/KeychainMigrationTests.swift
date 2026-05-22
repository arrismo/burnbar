import Testing
@testable import CodexBar

struct KeychainMigrationTests {
    @Test
    func `migration list covers known keychain items`() {
        let items = Set(KeychainMigration.itemsToMigrate.map(\.label))
        let expected: Set = [
            "com.arrismo.Burnbar:codex-cookie",
            "com.arrismo.Burnbar:claude-cookie",
            "com.arrismo.Burnbar:cursor-cookie",
            "com.arrismo.Burnbar:factory-cookie",
            "com.arrismo.Burnbar:minimax-cookie",
            "com.arrismo.Burnbar:minimax-api-token",
            "com.arrismo.Burnbar:augment-cookie",
            "com.arrismo.Burnbar:copilot-api-token",
            "com.arrismo.Burnbar:zai-api-token",
            "com.arrismo.Burnbar:synthetic-api-key",
        ]

        let missing = expected.subtracting(items)
        #expect(missing.isEmpty, "Missing migration entries: \(missing.sorted())")
    }
}
