import Foundation

/// 6 primary categories for unboxing cases on iPhone Duo and iOS devices.
public enum AppCategory: String, CaseIterable, Identifiable, Codable {
    case all = "all"
    case games = "games"
    case social = "social"
    case media = "media"
    case food = "food"
    case tools = "tools"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "ALL"
        case .games: return "GAMES"
        case .social: return "SOCIAL"
        case .media: return "MEDIA"
        case .food: return "FOOD"
        case .tools: return "TOOLS"
        }
    }

    public var subtitle: String {
        switch self {
        case .all: return "EVERY APP · ONE CASE"
        case .games: return "GAMING CASE · PLAY SOMETHING NEW"
        case .social: return "SOCIAL CASE · CHAT & CONNECT"
        case .media: return "MEDIA CASE · STREAM & WATCH"
        case .food: return "FOOD CASE · WHAT'S FOR DINNER?"
        case .tools: return "TOOLS CASE · GET THINGS DONE"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .games: return "gamecontroller.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .media: return "play.tv.fill"
        case .food: return "fork.knife"
        case .tools: return "wrench.and.screwdriver.fill"
        }
    }

    public var emoji: String {
        switch self {
        case .all: return "⊞"
        case .games: return "🎮"
        case .social: return "💬"
        case .media: return "🎬"
        case .food: return "🍔"
        case .tools: return "⚙️"
        }
    }
}

/// One known app: bundle id, display name, launch URL scheme ("" when none is
/// known), rarity code (g gold, c covert, k classified, r restricted,
/// m mil-spec), fallback SF Symbol, and category classification.
struct CatalogApp {
    let bundleID: String
    let name: String
    let scheme: String
    let rarity: String
    let symbol: String
    let category: AppCategory

    init(_ bundleID: String, _ name: String, _ scheme: String, _ rarity: String, _ symbol: String, _ category: AppCategory = .tools) {
        self.bundleID = bundleID
        self.name = name
        self.scheme = scheme
        self.rarity = rarity
        self.symbol = symbol
        self.category = category
    }
}

/// A sandboxed sideload cannot ask iOS for the installed-app list, so the app
/// carries this catalog and probes each entry on the device. Entries that are
/// not installed are simply never shown; a wrong bundle id is harmless.
enum AppCatalog {

    static let all: [CatalogApp] = (system + social + media + food + tools + games).map { c in
        // Fill in a scheme from a locally generated list when the entry has none.
        if c.scheme.isEmpty, let scheme = extraSchemes[c.bundleID] {
            return CatalogApp(c.bundleID, c.name, scheme, c.rarity, c.symbol, c.category)
        }
        return c
    } + extra

    // Always present on any iPhone; used as the reel before detection finishes.
    static let starterIDs: Set<String> = [
        "com.apple.Preferences", "com.apple.camera", "com.apple.mobileslideshow",
        "com.apple.mobilesafari", "com.apple.MobileSMS", "com.apple.AppStore",
        "com.apple.mobilenotes", "com.apple.calculator", "com.apple.Maps",
        "com.apple.Music", "com.apple.mobiletimer", "com.apple.weather",
    ]

