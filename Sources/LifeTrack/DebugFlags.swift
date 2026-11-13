import Foundation

/// Launch arguments for driving the app into a known state from the command line,
/// so screens can be screenshotted headlessly. Ignored unless passed explicitly.
///
///   --tab=food        start on the Food tab
///   --demo-food       seed a few analyzed entries so the ring shows progress
///   --show=add        open the add drawer on launch
///   --show=voice      same as add (the drawer opens listening)
///   --show=camera     open the drawer in camera mode
///   --show=calendar   open the day picker
///   --day=-1          start the Food tab on yesterday
///   --demo-transcript with --show=voice, land in the review state with sample text
enum DebugFlags {
    private static let args = ProcessInfo.processInfo.arguments

    private static func value(_ name: String) -> String? {
        args.first { $0.hasPrefix("--\(name)=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init)
    }

    static var startTab: String? { value("tab") }
    /// Start the Food tab this many days from today, e.g. -1 for yesterday.
    static var dayOffset: Int { value("day").flatMap(Int.init) ?? 0 }
    static var show: String? { value("show") }
    static var demoFood: Bool { args.contains("--demo-food") }
    /// Pretend a transcription just finished, to show the review state.
    static var demoTranscript: Bool { args.contains("--demo-transcript") }
}
