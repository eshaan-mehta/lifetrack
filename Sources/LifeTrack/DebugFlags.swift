import Foundation

/// Launch arguments for driving the app into a known state from the command line,
/// so screens can be screenshotted headlessly. Ignored unless passed explicitly.
///
///   --tab=food        start on the Food tab
///   --demo-food       seed a few analyzed entries so the ring shows progress
///   --show=add        open the add drawer on launch
///   --show=voice      open the drawer straight into voice capture
enum DebugFlags {
    private static let args = ProcessInfo.processInfo.arguments

    private static func value(_ name: String) -> String? {
        args.first { $0.hasPrefix("--\(name)=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init)
    }

    static var startTab: String? { value("tab") }
    static var show: String? { value("show") }
    static var demoFood: Bool { args.contains("--demo-food") }
}