    static let system: [CatalogApp] = [
        CatalogApp("com.apple.Preferences", "Settings", "app-settings://", "r", "gearshape.fill", .tools),
        CatalogApp("com.apple.camera", "Camera", "camera://", "r", "camera.fill", .media),
        CatalogApp("com.apple.mobileslideshow", "Photos", "photos-redirect://", "r", "photo.on.rectangle", .media),
        CatalogApp("com.apple.mobilesafari", "Safari", "x-web-search://", "m", "safari.fill", .tools),
        CatalogApp("com.apple.MobileSMS", "Messages", "sms://", "m", "message.fill", .social),
        CatalogApp("com.apple.mobilephone", "Phone", "mobilephone://", "m", "phone.fill", .social),
        CatalogApp("com.apple.mobilemail", "Mail", "message://", "m", "envelope.fill", .social),
        CatalogApp("com.apple.Maps", "Maps", "maps://", "m", "map.fill", .tools),
        CatalogApp("com.apple.Music", "Music", "music://", "r", "music.note", .media),
        CatalogApp("com.apple.AppStore", "App Store", "itms-apps://", "r", "bag.fill", .tools),
        CatalogApp("com.apple.mobilenotes", "Notes", "mobilenotes://", "m", "note.text", .tools),
        CatalogApp("com.apple.calculator", "Calculator", "calc://", "m", "function", .tools),
        CatalogApp("com.apple.mobiletimer", "Clock", "clock-alarm://", "m", "clock.fill", .tools),
        CatalogApp("com.apple.weather", "Weather", "weather://", "m", "cloud.sun.fill", .tools),
        CatalogApp("com.apple.Passbook", "Wallet", "shoebox://", "r", "creditcard.fill", .tools),
        CatalogApp("com.apple.Health", "Health", "x-apple-health://", "m", "heart.fill", .tools),
        CatalogApp("com.apple.facetime", "FaceTime", "facetime://", "m", "video.fill", .social),
        CatalogApp("com.apple.podcasts", "Podcasts", "podcasts://", "m", "mic.fill", .media),
        CatalogApp("com.apple.tv", "TV", "videos://", "r", "tv.fill", .media),
        CatalogApp("com.apple.iBooks", "Books", "ibooks://", "m", "book.fill", .media),
        CatalogApp("com.apple.reminders", "Reminders", "x-apple-reminderkit://", "m", "checklist", .tools),
        CatalogApp("com.apple.mobilecal", "Calendar", "calshow://", "m", "calendar", .tools),
        CatalogApp("com.apple.stocks", "Stocks", "stocks://", "m", "chart.line.uptrend.xyaxis", .tools),
        CatalogApp("com.apple.VoiceMemos", "Voice Memos", "voicememos://", "m", "waveform", .media),
        CatalogApp("com.apple.findmy", "Find My", "findmy://", "m", "location.fill", .tools),
        CatalogApp("com.apple.shortcuts", "Shortcuts", "shortcuts://", "r", "square.stack.3d.up.fill", .tools),
        CatalogApp("com.apple.DocumentsApp", "Files", "shareddocuments://", "m", "folder.fill", .tools),
        CatalogApp("com.apple.Translate", "Translate", "", "m", "character.bubble.fill", .tools),
        CatalogApp("com.apple.Home", "Home", "com.apple.home://", "m", "house.fill", .tools),
        CatalogApp("com.apple.Fitness", "Fitness", "fitnessapp://", "m", "figure.run", .tools),
        CatalogApp("com.apple.compass", "Compass", "", "m", "location.north.fill", .tools),
        CatalogApp("com.apple.measure", "Measure", "", "m", "ruler.fill", .tools),
        CatalogApp("com.apple.tips", "Tips", "x-apple-tips://", "m", "lightbulb.fill", .tools),
        CatalogApp("com.apple.MobileAddressBook", "Contacts", "contacts://", "m", "person.crop.circle.fill", .social),
        CatalogApp("com.apple.freeform", "Freeform", "", "m", "scribble.variable", .tools),
        CatalogApp("com.apple.journal", "Journal", "", "m", "book.closed.fill", .tools),
        CatalogApp("com.apple.Passwords", "Passwords", "", "r", "key.fill", .tools),
        CatalogApp("com.apple.Magnifier", "Magnifier", "", "m", "magnifyingglass", .tools),
        CatalogApp("com.apple.news", "News", "applenews://", "m", "newspaper.fill", .media),
        CatalogApp("com.apple.games", "Games", "", "k", "gamecontroller.fill", .games),
        CatalogApp("com.apple.TestFlight", "TestFlight", "itms-beta://", "k", "airplane", .tools),
        CatalogApp("com.apple.store.Jolly", "Apple Store", "applestore://", "m", "bag", .tools),
        CatalogApp("com.apple.Bridge", "Watch", "", "m", "applewatch", .tools),
        CatalogApp("com.apple.mobilegarageband", "GarageBand", "garageband://", "r", "guitars.fill", .media),
        CatalogApp("com.apple.iMovie", "iMovie", "", "r", "film.fill", .media),
        CatalogApp("com.apple.Pages", "Pages", "", "m", "doc.text.fill", .tools),
        CatalogApp("com.apple.Numbers", "Numbers", "", "m", "tablecells.fill", .tools),
        CatalogApp("com.apple.Keynote", "Keynote", "", "m", "play.rectangle.fill", .tools),
        CatalogApp("com.apple.clips", "Clips", "", "m", "video.badge.plus", .media),
    ]

