import Foundation
import UIKit

public struct AppEntry: Identifiable, Hashable {
    public let id: String          // bundle identifier
    public let name: String
    public let scheme: String      // launch URL scheme, "" when unknown
    public let rarity: String      // "milspec", "restricted", "classified", "covert", "gold"
    public let systemIcon: String  // SF Symbol fallback
    public let icon: UIImage?      // the app's real icon when iOS hands it over

    public var color: UIColor {
        switch rarity {
        case "gold": return UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        case "covert": return UIColor(red: 0.92, green: 0.29, blue: 0.29, alpha: 1.0)
        case "classified": return UIColor(red: 0.83, green: 0.17, blue: 0.9, alpha: 1.0)
        case "restricted": return UIColor(red: 0.53, green: 0.28, blue: 1.0, alpha: 1.0)
        default: return UIColor(red: 0.29, green: 0.41, blue: 1.0, alpha: 1.0)
        }
    }

    public static func == (a: AppEntry, b: AppEntry) -> Bool { a.id == b.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Real app icons

/// Fetches another app's real home-screen icon through UIKit's private
/// `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]`.
/// For a bundle id that is not installed iOS returns a generic placeholder,
/// which doubles as an "is this app installed?" probe with no 50-scheme limit.
enum AppIconProvider {

    private typealias IconFn = @convention(c) (AnyClass, Selector, NSString, Int32, CGFloat) -> Unmanaged<UIImage>?
    private static let selector = NSSelectorFromString("_applicationIconImageForBundleIdentifier:format:scale:")

    private static let function: IconFn? = {
        guard let method = class_getClassMethod(UIImage.self, selector) else { return nil }
        return unsafeBitCast(method_getImplementation(method), to: IconFn.self)
    }()

    static var isAvailable: Bool { function != nil }

    /// format 2 is the 60pt home-screen icon; at scale 3 that is 180px.
    static func rawIcon(for bundleID: String, format: Int32 = 2, scale: CGFloat = 3.0) -> UIImage? {
        guard let function = function else { return nil }
        return function(UIImage.self, selector, bundleID as NSString, format, scale)?.takeUnretainedValue()
    }

    /// A small pixel signature, so the placeholder can be recognised reliably.
    static func signature(_ image: UIImage) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        return pixels
    }

    static func isSame(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return false }
        var diff = 0
        for i in 0..<a.count { diff += abs(Int(a[i]) - Int(b[i])) }
        return diff < a.count * 3
    }
}

// MARK: - Private LaunchServices (works only when iOS allows it)

enum LaunchServicesBridge {

    private static var workspace: AnyObject? {
        guard let cls = NSClassFromString("LSApplicationWorkspace") else { return nil }
        let clsObject = cls as AnyObject
        let sel = NSSelectorFromString("defaultWorkspace")
        guard clsObject.responds(to: sel) else { return nil }
        return clsObject.perform(sel)?.takeUnretainedValue()
    }

    /// Every installed user app as (bundle id, name). Empty when sandboxed off.
    static func installedUserApps() -> [(id: String, name: String)] {
        guard let ws = workspace else { return [] }
        let sel = NSSelectorFromString("allInstalledApplications")
        guard ws.responds(to: sel),
              let proxies = ws.perform(sel)?.takeUnretainedValue() as? [AnyObject] else { return [] }
        var out: [(id: String, name: String)] = []
        for proxy in proxies {
            guard let id = string(proxy, "applicationIdentifier"), !id.isEmpty else { continue }
            if let type = string(proxy, "applicationType"), type != "User" { continue }
            let name = string(proxy, "localizedName") ?? id
            out.append((id: id, name: name))
        }
        return out
    }

    static func open(bundleID: String) -> Bool {
        guard let ws = workspace else { return false }
        let sel = NSSelectorFromString("openApplicationWithBundleID:")
        guard ws.responds(to: sel), let method = class_getInstanceMethod(type(of: ws), sel) else { return false }
        typealias OpenFn = @convention(c) (AnyObject, Selector, NSString) -> Bool
        let fn = unsafeBitCast(method_getImplementation(method), to: OpenFn.self)
        return fn(ws, sel, bundleID as NSString)
    }

