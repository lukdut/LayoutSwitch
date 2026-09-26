public enum InputSourceCycle {
    /// nil means all available sources; an empty selection remains empty.
    public static func candidates(available: [String], selected: [String]?) -> [String] {
        let availableSet = Set(available)
        var seen = Set<String>()
        return (selected ?? available).filter { availableSet.contains($0) && seen.insert($0).inserted }
    }

    public static func next(available: [String], selected: [String]?, current: String?) -> String? {
        let ids = candidates(available: available, selected: selected)
        guard ids.count >= 2 else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return ids.first }
        return ids[(index + 1) % ids.count]
    }
}