    static let social: [CatalogApp] = [
        CatalogApp("com.atebits.Tweetie2", "X", "twitter://", "c", "bubble.left.and.bubble.right.fill", .social),
        CatalogApp("com.burbn.instagram", "Instagram", "instagram://", "c", "camera.fill", .social),
        CatalogApp("com.zhiliaoapp.musically", "TikTok", "snssdk1233://", "c", "music.note", .social),
        CatalogApp("com.toyopagroup.picaboo", "Snapchat", "snapchat://", "c", "bolt.fill", .social),
        CatalogApp("com.hammerandchisel.discord", "Discord", "discord://", "k", "gamecontroller.fill", .social),
        CatalogApp("com.reddit.Reddit", "Reddit", "reddit://", "k", "antenna.radiowaves.left.and.right", .social),
        CatalogApp("com.facebook.Facebook", "Facebook", "fb://", "k", "person.2.fill", .social),
        CatalogApp("com.facebook.Messenger", "Messenger", "fb-messenger://", "r", "message.fill", .social),
        CatalogApp("net.whatsapp.WhatsApp", "WhatsApp", "whatsapp://", "k", "phone.bubble.left.fill", .social),
        CatalogApp("ph.telegra.Telegraph", "Telegram", "tg://", "k", "paperplane.fill", .social),
        CatalogApp("org.whispersystems.signal", "Signal", "sgnl://", "r", "lock.fill", .social),
        CatalogApp("com.burbn.barcelona", "Threads", "barcelona://", "k", "at", .social),
        CatalogApp("com.pinterest", "Pinterest", "pinterest://", "r", "pin.fill", .social),
        CatalogApp("com.linkedin.LinkedIn", "LinkedIn", "linkedin://", "m", "briefcase.fill", .social),
        CatalogApp("com.tumblr.tumblr", "Tumblr", "tumblr://", "r", "t.square.fill", .social),
        CatalogApp("com.bereal.BRAssets", "BeReal", "bereal://", "r", "camera.metering.center.weighted", .social),
        CatalogApp("tv.twitch", "Twitch", "twitch://", "c", "play.tv.fill", .social),
        CatalogApp("xyz.blueskyweb.app", "Bluesky", "bluesky://", "r", "cloud.fill", .social),
    ]

