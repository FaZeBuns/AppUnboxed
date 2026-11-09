import UIKit

/// Developer-only test harness. It switches on only when a flag file exists at
/// a path a sandboxed install can never see, so on the iPhone Duo it is inert.
/// On the jailbroken build phone it auto-plays the unbox and saves window
/// snapshots + a scan log so a build can be checked without touching the device.
enum DebugHarness {

    private static let flagPath = "/var/mobile/Documents/appunboxed_debug"
    private static let outDir = "/var/mobile/Documents/au_shots"
    static let enabled: Bool = FileManager.default.fileExists(atPath: flagPath)

    private static var timer: Timer?
    private static var frame = 0

    static func log(_ line: String) {
        guard enabled else { return }
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let path = outDir + "/log.txt"
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    static func start(window: UIWindow) {
        guard enabled else { return }
        try? FileManager.default.removeItem(atPath: outDir)
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        log("harness start, window \(window.bounds.size)")

        // A second flag file skips the auto-play, for timing the app scan alone.
        if !FileManager.default.fileExists(atPath: flagPath + "_noplay") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                DuoHingeSensor.shared.setFoldedState(false)
            }
        }
        frame = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { t in
            frame += 1
            if frame > 75 { t.invalidate(); log("harness done"); return }
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            var drew = false
            var image = renderer.image { ctx in
                UIColor.black.setFill()
                ctx.fill(window.bounds)
                drew = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
            if !drew {
                // Display asleep: fall back to a flat render of the layer tree
                // (shows the SwiftUI screens; 3D transform layers are skipped).
                image = renderer.image { ctx in
                    UIColor.black.setFill()
                    ctx.fill(window.bounds)
                    window.layer.render(in: ctx.cgContext)
                }
            }
            if let data = image.jpegData(compressionQuality: 0.6) {
                let name = String(format: "%@/f%03d.jpg", outDir, frame)
                try? data.write(to: URL(fileURLWithPath: name))
            }
        }
    }
}
