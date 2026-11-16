/// LaunchServices can retain the previous process briefly while Sparkle relaunches.
public enum ApplicationInstancePolicy {
    public static func shouldYield(isTerminated: Bool, isAlive: () -> Bool,
                                   activate: () -> Bool) -> Bool {
        guard !isTerminated, isAlive() else { return false }
        if activate() { return true }
        // The process may exit between discovery and activation during an update.
        return isAlive()
    }
}