    static let media: [CatalogApp] = [
        CatalogApp("com.google.ios.youtube", "YouTube", "youtube://", "c", "play.rectangle.fill", .media),
        CatalogApp("com.google.ios.youtubemusic", "YouTube Music", "youtubemusic://", "k", "music.note.tv.fill", .media),
        CatalogApp("com.spotify.client", "Spotify", "spotify://", "k", "waveform", .media),
        CatalogApp("com.netflix.Netflix", "Netflix", "nflx://", "c", "film.fill", .media),
        CatalogApp("com.disney.disneyplus", "Disney+", "disneyplus://", "k", "sparkles.tv.fill", .media),
        CatalogApp("com.hulu.plus", "Hulu", "hulu://", "k", "tv.fill", .media),
        CatalogApp("com.amazon.aiv.AIVApp", "Prime Video", "aiv://", "k", "play.tv.fill", .media),
        CatalogApp("com.wbd.stream", "Max", "", "k", "tv.fill", .media),
        CatalogApp("com.crunchyroll.iphone", "Crunchyroll", "crunchyroll://", "k", "play.circle.fill", .media),
        CatalogApp("com.soundcloud.TouchApp", "SoundCloud", "soundcloud://", "r", "cloud.fill", .media),
        CatalogApp("com.shazam.Shazam", "Shazam", "shazam://", "r", "shazam.logo.fill", .media),
        CatalogApp("com.plexapp.plex", "Plex", "plex://", "r", "play.fill", .media),
        CatalogApp("org.videolan.vlc-ios", "VLC", "vlc://", "r", "cone.fill", .media),
        CatalogApp("com.lemon.lvoverseas", "CapCut", "capcut://", "r", "scissors", .media),
        CatalogApp("com.amazon.mp3.AmazonCloudPlayer", "Amazon Music", "amznmp3://", "r", "music.quarternote.3", .media),
        CatalogApp("com.pandora", "Pandora", "pandora://", "m", "music.mic", .media),
        CatalogApp("com.audible.iphone", "Audible", "audible://", "m", "headphones", .media),
        CatalogApp("com.clearchannel.iheartradio", "iHeart", "iheartradio://", "m", "radio.fill", .media),
        CatalogApp("com.google.ios.youtubeunplugged", "YouTube TV", "youtubetv://", "k", "tv.fill", .media),
        CatalogApp("net.zedge.wallpapers", "Zedge", "zedge://", "m", "photo.artframe", .media),
        CatalogApp("com.lightricks.Enlight-Editor", "Photoleap", "photoleap://", "r", "photo.fill", .media),
        CatalogApp("com.lightricks.Enlight-Quickart", "Artleap", "quickart://", "r", "paintpalette.fill", .media),
        CatalogApp("com.lightricks.Enlight-Phoenix", "Motionleap", "motionleap://", "r", "photo.stack.fill", .media),
    ]

    static let food: [CatalogApp] = [
        CatalogApp("com.mcdonalds.gma", "McDonald's", "mcdmobileapp://", "m", "fork.knife", .food),
        CatalogApp("com.starbucks.mystarbucks", "Starbucks", "starbucks://", "m", "cup.and.saucer.fill", .food),
        CatalogApp("com.ubercab.UberEats", "Uber Eats", "ubereats://", "r", "takeoutbag.and.cup.and.straw.fill", .food),
        CatalogApp("com.dd.doordash.DoorDash", "DoorDash", "doordash://", "r", "bag.fill", .food),
        CatalogApp("com.grubhub.search", "Grubhub", "grubhubapp://", "m", "bag.fill", .food),
        CatalogApp("com.dominos.iphone", "Domino's", "dominos://", "m", "fork.knife", .food),
        CatalogApp("com.imc2.iHut", "Pizza Hut", "pizzahut://", "m", "fork.knife", .food),
        CatalogApp("com.kfc.us.mobile", "KFC", "kfcmobile://", "m", "fork.knife", .food),
        CatalogApp("com.emn8.mobilem8.native.bkrewards", "Burger King", "burgerking://", "m", "fork.knife", .food),
        CatalogApp("com.chipotle.Chipotle", "Chipotle", "chipotle://", "m", "fork.knife", .food),
        CatalogApp("com.tacobell.ARgame", "Taco Bell", "", "m", "fork.knife", .food),
        CatalogApp("com.dairyqueen.ios.loyaltyapp.production", "Dairy Queen", "dairyqueen://", "m", "fork.knife", .food),
        CatalogApp("com.relevantmobile.firehousesubs", "Firehouse Subs", "firehousesubs://", "m", "fork.knife", .food),
        CatalogApp("com.splickit.jerseymikes", "Jersey Mike's", "jerseymikes://", "m", "fork.knife", .food),
        CatalogApp("com.papajohns.ios", "Papa Johns", "papajohns://", "m", "fork.knife", .food),
        CatalogApp("com.snapfinger.mobile.zaxbys", "Zaxbys", "zaxbys://", "m", "fork.knife", .food),
        CatalogApp("com.dunkinbrands.otgo", "Dunkin'", "dunkin://", "m", "cup.and.saucer.fill", .food),
        CatalogApp("com.jackinthebox.jibprod", "Jack in the Box", "jackinthebox://", "m", "fork.knife", .food),
        CatalogApp("com.jimmyjohns.jimmyjohns", "Jimmy John's", "jimmyjohns://", "m", "fork.knife", .food),
        CatalogApp("com.gopuff.gopuff", "Gopuff", "gopuff://", "m", "bag.fill", .food),
        CatalogApp("com.chick-fil-a.mobile", "Chick-fil-A", "chickfila://", "m", "fork.knife", .food),
        CatalogApp("com.wendys.iron", "Wendy's", "wendys://", "m", "fork.knife", .food),
        CatalogApp("com.panerabread.app", "Panera Bread", "panera://", "m", "fork.knife", .food),
        CatalogApp("com.subway.mobile.subwayapp", "Subway", "subway://", "m", "fork.knife", .food),
        CatalogApp("com.sonicdrivein", "Sonic Drive-In", "sonic://", "m", "fork.knife", .food),
        CatalogApp("com.crumblcookies.crumbl", "Crumbl Cookies", "crumbl://", "m", "fork.knife", .food),
        CatalogApp("com.sweetgreen.ios", "Sweetgreen", "sweetgreen://", "m", "leaf.fill", .food),
        CatalogApp("com.cava.cava", "CAVA", "cava://", "m", "fork.knife", .food),
        CatalogApp("com.instacart.client", "Instacart", "instacart://", "m", "cart.fill", .food),
        CatalogApp("com.postmates.ios", "Postmates", "postmates://", "m", "bag.fill", .food),
        CatalogApp("com.pandaexpress.app", "Panda Express", "pandaexpress://", "m", "fork.knife", .food),
        CatalogApp("com.wingstop.wings", "Wingstop", "wingstop://", "m", "fork.knife", .food),
        CatalogApp("com.whataburger.ordering", "Whataburger", "whataburger://", "m", "fork.knife", .food),
        CatalogApp("com.culvers.guest", "Culver's", "culvers://", "m", "fork.knife", .food),
    ]

