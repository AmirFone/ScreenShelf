import Foundation
import AppKit

@Observable
@MainActor
final class ScreenshotStore {
    enum CopyMode: String { case image, path }

    var screenshots: [Screenshot] = []
    var totalCount: Int = 0
    var selectedIDs: Set<Int64> = []
    var cursorIndex: Int = 0
    var copyMode: CopyMode = .image

    private let database: AppDatabase
    private let thumbnailDir: URL
    private var watcher: ScreenshotWatcher?
    private var currentPage = 0
    private let pageSize = 50

    init(database: AppDatabase) {
        self.database = database

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenShelf", isDirectory: true)
        self.thumbnailDir = appSupport.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: thumbnailDir, withIntermediateDirectories: true)
    }

    // MARK: - Selection

    func indexOf(_ screenshot: Screenshot) -> Int {
        screenshots.firstIndex(where: { $0.id == screenshot.id }) ?? 0
    }

    func onPanelOpen() {
        Task { @MainActor in
            await loadInitialPage()
            cursorIndex = 0
            selectedIDs.removeAll()
            if let id = screenshots.first?.id {
                selectedIDs = [id]
            }
        }
    }

    func moveCursor(down: Bool, extendSelection: Bool) {
        guard !screenshots.isEmpty else { return }

        let newIndex = down
            ? min(cursorIndex + 1, screenshots.count - 1)
            : max(cursorIndex - 1, 0)

        guard newIndex != cursorIndex else { return }

        if extendSelection {
            let oldID = screenshots[cursorIndex].id
            let newID = screenshots[newIndex].id

            if let newID, selectedIDs.contains(newID) {
                // Moving back into already-selected territory — deselect the item we're leaving
                if let oldID { selectedIDs.remove(oldID) }
            } else if let newID {
                // Extending into unselected territory — add the new item
                selectedIDs.insert(newID)
            }
        }

        cursorIndex = newIndex
    }

    func toggleSelection(at index: Int) {
        guard index >= 0, index < screenshots.count,
              let id = screenshots[index].id else { return }
        cursorIndex = index
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectSingle(at index: Int) {
        guard index >= 0, index < screenshots.count,
              let id = screenshots[index].id else { return }
        cursorIndex = index
        selectedIDs = [id]
    }

    func rangeSelect(to index: Int) {
        guard index >= 0, index < screenshots.count else { return }
        let range = min(cursorIndex, index)...max(cursorIndex, index)
        for i in range {
            if let id = screenshots[i].id {
                selectedIDs.insert(id)
            }
        }
        cursorIndex = index
    }

    func copySelected() -> Bool {
        let selected = screenshots.filter { $0.id.map { selectedIDs.contains($0) } ?? false }
        guard !selected.isEmpty else { return false }
        let urls = selected.map { URL(fileURLWithPath: $0.filePath) }
        switch copyMode {
        case .image: ClipboardManager.copyAsImages(urls: urls)
        case .path:  ClipboardManager.copyAsPaths(urls: urls)
        }
        return true
    }

    // MARK: - Data

    func startWatching() {
        let dir = Self.screenshotDirectory()
        watcher = ScreenshotWatcher(directory: dir) { [weak self] url in
            Task { @MainActor [weak self] in
                await self?.processNewScreenshot(url)
            }
        }
        watcher?.start()
    }

    func loadInitialPage() async {
        do {
            screenshots = try database.fetchPage(limit: pageSize, offset: 0)
            totalCount = try database.count()
            currentPage = 1
        } catch {
            print("Failed to load screenshots: \(error)")
        }
    }

    func loadNextPage() async {
        do {
            let next = try database.fetchPage(limit: pageSize, offset: currentPage * pageSize)
            guard !next.isEmpty else { return }
            screenshots.append(contentsOf: next)
            currentPage += 1
        } catch {
            print("Failed to load next page: \(error)")
        }
    }

    func indexExisting() async {
        let dir = Self.screenshotDirectory()

        let hasNew: Bool = await Task.detached(priority: .utility) { [weak self] () -> Bool in
            guard let self else { return false }

            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { return false }

            let files = enumerator.allObjects.compactMap { $0 as? URL }
            var found = false

            for fileURL in files {
                guard FilenameParser.isScreenshot(fileURL) else { continue }
                let alreadyExists = (try? self.database.exists(filePath: fileURL.path)) ?? false
                if alreadyExists { continue }
                if self.processFile(fileURL) != nil { found = true }
            }
            return found
        }.value

        if hasNew { await loadInitialPage() }
    }

    private func processNewScreenshot(_ url: URL) async {
        let _ = await Task.detached(priority: .utility, operation: { [weak self] in
            self?.processFile(url)
        }).value

        // Reload from DB instead of inserting into array directly.
        // LazyVStack has a bug where items inserted at index 0 while visible
        // render but have broken hit-testing. Full reload avoids this.
        await loadInitialPage()
    }

    private static func screenshotDirectory() -> URL {
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !location.isEmpty {
            return URL(fileURLWithPath: NSString(string: location).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    private nonisolated func processFile(_ url: URL) -> Screenshot? {
        let path = url.path
        let alreadyExists = (try? database.exists(filePath: path)) ?? false
        if alreadyExists { return nil }
        guard let capturedAt = FilenameParser.parse(url) else { return nil }

        let thumbName = url.deletingPathExtension().lastPathComponent + ".jpg"
        let thumbURL = thumbnailDir.appendingPathComponent(thumbName)
        let thumbGenerated = ThumbnailGenerator.generate(from: url, to: thumbURL)
        let size = ThumbnailGenerator.imageSize(at: url)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0

        var entry = Screenshot(
            filePath: path,
            fileName: url.lastPathComponent,
            thumbPath: thumbGenerated ? thumbURL.path : nil,
            fileSize: fileSize,
            width: size?.width ?? 0,
            height: size?.height ?? 0,
            capturedAt: capturedAt,
            createdAt: Date()
        )

        do {
            try database.insert(&entry)
            return entry
        } catch {
            print("Failed to insert screenshot: \(error)")
            return nil
        }
    }
}
