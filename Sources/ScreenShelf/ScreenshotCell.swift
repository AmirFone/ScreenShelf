import SwiftUI

struct ScreenshotCell: View {
    let screenshot: Screenshot
    let isSelected: Bool
    let isCursor: Bool
    let showPath: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                thumbnail
                    .frame(width: 110, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeTime(screenshot.capturedAt))
                        .font(.system(size: 12, weight: .medium))

                    Text("\(screenshot.width)\u{00D7}\(screenshot.height) \u{00B7} \(Self.sizeFormatter.string(fromByteCount: screenshot.fileSize))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if showPath {
                        Text(screenshot.filePath)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Color.accentColor)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCursor ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Image") {
                ClipboardManager.copyAsImages(urls: [URL(fileURLWithPath: screenshot.filePath)])
            }
            Button("Copy Path") {
                ClipboardManager.copyAsPaths(urls: [URL(fileURLWithPath: screenshot.filePath)])
            }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: screenshot.filePath)])
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbPath = screenshot.thumbPath,
           let nsImage = NSImage(contentsOfFile: thumbPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private func relativeTime(_ date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        if seconds < 86400 {
            let h = Int(seconds / 3600)
            return h == 1 ? "1 hour ago" : "\(h) hours ago"
        }
        if seconds < 172800 { return "Yesterday" }
        if seconds < 604800 { return "\(Int(seconds / 86400)) days ago" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