    static let tools: [CatalogApp] = [
        CatalogApp("com.google.chrome.ios", "Chrome", "googlechrome://", "r", "globe", .tools),
        CatalogApp("com.google.Gmail", "Gmail", "googlegmail://", "r", "envelope.fill", .tools),
        CatalogApp("com.google.Maps", "Google Maps", "comgooglemaps://", "r", "mappin.and.ellipse", .tools),
        CatalogApp("com.google.GoogleMobile", "Google", "google://", "r", "magnifyingglass", .tools),
        CatalogApp("com.google.Drive", "Google Drive", "googledrive://", "m", "externaldrive.fill", .tools),
        CatalogApp("com.google.photos", "Google Photos", "googlephotos://", "m", "photo.stack.fill", .media),
        CatalogApp("com.google.Translate", "Google Translate", "googletranslate://", "m", "character.book.closed.fill", .tools),
        CatalogApp("org.mozilla.ios.Firefox", "Firefox", "firefox://", "r", "flame.fill", .tools),
        CatalogApp("com.brave.ios.browser", "Brave", "brave://", "r", "shield.fill", .tools),
        CatalogApp("com.openai.chat", "ChatGPT", "chatgpt://", "c", "bubble.left.fill", .tools),
        CatalogApp("com.anthropic.claude", "Claude", "claude://", "c", "sparkle", .tools),
        CatalogApp("com.google.gemini", "Gemini", "", "k", "sparkles", .tools),
        CatalogApp("com.amazon.Amazon", "Amazon", "com.amazon.mobile.shopping://", "r", "cart.fill", .tools),
        CatalogApp("com.ebay.iphone", "eBay", "ebay://", "m", "tag.fill", .tools),
        CatalogApp("com.walmart.electronics", "Walmart", "walmart://", "m", "cart", .tools),
        CatalogApp("com.target.Target", "Target", "target://", "m", "target", .tools),
        CatalogApp("com.ubercab.UberClient", "Uber", "uber://", "r", "car.fill", .tools),
        CatalogApp("com.zimride.instant", "Lyft", "lyft://", "m", "car.side.fill", .tools),
        CatalogApp("com.yourcompany.PPClient", "PayPal", "paypal://", "r", "dollarsign.circle.fill", .tools),
        CatalogApp("net.kortina.labs.Venmo", "Venmo", "venmo://", "r", "dollarsign.square.fill", .tools),
        CatalogApp("com.squareup.cash", "Cash App", "cashme://", "r", "dollarsign", .tools),
        CatalogApp("com.microsoft.Office.Outlook", "Outlook", "ms-outlook://", "m", "envelope.badge.fill", .tools),
        CatalogApp("com.microsoft.skype.teams", "Teams", "msteams://", "m", "person.3.fill", .social),
        CatalogApp("us.zoom.videomeetings", "Zoom", "zoomus://", "m", "video.fill", .social),
        CatalogApp("com.tinyspeck.chatlyio", "Slack", "slack://", "m", "number", .social),
        CatalogApp("com.getdropbox.Dropbox", "Dropbox", "dbapi-1://", "m", "shippingbox.fill", .tools),
        CatalogApp("com.duolingo.DuolingoMobile", "Duolingo", "duolingo://", "r", "bird.fill", .tools),
        CatalogApp("com.airbnb.app", "Airbnb", "airbnb://", "m", "house.fill", .tools),
        CatalogApp("com.yelp.yelpiphone", "Yelp", "yelp://", "m", "star.bubble.fill", .tools),
        CatalogApp("io.tailscale.ipn.ios", "Tailscale", "tailscale://", "k", "network", .tools),
        CatalogApp("com.valvesoftware.Steam", "Steam", "steammobile://", "c", "gamecontroller.fill", .games),
        CatalogApp("com.microsoft.smartglass", "Xbox", "xbox://", "k", "xbox.logo", .games),
        CatalogApp("com.nintendo.znca", "Nintendo Switch Online", "", "k", "gamecontroller", .games),
        CatalogApp("com.notion.Notion", "Notion", "notion://", "m", "doc.plaintext.fill", .tools),
        CatalogApp("com.kick.mobile", "Kick", "kick://", "k", "play.tv.fill", .media),
        CatalogApp("ai.x.GrokApp", "Grok", "xai-grok://", "k", "sparkle", .tools),
        CatalogApp("com.life360.safetymap", "Life360", "Life360://", "m", "location.circle.fill", .tools),
        CatalogApp("com.vilcsak.bitcoin2", "Coinbase", "com.coinbase.oauth://", "r", "bitcoinsign.circle.fill", .tools),
        CatalogApp("com.ring", "Ring", "ring://", "m", "bell.fill", .tools),
        CatalogApp("com.jadedlabs.arrive", "Shop", "shopapp://", "m", "bag.fill", .tools),
        CatalogApp("com.microsoft.skydrive", "OneDrive", "ms-onedrive://", "m", "cloud.fill", .tools),
        CatalogApp("com.blizzard.social", "Battle.net", "battlenet://", "k", "gamecontroller.fill", .games),
        CatalogApp("com.riotgames.mobile.leagueconnect", "Riot Mobile", "riotmobile://", "k", "shield.fill", .games),
        CatalogApp("com.giphy.giphyformessenger", "GIPHY", "giphy://", "m", "photo.stack.fill", .social),
        CatalogApp("com.google.Authenticator", "Google Authenticator", "googleauthenticator://", "m", "lock.shield.fill", .tools),
        CatalogApp("com.microsoft.azureauthenticator", "Microsoft Authenticator", "microsoft-authenticator://", "m", "lock.shield.fill", .tools),
        CatalogApp("com.github.stormbreaker.prod", "GitHub", "github://", "k", "chevron.left.forwardslash.chevron.right", .tools),
        CatalogApp("com.FetchRewards.HopBeta", "Fetch", "fetchrewards://", "m", "gift.fill", .tools),
        CatalogApp("com.hualai.WyzeCam", "Wyze", "wyze://", "m", "video.fill", .tools),
        CatalogApp("com.wohand.wohand", "SwitchBot", "switchbot://", "m", "switch.2", .tools),
        CatalogApp("im.talkme.talkmeim", "Talkatone", "tktn://", "m", "phone.fill", .social),
        CatalogApp("com.truesoftware.TrueCallerOther", "Truecaller", "truecaller://", "m", "phone.badge.checkmark", .social),
        CatalogApp("com.kalshi.mobile", "Kalshi", "kalshi://", "k", "chart.line.uptrend.xyaxis", .tools),
        CatalogApp("com.flipperdevices.main", "Flipper", "flipper://", "k", "wave.3.forward", .tools),
        CatalogApp("com.treshna.Gymmaster", "GymMaster", "gymmaster://", "m", "figure.strengthtraining.traditional", .tools),
        CatalogApp("com.bfac.HailTrace", "HailTrace", "hailtrace://", "m", "cloud.hail.fill", .tools),
        CatalogApp("org.bidmailers.mobile", "Bid Mailers", "bidmailers://", "m", "envelope.fill", .tools),
        CatalogApp("com.acornfinance.pro", "Acorn Finance", "acornfinancepro://", "m", "dollarsign.circle.fill", .tools),
        CatalogApp("com.logmein.ios.gotomypc", "GoToMyPC", "GoToMyPC://", "m", "display", .tools),
        CatalogApp("com.intuit.QBOiPad", "QuickBooks", "qb001://", "m", "dollarsign.square.fill", .tools),
        CatalogApp("mobi.mobilejump.freevpn", "VPN Super", "supervpn://", "m", "lock.shield.fill", .tools),
        CatalogApp("com.crystalnix.ServerAuditor", "Termius", "serverauditor://", "k", "terminal.fill", .tools),
        CatalogApp("com.truistmobile.truist", "Truist", "truist://", "m", "building.columns.fill", .tools),
        CatalogApp("com.moonlight-stream.Moonlight", "Moonlight", "", "k", "moon.fill", .games),
        CatalogApp("com.microsoft.LinkToWindows", "Link to Windows", "ms-linktowindows://", "m", "laptopcomputer.and.iphone", .tools),
        CatalogApp("com.secondline.message", "2nd Line", "", "m", "phone.fill", .social),
        CatalogApp("com.carnival.funhub", "Carnival HUB", "", "m", "ferry.fill", .tools),
        CatalogApp("com.nfl.gamecenter", "NFL", "", "m", "football.fill", .media),
    ]

