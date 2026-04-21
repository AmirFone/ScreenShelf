import Foundation

enum FilenameParser {
    // U+202F NARROW NO-BREAK SPACE appears before AM/PM in macOS screenshot filenames
    private static let nnbsp = "\u{202F}"

    // 12-hour: "Screenshot 2026-04-20 at 3.45.12\u{202F}PM.png"
    private static let regex12h = try! Regex(
        #"^Screen(?:shot| Shot) (\d{4}-\d{2}-\d{2} at \d{1,2}\.\d{2}\.\d{2})"# + nnbsp + #"(AM|PM)\.(?:png|jpg|jpeg|tiff)$"#
    )

    // 24-hour: "Screenshot 2026-04-20 at 15.45.12.png"
    private static let regex24h = try! Regex(
        #"^Screen(?:shot| Shot) (\d{4}-\d{2}-\d{2} at \d{2}\.\d{2}\.\d{2})\.(?:png|jpg|jpeg|tiff)$"#
    )

    private static let formatter12h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' h.mm.ss\u{202F}a"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private static let formatter24h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' H.mm.ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    static func isScreenshot(_ url: URL) -> Bool {
        parse(url) != nil
    }

    static func parse(_ url: URL) -> Date? {
        let filename = url.lastPathComponent

        if let match = filename.wholeMatch(of: regex12h) {
            let dateStr = String(match[1].substring!) + nnbsp + String(match[2].substring!)
            return formatter12h.date(from: dateStr)
        }
        if let match = filename.wholeMatch(of: regex24h) {
            return formatter24h.date(from: String(match[1].substring!))
        }
        return nil
    }
}