    private static func string(_ obj: AnyObject, _ name: String) -> String? {
        let sel = NSSelectorFromString(name)
        guard obj.responds(to: sel) else { return nil }
        return obj.perform(sel)?.takeUnretainedValue() as? String
    }
}

// MARK: - Installed check through LaunchServices (used only if it proves itself)

enum InstalledCheck {

    private static func workspaceCheck(_ id: String) -> Bool {
        guard let cls = NSClassFromString("LSApplicationWorkspace") else { return false }
        let clsObject = cls as AnyObject
        let def = NSSelectorFromString("defaultWorkspace")
        guard clsObject.responds(to: def), let ws = clsObject.perform(def)?.takeUnretainedValue() else { return false }
        let sel = NSSelectorFromString("applicationIsInstalled:")
        guard ws.responds(to: sel), let method = class_getInstanceMethod(type(of: ws), sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Bool
        return unsafeBitCast(method_getImplementation(method), to: Fn.self)(ws, sel, id as NSString)
    }

    private static func proxyCheck(_ id: String) -> Bool {
        guard let cls = NSClassFromString("LSApplicationProxy") else { return false }
        let clsObject = cls as AnyObject
        let make = NSSelectorFromString("applicationProxyForIdentifier:")
        guard clsObject.responds(to: make),
              let proxy = clsObject.perform(make, with: id as NSString)?.takeUnretainedValue() else { return false }
        let sel = NSSelectorFromString("isInstalled")
        guard proxy.responds(to: sel), let method = class_getInstanceMethod(type(of: proxy), sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(method_getImplementation(method), to: Fn.self)(proxy, sel)
    }

    /// A check is trusted only if it says "no" to a made-up app and "yes" to
    /// Settings; a sandbox that blocks it fails one of the two.
    static let function: ((String) -> Bool)? = {
        for check in [workspaceCheck, proxyCheck] {
            if !check("com.appunboxed.none.zz9") && check("com.apple.Preferences") { return check }
        }
        return nil
    }()
}

// MARK: - App Store icons (for apps iOS will not hand an icon over for)

enum RemoteIcons {

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("storeicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private static func file(_ id: String) -> URL {
        dir.appendingPathComponent(id.replacingOccurrences(of: "/", with: "_") + ".png")
    }

    static func cached(_ id: String) -> UIImage? {
        UIImage(contentsOfFile: file(id).path)
    }

    /// Batch-fetches artwork URLs for multiple bundle IDs in requests of up to 40 at a time.
    static func batchLookupArtwork(bundleIDs: [String]) -> [String: String] {
        guard !bundleIDs.isEmpty else { return [:] }
        var result: [String: String] = [:]
        let chunk = 40
        for i in stride(from: 0, to: bundleIDs.count, by: chunk) {
            let slice = Array(bundleIDs[i..<min(i + chunk, bundleIDs.count)])
            let idsParam = slice.joined(separator: ",")
            guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(idsParam)"),
                  let data = get(url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { continue }
            for item in results {
                if let bid = item["bundleId"] as? String,
                   var art = item["artworkUrl100"] as? String {
                    art = art.replacingOccurrences(of: "100x100bb", with: "256x256bb")
                    result[bid] = art
                }
            }
        }
        return result
    }

    /// Downloads an image from a URL and saves it to disk cache.
    static func downloadImage(from urlString: String, saveID id: String) -> UIImage? {
        if let hit = cached(id) { return hit }
        guard let url = URL(string: urlString),
              let data = get(url),
              let image = UIImage(data: data) else { return nil }
        try? data.write(to: file(id))
        return image
    }

    /// Blocking; call from a background queue only.
    static func fetch(id: String, artwork: String?) -> UIImage? {
        if let hit = cached(id) { return hit }
        var address = artwork
        if address == nil,
           let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(id)"),
           let data = get(url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let first = (json["results"] as? [[String: Any]])?.first {
            address = first["artworkUrl100"] as? String
        }
        guard var a = address else { return nil }
        a = a.replacingOccurrences(of: "100x100bb", with: "256x256bb")
        guard let url = URL(string: a), let data = get(url), let image = UIImage(data: data) else { return nil }
        try? data.write(to: file(id))
        return image
    }

    private static func get(_ url: URL) -> Data? {
        var result: Data?
        let done = DispatchSemaphore(value: 0)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if (response as? HTTPURLResponse)?.statusCode == 200 { result = data }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 12)
        return result
    }
}

// MARK: - Model

public class InstalledAppsModel: ObservableObject {
    @Published public var apps: [AppEntry] = []
    /// One line describing how the list was built, shown on the roll screen.
    @Published public var sourceStatus: String = "SCANNING APPS..."
    /// Bundle ids the user added by hand (always in the reel).
    @Published public var manualIDs: Set<String> = []
    /// False until the first full scan of this launch has finished. The
    /// case is held back until then so the reel has every app in it.
    @Published public var scanDone: Bool = false
    @Published public var scanFraction: Double = 0

    fileprivate static let rarityNames = ["g": "gold", "c": "covert", "k": "classified", "r": "restricted", "m": "milspec"]
    private static let tierWeights: [(String, Int)] = [
        ("gold", 2), ("covert", 8), ("classified", 16), ("restricted", 28), ("milspec", 46),
    ]
    private static let cacheKey = "appunboxed.foundApps.v2"
    private static let bigScanKey = "appunboxed.bigScanAt.v2"
    private static let manualKey = "appunboxed.manualApps.v1"
    private var isScanning = false
    private var rescanWanted = false
    /// Whether icons that iOS will not provide may be downloaded from Apple's
    /// public App Store lookup. On by default; the user can switch it off.
    public static var storeIconsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "appunboxed.storeIcons") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "appunboxed.storeIcons") }
    }
    /// Set while the crate or reel is animating so the big scan does not
    /// compete with it for CPU.
    public static var heavyScanPaused = false

    public init() {
        // Instant starter list so the reel is never empty; replaced by the scan.
        apps = AppCatalog.all
            .filter { AppCatalog.starterIDs.contains($0.bundleID) }
            .map { Self.entry(from: $0, icon: nil) }
        manualIDs = Set(Self.loadManual().map { $0[0] })
        scan()
        // Rescan every time the app comes back to the front, so apps installed
        // or deleted since the last spin are picked up.
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.scan()
        }
    }

    fileprivate static func entry(from c: CatalogApp, icon: UIImage?) -> AppEntry {
        AppEntry(id: c.bundleID, name: c.name, scheme: c.scheme,
                 rarity: rarityNames[c.rarity] ?? "milspec", systemIcon: c.symbol, icon: icon)
    }

    /// Stable pseudo-random rarity for apps without a hand-picked one.
    fileprivate static func rarity(forUnknown id: String) -> String {
        let n = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1000 } % 100
        if n < 46 { return "milspec" }
        if n < 74 { return "restricted" }
        if n < 90 { return "classified" }
        if n < 98 { return "covert" }
        return "gold"
    }

    // MARK: Apps added by hand

    private static func loadManual() -> [[String]] {
        (UserDefaults.standard.array(forKey: manualKey) as? [[String]]) ?? []
    }

    public func addManual(id: String, name: String, artwork: String) {
        var rows = Self.loadManual().filter { $0[0] != id }
        rows.append([id, name, artwork])
        UserDefaults.standard.set(rows, forKey: Self.manualKey)
        manualIDs.insert(id)
    }

    public func removeManual(id: String) {
        UserDefaults.standard.set(Self.loadManual().filter { $0[0] != id }, forKey: Self.manualKey)
        manualIDs.remove(id)
    }

    // MARK: Scan

    /// Finds the apps on this device in passes, publishing after each:
    ///   1. apps added by hand + apps remembered from the last scan
    ///   2. the hand-curated catalog, checked every way iOS allows
    ///   3. the big App Store chart catalog (~10,000 apps and games)
    ///   4. App Store icons for anything found without an icon
    public func scan() {
        guard !isScanning else { rescanWanted = true; return }
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scanner = Scanner()
            let started = Date()

            func publish(_ final: Bool, note: String? = nil) {
                let apps = scanner.found
                let status = scanner.status(final: final, note: note)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if apps.count >= 4 { self.apps = apps }
                    self.sourceStatus = status
                }
            }
            scanner.onProgress = { done, total in
                let line = scanner.status(final: false, note: "CHECKING \(done)/\(total)")
                let fraction = 0.1 + 0.85 * Double(done) / Double(max(total, 1))
                DispatchQueue.main.async {
                    self?.sourceStatus = line
                    if self?.scanDone == false { self?.scanFraction = fraction }
                }
            }

            scanner.passManual(Self.loadManual())
            scanner.passCached(Self.loadCache())
            if scanner.found.count >= 4 { publish(false) }

            scanner.passCurated()
            publish(false)
            DispatchQueue.main.async { if self?.scanDone == false { self?.scanFraction = 0.15 } }
            DebugHarness.log(String(format: "curated pass: %d apps in %.2fs", scanner.found.count, Date().timeIntervalSince(started)))

            scanner.passPlugins()
            publish(false)
            DispatchQueue.main.async { if self?.scanDone == false { self?.scanFraction = 0.3 } }
            DebugHarness.log(String(format: "curated+plugins pass: %d apps in %.2fs", scanner.found.count, Date().timeIntervalSince(started)))

            // The big catalog takes most of a minute to probe, so it runs only
            // when iOS withheld the full list, and at most every 6 hours; in
            // between, its finds come back instantly from the cache.
            let lastBig = UserDefaults.standard.double(forKey: Self.bigScanKey)
            let now = Date().timeIntervalSince1970
            if !scanner.hasFullList && scanner.canProbe && now - lastBig > 6 * 3600 {
                if scanner.passBigCatalog() {
                    UserDefaults.standard.set(now, forKey: Self.bigScanKey)
                }
                publish(false)
            }
            Self.saveCache(scanner.found)

            scanner.passStoreIcons { publish(false, note: "FETCHING ICONS") }
            publish(true)
            DebugHarness.log(String(format: "full scan: %@ in %.2fs", scanner.status(final: true, note: nil), Date().timeIntervalSince(started)))
            DebugHarness.log("apps: " + scanner.found.map { "\($0.name)[\($0.icon == nil ? "sym" : "icon")]" }.joined(separator: ", "))

            let schemesForLab = scanner.openableSchemeList
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                DetectionLab.runOnceIfNeeded(openableSchemes: schemesForLab)
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isScanning = false
                self.scanFraction = 1
                self.scanDone = true
                UserDefaults.standard.set(self.sourceStatus, forKey: "appunboxed.debug.status")
                if self.rescanWanted { self.rescanWanted = false; self.scan() }
            }
        }
    }

    private static func loadCache() -> [[String]] {
        (UserDefaults.standard.array(forKey: cacheKey) as? [[String]]) ?? []
    }

    private static func saveCache(_ apps: [AppEntry]) {
        let rows = apps.map { [$0.id, $0.name, $0.scheme, $0.rarity, $0.systemIcon] }
        UserDefaults.standard.set(rows, forKey: cacheKey)
    }

    /// One scan's working state. Runs entirely on a background queue.
    private final class Scanner {
        private(set) var found: [AppEntry] = []
        var onProgress: ((Int, Int) -> Void)?

        private var seenIDs = Set<String>()
        private var seenNames = Set<String>()
        private let ownID = Bundle.main.bundleIdentifier ?? ""
        private var placeholder: [UInt8]? = nil
        private var smallPlaceholder: [UInt8]? = nil   // tiny-icon probe, used for the big catalog
        private var iconProbeWorks = false
        private let installedCheck = InstalledCheck.function
        private var lsApps: [(id: String, name: String)] = []
        private var openableSchemes = Set<String>()
        private var manual: [String: String] = [:]     // id -> artwork url

        // How each app was found, for the status line.
        private var byIcon = 0, byCheck = 0, byScheme = 0, byPlugin = 0, byHand = 0

        var hasFullList: Bool { !lsApps.isEmpty }
        var openableSchemeList: [String] { openableSchemes.sorted() }
        var canProbe: Bool { (iconProbeWorks && smallPlaceholder != nil) || installedCheck != nil }

        init() {
            // The icon probe is only trusted if several made-up bundle ids all
            // come back as the same generic placeholder.
            if AppIconProvider.isAvailable {
                let fakes = ["com.appunboxed.none.zz9", "org.nothing.qq7.fake", "net.absent.app.k3"]
                let sigs = fakes.compactMap { AppIconProvider.rawIcon(for: $0).flatMap(AppIconProvider.signature) }
                if sigs.count == fakes.count, sigs.dropFirst().allSatisfy({ AppIconProvider.isSame($0, sigs[0]) }) {
                    placeholder = sigs[0]
                    iconProbeWorks = true
                }
                let small = fakes.compactMap { AppIconProvider.rawIcon(for: $0, format: 0, scale: 1).flatMap(AppIconProvider.signature) }
                if small.count == fakes.count, small.dropFirst().allSatisfy({ AppIconProvider.isSame($0, small[0]) }) {
                    smallPlaceholder = small[0]
                }
            }
            lsApps = LaunchServicesBridge.installedUserApps()

            // URL schemes: direct LaunchServices check first (bypasses 50-scheme limit),
            // with UIApplication.canOpenURL fallback for sandboxed safety.
            var schemes = Set<String>()
            for c in AppCatalog.all where !c.scheme.isEmpty {
                if let url = URL(string: c.scheme) {
                    if AUIsApplicationAvailableToOpenURL(url) {
                        schemes.insert(c.scheme)
                    } else if DispatchQueue.main.sync(execute: { UIApplication.shared.canOpenURL(url) }) {
                        schemes.insert(c.scheme)
                    }
                }
            }
            openableSchemes = schemes
            // Kept for troubleshooting detection on a device.
            UserDefaults.standard.set(Array(schemes).sorted(), forKey: "appunboxed.debug.schemes")
            DebugHarness.log("iconProbe=\(iconProbeWorks) installedCheck=\(installedCheck != nil) ls=\(lsApps.count) schemes=\(schemes.count)")
        }

        @discardableResult
        private func add(_ e: AppEntry, dedupeName: Bool) -> Bool {
            guard e.id != ownID, !ownID.hasPrefix(e.id + "."), !seenIDs.contains(e.id) else { return false }
            let lowered = e.name.lowercased()
            if dedupeName && seenNames.contains(lowered) { return false }
            seenIDs.insert(e.id)
            seenNames.insert(lowered)
            found.append(e)
            return true
        }

        /// The app's real icon straight from iOS, or nil.
        private func deviceIcon(_ id: String) -> UIImage? {
            guard iconProbeWorks, let placeholder = placeholder,
                  let img = AppIconProvider.rawIcon(for: id),
                  let sig = AppIconProvider.signature(img),
                  !AppIconProvider.isSame(placeholder, sig) else { return nil }
            return img
        }

        func passManual(_ rows: [[String]]) {
            for row in rows where row.count == 3 {
                manual[row[0]] = row[2]
                let icon = deviceIcon(row[0]) ?? RemoteIcons.cached(row[0])
                if add(AppEntry(id: row[0], name: row[1], scheme: "",
                                rarity: InstalledAppsModel.rarity(forUnknown: row[0]),
                                systemIcon: "app.fill", icon: icon), dedupeName: false) { byHand += 1 }
            }
        }

        func passCached(_ rows: [[String]]) {
            for row in rows where row.count == 5 {
                let id = row[0]
                let icon = deviceIcon(id)
                guard icon != nil || installedCheck?(id) == true || (!row[2].isEmpty && openableSchemes.contains(row[2])) else { continue }
                if add(AppEntry(id: id, name: row[1], scheme: row[2], rarity: row[3],
                                systemIcon: row[4], icon: icon ?? RemoteIcons.cached(id)), dedupeName: true) {
                    count(icon: icon, id: id)
                }
            }
        }

        private func count(icon: UIImage?, id: String) {
            if icon != nil { byIcon += 1 }
            else if installedCheck?(id) == true { byCheck += 1 }
            else { byScheme += 1 }
        }

        func passCurated() {
            let lsIDs = Set(lsApps.map { $0.id })
            for c in AppCatalog.all {
                let icon = deviceIcon(c.bundleID)
                let installed = icon != nil
                    || lsIDs.contains(c.bundleID)
                    || installedCheck?(c.bundleID) == true
                    || (!c.scheme.isEmpty && openableSchemes.contains(c.scheme))
                guard installed else { continue }
                if add(InstalledAppsModel.entry(from: c, icon: icon ?? RemoteIcons.cached(c.bundleID)), dedupeName: true) {
                    count(icon: icon, id: c.bundleID)
                }
            }
            // Everything iOS itself reported (only when it allows the full list).
            for app in lsApps {
                let icon = deviceIcon(app.id)
                if add(AppEntry(id: app.id, name: app.name, scheme: "",
                                rarity: InstalledAppsModel.rarity(forUnknown: app.id),
                                systemIcon: "app.fill", icon: icon), dedupeName: true) { byIcon += 1 }
            }
        }

        /// Dynamically discovers installed user applications from LaunchServices plugin/extension
        /// registrations. This works on sandboxed/stock iOS devices (including iOS 27.1).
        func passPlugins() {
            let pluginApps = AUInstalledPluginApps()
            let catalogMap = Dictionary(AppCatalog.all.map { ($0.bundleID, $0) }, uniquingKeysWith: { a, _ in a })
            for dict in pluginApps {
                guard let id = dict["id"], !id.isEmpty else { continue }
                let name = dict["name"] ?? id
                let icon = deviceIcon(id) ?? RemoteIcons.cached(id)

                if let cat = catalogMap[id] {
                    let entry = AppEntry(id: id, name: cat.name, scheme: cat.scheme,
                                         rarity: InstalledAppsModel.rarityNames[cat.rarity] ?? "milspec",
                                         systemIcon: cat.symbol, icon: icon)
                    if add(entry, dedupeName: true) { byPlugin += 1 }
                } else {
                    let entry = AppEntry(id: id, name: name, scheme: "",
                                         rarity: InstalledAppsModel.rarity(forUnknown: id),
                                         systemIcon: "app.fill", icon: icon)
                    if add(entry, dedupeName: true) { byPlugin += 1 }
                }
            }
        }

        /// Cheap installed check for the big catalog. Safe from several threads.
        private func looksInstalled(_ id: String) -> Bool {
            if let ph = smallPlaceholder, iconProbeWorks,
               let img = AppIconProvider.rawIcon(for: id, format: 0, scale: 1),
               let sig = AppIconProvider.signature(img), !AppIconProvider.isSame(ph, sig) { return true }
            return installedCheck?(id) == true
        }

        /// Returns false if the pass could not run or its result was discarded.
        func passBigCatalog() -> Bool {
            guard canProbe,
                  let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let rows = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return false }
            let candidates: [(id: String, name: String, game: Bool)] = rows.compactMap { row in
                guard row.count >= 3, let id = row[0] as? String, let name = row[1] as? String,
                      !seenIDs.contains(id) else { return nil }
                return (id, name, (row[2] as? Int) == 1)
            }
            let began = Date()
            let lock = NSLock()
            var hitIndexes: [Int] = []
            var doneChunks = 0
            let chunk = 100
            let chunks = (candidates.count + chunk - 1) / chunk
            DispatchQueue.concurrentPerform(iterations: chunks) { c in
                // Stand aside while the crate or the reel is animating.
                while InstalledAppsModel.heavyScanPaused { usleep(150_000) }
                var local: [Int] = []
                for i in (c * chunk)..<min((c + 1) * chunk, candidates.count) where looksInstalled(candidates[i].id) {
                    local.append(i)
                }
                lock.lock()
                hitIndexes.append(contentsOf: local)
                doneChunks += 1
                let done = doneChunks
                lock.unlock()
                if done % 5 == 0 { onProgress?(min(done * chunk, candidates.count), candidates.count) }
            }
            DebugHarness.log(String(format: "big catalog: %d probed, %d hits, %.2fs", candidates.count, hitIndexes.count, Date().timeIntervalSince(began)))
            // If a large share "matched", the probe is lying; discard the pass.
            guard hitIndexes.count < max(50, candidates.count / 4) else {
                DebugHarness.log("big catalog discarded")
                return false
            }
            for i in hitIndexes.sorted() {
                let c = candidates[i]
                let icon = deviceIcon(c.id)
                if add(AppEntry(id: c.id, name: c.name, scheme: "",
                                rarity: InstalledAppsModel.rarity(forUnknown: c.id),
                                systemIcon: c.game ? "gamecontroller.fill" : "app.fill",
                                icon: icon ?? RemoteIcons.cached(c.id)), dedupeName: false) {
                    count(icon: icon, id: c.id)
                }
            }
            return true
        }

        /// Downloads App Store artwork for found apps iOS gave no icon for.
        func passStoreIcons(progress: () -> Void) {
            guard InstalledAppsModel.storeIconsEnabled else { return }

            // First check if any already have a cached icon on disk
            for (i, app) in found.enumerated() where app.icon == nil {
                if let disk = RemoteIcons.cached(app.id) {
                    found[i] = AppEntry(id: app.id, name: app.name, scheme: app.scheme, rarity: app.rarity,
                                        systemIcon: app.systemIcon, icon: disk)
                }
            }

            // Identify apps still needing icons (skip Apple system apps with no store presence)
            var needsLookup: [String] = []
            for app in found where app.icon == nil {
                if app.id.hasPrefix("com.apple.") && manual[app.id] == nil { continue }
                if manual[app.id] == nil {
                    needsLookup.append(app.id)
                }
            }

            // Fast batch lookup from iTunes Search API
            let artworkMap = RemoteIcons.batchLookupArtwork(bundleIDs: needsLookup)

            var fetched = 0
            for (i, app) in found.enumerated() where app.icon == nil {
                guard fetched < 150 else { break }
                if app.id.hasPrefix("com.apple.") && manual[app.id] == nil { continue }

                let artURL = manual[app.id] ?? artworkMap[app.id]
                guard let art = artURL,
                      let icon = RemoteIcons.downloadImage(from: art, saveID: app.id) else { continue }

                found[i] = AppEntry(id: app.id, name: app.name, scheme: app.scheme, rarity: app.rarity,
                                    systemIcon: app.systemIcon, icon: icon)
                fetched += 1
                if fetched % 5 == 0 { progress() }
            }
        }

        /// e.g. "95 APPS · 90 ICONS · SYS 37 · PLUGIN 42 · URL 16"
        func status(final: Bool, note: String?) -> String {
            let withIcons = found.filter { $0.icon != nil }.count
            var parts = ["\(found.count) APPS", "\(withIcons) ICONS"]
            if hasFullList { parts.append("FULL LIST") }
            else {
                if byIcon > 0 { parts.append("SYS \(byIcon)") }
                if byPlugin > 0 { parts.append("PLUGIN \(byPlugin)") }
                if byScheme > 0 { parts.append("URL \(byScheme)") }
                if byCheck > 0 { parts.append("LS \(byCheck)") }
            }
            if byHand > 0 { parts.append("ADDED \(byHand)") }
            if let note = note { parts.append(note) } else if !final { parts.append("SCANNING…") }
            return parts.joined(separator: " · ")
        }
    }

    // MARK: Weighted picks (CS:GO odds)

    /// Picks a tier by the drop odds (skipping empty tiers), then an app in it.
    public func randomWeighted() -> AppEntry? {
        guard !apps.isEmpty else { return nil }
        let byTier = Dictionary(grouping: apps, by: { $0.rarity })
        let live = Self.tierWeights.filter { !(byTier[$0.0] ?? []).isEmpty }
        let total = live.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return apps.randomElement() }
        var roll = Int.random(in: 0..<total)
        for (tier, weight) in live {
            if roll < weight { return byTier[tier]?.randomElement() }
            roll -= weight
        }
        return apps.randomElement()
    }

    /// A few app names in a tier, for the odds table.
    public func sampleNames(tier: String, limit: Int = 4) -> String {
        let names = apps.filter { $0.rarity == tier }.prefix(limit).map { $0.name }
        return names.isEmpty ? "—" : names.joined(separator: ", ")
    }

    // MARK: Launch

    public func launch(app: AppEntry) {
        if !app.scheme.isEmpty, let url = URL(string: app.scheme) {
            UIApplication.shared.open(url, options: [:]) { ok in
                if !ok {
                    if !AUOpenApplicationWithBundleID(app.id) {
                        _ = LaunchServicesBridge.open(bundleID: app.id)
                    }
                }
            }
        } else {
            if !AUOpenApplicationWithBundleID(app.id) {
                _ = LaunchServicesBridge.open(bundleID: app.id)
            }
        }
    }
}