    static let games: [CatalogApp] = [
        CatalogApp("com.roblox.robloxmobile", "Roblox", "roblox://", "g", "cube.fill", .games),
        CatalogApp("com.mojang.minecraftpe", "Minecraft", "minecraft://", "g", "cube.transparent.fill", .games),
        CatalogApp("com.epicgames.FortniteGame", "Fortnite", "FortniteClient://", "g", "scope", .games),
        CatalogApp("com.rockstargames.gtasa", "GTA: San Andreas", "", "g", "car.fill", .games),
        CatalogApp("com.supercell.magic", "Clash of Clans", "clashofclans://", "c", "shield.lefthalf.filled", .games),
        CatalogApp("com.supercell.scroll", "Clash Royale", "clashroyale://", "c", "crown.fill", .games),
        CatalogApp("com.supercell.laser", "Brawl Stars", "brawlstars://", "c", "star.fill", .games),
        CatalogApp("com.supercell.soil", "Hay Day", "", "r", "leaf.fill", .games),
        CatalogApp("com.kiloo.subwaysurfers", "Subway Surfers", "", "c", "tram.fill", .games),
        CatalogApp("com.robtopx.geometryjump", "Geometry Dash", "", "c", "square.fill", .games),
        CatalogApp("com.halfbrick.jetpack", "Jetpack Joyride", "", "k", "flame.fill", .games),
        CatalogApp("com.ninjakiwi.bloonstd6", "Bloons TD 6", "", "c", "balloon.fill", .games),
        CatalogApp("com.hipsterwhale.crossy", "Crossy Road", "", "k", "bird.fill", .games),
        CatalogApp("com.imangi.templerun2", "Temple Run 2", "", "k", "figure.run", .games),
        CatalogApp("com.popcap.ios.PVZ2", "Plants vs. Zombies 2", "", "k", "leaf.fill", .games),
        CatalogApp("jp.co.ponos.battlecatsen", "The Battle Cats", "ponos-battlecatsen://", "k", "cat.fill", .games),
        CatalogApp("io.randomco.travel", "Travel Town", "", "m", "gamecontroller.fill", .games),
        CatalogApp("com.valvesoftware.SteamLink17", "Steam Link", "steamlink://", "k", "gamecontroller.fill", .games),
        CatalogApp("com.miniclip.ghostinvasion", "Ghost Invasion", "com.miniclip.ghostinvasion://", "k", "ghost.fill", .games),
        CatalogApp("com.poncle.vampiresurvivors", "Vampire Survivors", "", "k", "moon.fill", .games),
        CatalogApp("com.innersloth.amongus", "Among Us", "", "c", "person.fill.questionmark", .games),
        CatalogApp("com.activision.callofduty.shooter", "Call of Duty: Mobile", "codm://", "c", "scope", .games),
        CatalogApp("com.miHoYo.GenshinImpact", "Genshin Impact", "", "c", "sparkles", .games),
        CatalogApp("com.nianticlabs.pokemongo", "Pokémon GO", "pokemongo://", "c", "circle.circle.fill", .games),
        CatalogApp("jp.pokemon.pokemontcgp", "Pokémon TCG Pocket", "", "k", "rectangle.stack.fill", .games),
        CatalogApp("com.king.candycrushsaga", "Candy Crush Saga", "", "r", "circle.hexagongrid.fill", .games),
        CatalogApp("com.tencent.ig", "PUBG Mobile", "", "c", "scope", .games),
        CatalogApp("com.dts.freefireth", "Free Fire", "", "k", "flame.fill", .games),
        CatalogApp("com.mobile.legends", "Mobile Legends", "", "k", "shield.fill", .games),
        CatalogApp("com.riotgames.league.wildrift", "Wild Rift", "", "k", "bolt.shield.fill", .games),
        CatalogApp("com.riotgames.league.teamfighttactics", "Teamfight Tactics", "", "k", "hexagon.fill", .games),
        CatalogApp("com.Psyonix.Sideswipe", "Rocket League Sideswipe", "", "k", "car.fill", .games),
        CatalogApp("com.blizzard.wtcg.hearthstone", "Hearthstone", "", "k", "suit.heart.fill", .games),
        CatalogApp("com.chess.iphone", "Chess", "", "r", "checkerboard.rectangle", .games),
        CatalogApp("com.scopely.monopolygo", "Monopoly GO!", "", "r", "dice.fill", .games),
        CatalogApp("com.dreamgames.royalmatch", "Royal Match", "", "r", "crown.fill", .games),
        CatalogApp("com.playrix.homescapes", "Homescapes", "", "r", "house.fill", .games),
        CatalogApp("com.fingersoft.hillclimbracing", "Hill Climb Racing", "", "r", "car.side.fill", .games),
        CatalogApp("com.fingersoft.hcr2", "Hill Climb Racing 2", "", "r", "car.side.fill", .games),
        CatalogApp("com.miniclip.8ballpoolmult", "8 Ball Pool", "", "r", "8.circle.fill", .games),
        CatalogApp("com.505games.terraria", "Terraria", "", "k", "tree.fill", .games),
        CatalogApp("com.chucklefish.stardewvalley", "Stardew Valley", "", "k", "sun.max.fill", .games),
        CatalogApp("com.playstack.balatro", "Balatro", "", "c", "suit.spade.fill", .games),
        CatalogApp("com.nytimes.crossword", "NYT Games", "", "m", "square.grid.3x3.fill", .games),
        CatalogApp("com.outfit7.mytalkingtom2", "My Talking Tom 2", "", "m", "cat.fill", .games),
    ]
}
