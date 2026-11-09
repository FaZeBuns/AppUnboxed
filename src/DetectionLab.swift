import Foundation
import UIKit

/// One-time self-test of every app-detection method, saved as
/// Documents/detection_report.json so it can be read back off the phone
/// (scripts/read_device_report.py). It answers "what does this iOS version
/// still tell a sandboxed app?" with evidence instead of guesswork.
///
/// Runs once per app version, after the first scan, on a background queue.
/// If a private API ever crashes the app mid-test, the next launch sees the
/// unfinished marker and skips the test instead of crashing again.
enum DetectionLab {

    private static let stateKey = "appunboxed.lab.state"
    private static let stageKey = "appunboxed.lab.stage"

    static func runOnceIfNeeded(openableSchemes: [String]) {
        let defaults = UserDefaults.standard
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let state = defaults.string(forKey: stateKey) ?? ""
        if state == "done \(version)" { return }
        if state == "started \(version)" {
            defaults.set("crashed \(version) at \(defaults.string(forKey: stageKey) ?? "?")", forKey: stateKey)
            return
        }
        if state.hasPrefix("crashed \(version)") { return }
        defaults.set("started \(version)", forKey: stateKey)
        defaults.synchronize()

        var ids = AppCatalog.all.map { $0.bundleID }
        ids.append(contentsOf: ["com.appunboxed.none.zz9", Bundle.main.bundleIdentifier ?? "self"])
        let schemes = AppCatalog.all.compactMap { c -> String? in
            c.scheme.isEmpty ? nil : c.scheme.components(separatedBy: ":").first
        }

        var report = AURunDetectionProbes(ids, schemes) { stage in
            defaults.set(stage, forKey: stageKey)
            defaults.synchronize()
        }
        report["version"] = version
        report["ios"] = UIDevice.current.systemVersion
        report["canOpenURL"] = openableSchemes
        report["testedIDs"] = ids.count

        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? data.write(to: docs.appendingPathComponent("detection_report.json"))
        }
        defaults.set("done \(version)", forKey: stateKey)
        DebugHarness.log("detection lab finished")
    }
}
