import Foundation
import CoreServices

final class ScreenshotWatcher {
    private var streamRef: FSEventStreamRef?
    private let watchedPath: String
    private let onNewScreenshot: (URL) -> Void
    private var pendingPaths: Set<String> = []

    init(directory: URL, onNewScreenshot: @escaping (URL) -> Void) {
        self.watchedPath = directory.path
        self.onNewScreenshot = onNewScreenshot
    }

    func start() {
        guard streamRef == nil else { return }
        print("[ScreenShelf] Watcher starting on: \(watchedPath)")

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        let callback: FSEventStreamCallback = { (_, contextInfo, numEvents, eventPaths, eventFlags, _) in
            guard let contextInfo else { return }
            let watcher = Unmanaged<ScreenshotWatcher>.fromOpaque(contextInfo).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
            let flags = UnsafeBufferPointer(start: eventFlags, count: numEvents)

            for (path, flag) in zip(paths, flags) {
                watcher.handleEvent(path: path, flags: flag)
            }
        }

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [watchedPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.0,
            flags
        )

        guard let stream = streamRef else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }

    private func handleEvent(path: String, flags: FSEventStreamEventFlags) {
        let renamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0
        let created = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
        let isFile  = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0
        let removed = flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0

        guard (renamed || created) && isFile && !removed else { return }

        let url = URL(fileURLWithPath: path)

        // FSEvents watches recursively — only process files directly in the watched directory
        guard url.deletingLastPathComponent().path == watchedPath else { return }
        guard FilenameParser.isScreenshot(url) else { return }
        guard FileManager.default.fileExists(atPath: path) else { return }

        print("[ScreenShelf] Detected: \(url.lastPathComponent)")
        debounce(url: url)
    }

    private func debounce(url: URL) {
        let path = url.path
        guard !pendingPaths.contains(path) else { return }
        pendingPaths.insert(path)

        Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
                pendingPaths.remove(path)
                onNewScreenshot(url)
            } catch {
                pendingPaths.remove(path)
            }
        }
    }

    deinit {
        stop()
    }
}
