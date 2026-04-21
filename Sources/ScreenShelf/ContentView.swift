import SwiftUI

struct ContentView: View {
    var store: ScreenshotStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            screenshotList
            Divider()
            footer
        }
        .frame(width: 360, height: 440)
        .background(VibrancyView())
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("ScreenShelf")
                .font(.system(size: 13, weight: .semibold))
            Text("\(store.totalCount)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(.quaternary))
            Spacer()
            copyModePicker
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var copyModePicker: some View {
        HStack(spacing: 0) {
            modeButton("Image", icon: "photo", mode: .image)
            modeButton("Path", icon: "text.cursor", mode: .path)
        }
        .background(Capsule().fill(.quaternary.opacity(0.6)))
    }

    private func modeButton(_ label: String, icon: String, mode: ScreenshotStore.CopyMode) -> some View {
        Button {
            store.copyMode = mode
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                store.copyMode == mode
                    ? Capsule().fill(Color.accentColor.opacity(0.2))
                    : Capsule().fill(.clear)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.copyMode == mode ? .primary : .secondary)
    }

    private var screenshotList: some View {
        Group {
            if store.screenshots.isEmpty {
                ContentUnavailableView(
                    "No Screenshots",
                    systemImage: "photo.on.rectangle",
                    description: Text("Take a screenshot and it will appear here.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(store.screenshots) { screenshot in
                                let index = store.indexOf(screenshot)
                                ScreenshotCell(
                                    screenshot: screenshot,
                                    isSelected: screenshot.id.map { store.selectedIDs.contains($0) } ?? false,
                                    isCursor: index == store.cursorIndex,
                                    onSelect: { handleClick(screenshot) }
                                )
                                .id(screenshot.id)
                                .onAppear {
                                    if screenshot.id == store.screenshots.last?.id {
                                        Task { await store.loadNextPage() }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: store.cursorIndex) { _, newIndex in
                        if newIndex >= 0, newIndex < store.screenshots.count {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(store.screenshots[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if store.selectedIDs.isEmpty {
                Text("\u{2191}\u{2193} nav \u{2022} \u{21E7}\u{2193} extend \u{2022} \u{23CE} copy")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(store.selectedIDs.count) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func handleClick(_ screenshot: Screenshot) {
        guard let index = store.screenshots.firstIndex(where: { $0.id == screenshot.id }) else { return }
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift) {
            store.rangeSelect(to: index)
        } else if modifiers.contains(.command) {
            store.toggleSelection(at: index)
        } else {
            store.selectSingle(at: index)
        }
    }
}

private struct VibrancyView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
