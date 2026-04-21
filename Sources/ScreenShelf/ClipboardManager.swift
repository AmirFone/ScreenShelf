import AppKit

@MainActor
enum ClipboardManager {
    static func copyAsImages(urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if urls.count == 1, let url = urls.first {
            let item = NSPasteboardItem()
            item.setData(url.dataRepresentation, forType: .fileURL)
            if let data = try? Data(contentsOf: url) {
                item.setData(data, forType: url.pathExtension.lowercased() == "png" ? .png : .tiff)
            }
            pasteboard.writeObjects([item])
        } else {
            pasteboard.writeObjects(urls.map { $0 as NSURL })
        }
    }

    static func copyAsPaths(urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let paths = urls.map(\.path).joined(separator: "\n")
        pasteboard.setString(paths, forType: .string)
    }
}
