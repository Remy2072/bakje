import AppKit
import Quartz
import QuickLookThumbnailing
import ServiceManagement

enum Brand {
    static func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }
    static let vlak = hex(0xF5F5F5)
    static let knopZacht = hex(0xDFDFDF)
    static let knopHover = hex(0xCCCCCC)
    static let knopPressed = hex(0xB8B8B8)
    static let lime = hex(0xF1F170)
    static let ok = hex(0x646729)
    static let darkGrey = hex(0x737373)
    static let tekstZacht = NSColor.black.withAlphaComponent(0.65)

    static func font(_ file: String, _ size: CGFloat) -> NSFont {
        guard let url = Bundle.main.url(forResource: file, withExtension: "woff2"),
              let desc = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
        else { return .systemFont(ofSize: size) }
        return CTFontCreateWithFontDescriptor(desc, size, nil) as NSFont
    }

    static let body = font("SuisseIntl-Regular", 14)
    static let label = font("SuisseIntl-Regular", 13)
    static let small = font("SuisseIntl-Regular", 12)
    static let mini = font("SuisseIntl-Regular", 11)

    static func label(_ text: String, _ font: NSFont, _ color: NSColor = .black) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font
        l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    static func box(_ color: NSColor, radius: CGFloat) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        v.layer?.cornerRadius = radius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    static func roundButton(_ symbol: String, _ label: String, _ target: AnyObject, _ action: Selector) -> RoundButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold)) ?? NSImage()
        let b = RoundButton(image: image, target: target, action: action)
        b.isBordered = false
        b.bezelStyle = .shadowlessSquare
        b.imagePosition = .imageOnly
        b.imageScaling = .scaleNone
        b.contentTintColor = .black
        b.toolTip = label
        b.wantsLayer = true
        b.base = knopZacht
        b.layer?.cornerRadius = RoundButton.size / 2
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentHuggingPriority(.required, for: .horizontal)
        b.setContentHuggingPriority(.required, for: .vertical)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: RoundButton.size),
            b.heightAnchor.constraint(equalToConstant: RoundButton.size),
        ])
        return b
    }

    static func roundedBottom(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: radius)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    static func menuBarIcon(active: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current else { return false }
            NSColor.black.set()
            let frame = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 1.75, width: 14.5, height: 14.5), xRadius: 4.6, yRadius: 4.6)
            frame.lineWidth = 1.5
            frame.stroke()
            if active { frame.fill() }
            let card: (CGFloat, CGFloat, CGFloat) -> NSBezierPath = { x, y, angle in
                let p = NSBezierPath(roundedRect: NSRect(x: -2.5, y: -3.2, width: 5, height: 6.4), xRadius: 1.1, yRadius: 1.1)
                var t = AffineTransform(translationByX: x, byY: y)
                t.rotate(byDegrees: angle)
                p.transform(using: t)
                return p
            }
            let back = card(7.7, 9.3, 12)
            let front = card(9.9, 8.7, -7)
            if active {
                ctx.compositingOperation = .clear
                back.fill()
                ctx.compositingOperation = .sourceOver
                front.lineWidth = 2.2
                front.stroke()
                ctx.compositingOperation = .clear
                front.fill()
                ctx.compositingOperation = .sourceOver
                return true
            }
            back.lineWidth = 1.25
            back.stroke()
            ctx.compositingOperation = .clear
            front.lineWidth = 2.2
            front.stroke()
            front.fill()
            ctx.compositingOperation = .sourceOver
            front.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Bakje"
        return image
    }

    static func bytes(_ n: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: n)
    }
    static func count(_ n: Int) -> String { n == 1 ? "1 bestand" : "\(n) bestanden" }
}

@MainActor
enum Thumbs {
    static var cache: [URL: NSImage] = [:]

    static func image(for url: URL, update: @escaping @MainActor (NSImage) -> Void) -> NSImage {
        if let cached = cache[url] { return cached }
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 128, height: 128),
                                                   scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            guard let image = rep?.nsImage else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    cache[url] = image
                    update(image)
                }
            }
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func fitted(_ size: NSSize, in box: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return box }
        let k = min(box.width / size.width, box.height / size.height)
        let w = size.width * k, h = size.height * k
        return NSRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h)
    }
}

func popUp(_ menu: NSMenu, under button: NSView) {
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
}

final class RoundButton: NSButton {
    static let size: CGFloat = 30
    var base: NSColor? = Brand.knopZacht { didSet { paint(hovering ? Brand.knopHover : base) } }
    private var hovering = false

    override var intrinsicContentSize: NSSize { NSSize(width: Self.size, height: Self.size) }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    private func paint(_ color: NSColor?) { layer?.backgroundColor = color?.cgColor }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        paint(Brand.knopHover)
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        paint(base)
    }

    override func mouseDown(with event: NSEvent) {
        paint(Brand.knopPressed)
        super.mouseDown(with: event)
        paint(hovering ? Brand.knopHover : base)
    }
}

final class KeyPanel: NSPanel {
    var onSpace: () -> Bool = { false }
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49, !(firstResponder is NSTextView), onSpace() { return }
        super.keyDown(with: event)
    }
}

class Pill: NSView {
    private let text = Brand.label("", Brand.label)
    private let dot = Brand.box(.clear, radius: 3.5)
    private var dotWidth: NSLayoutConstraint!
    private var textGap: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)
        addSubview(text)
        dotWidth = dot.widthAnchor.constraint(equalToConstant: 7)
        textGap = text.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6)
        NSLayoutConstraint.activate([
            dotWidth,
            textGap,
            dot.heightAnchor.constraint(equalToConstant: 7),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    func set(_ title: String, fill: NSColor, dot dotColor: NSColor?) {
        text.stringValue = title
        layer?.backgroundColor = fill.cgColor
        dot.layer?.backgroundColor = dotColor?.cgColor
        dot.isHidden = dotColor == nil
        dotWidth.constant = dotColor == nil ? 0 : 7
        textGap.constant = dotColor == nil ? 2 : 6
    }
}

final class ClickPill: Pill {
    var onClick: () -> Void = {}
    var clickable = false { didSet { window?.invalidateCursorRects(for: self) } }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() { if clickable { addCursorRect(bounds, cursor: .pointingHand) } }
    override func mouseDown(with event: NSEvent) { if clickable { onClick() } }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { if clickable { animator().alphaValue = 0.75 } }
    override func mouseExited(with event: NSEvent) { animator().alphaValue = 1 }
}

final class PileView: NSView, NSDraggingSource {
    static let iconSide: CGFloat = 84
    var urls: () -> [URL] = { [] }
    var onDropped: () -> Void = {}
    var onClick: () -> Void = {}
    private var icons: [CALayer] = []
    private var didDrag = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Bestanden in Bakje, sleep om alles te verplaatsen")
    }

    required init?(coder: NSCoder) { nil }

    func show(_ urls: [URL]) {
        icons.forEach { $0.removeFromSuperlayer() }
        let angles: [CGFloat] = [0, -8, 7]
        let scale = window?.backingScaleFactor ?? NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        icons = urls.prefix(3).enumerated().reversed().map { i, url in
            let l = CALayer()
            let render: (NSImage) -> CGImage? = { image in
                var rect = NSRect(x: 0, y: 0, width: Self.iconSide * scale, height: Self.iconSide * scale)
                return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            }
            l.contents = render(Thumbs.image(for: url) { [weak l] image in l?.contents = render(image) })
            l.contentsScale = scale
            l.contentsGravity = .resizeAspect
            l.setAffineTransform(CGAffineTransform(rotationAngle: angles[i] * .pi / 180))
            l.shadowOpacity = 0.18
            l.shadowRadius = 4
            l.shadowOffset = CGSize(width: 0, height: -1)
            layer?.addSublayer(l)
            return l
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let side = max(0, min(PileView.iconSide, bounds.height - 8))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in icons {
            l.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            l.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        CATransaction.commit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func mouseDown(with event: NSEvent) { didDrag = false }
    override func mouseUp(with event: NSEvent) { if !didDrag { onClick() } }

    override func mouseDragged(with event: NSEvent) {
        guard !didDrag else { return }
        didDrag = true
        let at = convert(event.locationInWindow, from: nil)
        let items = urls().enumerated().map { i, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let o = CGFloat(min(i, 4)) * 4
            item.setDraggingFrame(NSRect(x: at.x - 24 + o, y: at.y - 24 - o, width: 48, height: 48),
                                  contents: NSWorkspace.shared.icon(forFile: url.path))
            return item
        }
        guard !items.isEmpty else { return }
        beginDraggingSession(with: items, event: event, source: self).draggingFormation = .pile
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.move, .copy] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if !operation.isEmpty { onDropped() }
    }
}

class GridCell: NSView {
    static let tileSize = NSSize(width: 92, height: 104)
    static let rowHeight: CGFloat = 42
    let icon = NSImageView()
    let name: NSTextField
    let detail: NSTextField
    var gridConstraints: [NSLayoutConstraint] = []
    var listConstraints: [NSLayoutConstraint] = []

    init(title: String, subtitle: String, image: NSImage) {
        name = Brand.label(title, Brand.small)
        detail = Brand.label(subtitle, Brand.mini, Brand.tekstZacht)
        super.init(frame: NSRect(origin: .zero, size: Self.tileSize))
        wantsLayer = true
        layer?.cornerRadius = 10
        icon.image = image
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        name.lineBreakMode = .byTruncatingMiddle
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [icon, name, detail].forEach(addSubview)
        gridConstraints = [
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 56),
            icon.heightAnchor.constraint(equalToConstant: 56),
            name.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 4),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            detail.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 1),
            detail.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            detail.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ]
        listConstraints = [
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            name.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            detail.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: name.trailingAnchor),
            detail.topAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ]
        setListStyle(false)
    }

    required init?(coder: NSCoder) { nil }

    func setListStyle(_ list: Bool) {
        NSLayoutConstraint.deactivate(list ? gridConstraints : listConstraints)
        NSLayoutConstraint.activate(list ? listConstraints : gridConstraints)
        name.alignment = list ? .left : .center
        detail.alignment = list ? .left : .center
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { hover(true) }
    override func mouseExited(with event: NSEvent) { hover(false) }

    private var hovering = false
    var selected = false { didSet { paint() } }

    func hover(_ on: Bool) {
        hovering = on
        paint()
    }

    private func paint() {
        layer?.backgroundColor = selected ? Brand.lime.blended(withFraction: 0.35, of: .white)!.cgColor
            : hovering ? Brand.vlak.cgColor : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit is NSButton || hit is NSTextView || (hit as? NSTextField)?.isEditable == true { return hit }
        return frame.contains(point) ? self : nil
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}

final class RevealCell: GridCell {
    var onClick: () -> Void = {}

    init() {
        let image = NSImage(systemSymbolName: "arrowshape.turn.up.right.circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 40, weight: .light)) ?? NSImage()
        super.init(title: "Toon in Finder", subtitle: "Alle bestanden", image: image)
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = Brand.darkGrey
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Toon alles in Finder")
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) { onClick() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

final class TileView: GridCell, NSDraggingSource, NSTextFieldDelegate {
    private(set) var url: URL
    let added = Date()
    let bytes: Int64
    var onDropped: (TileView) -> Void = { _ in }
    var onRemove: (TileView) -> Void = { _ in }
    var onRenamed: () -> Void = {}
    private var more: NSButton?
    private var moreGrid: [NSLayoutConstraint] = []
    private var moreList: [NSLayoutConstraint] = []

    init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isFolder = values?.isDirectory == true
        bytes = isFolder ? 0 : Int64(values?.fileSize ?? 0)
        super.init(title: url.lastPathComponent, subtitle: isFolder ? "Map" : Brand.bytes(bytes),
                   image: NSWorkspace.shared.icon(forFile: url.path))
        name.delegate = self
        icon.image = Thumbs.image(for: url) { [weak self] image in self?.icon.image = image }
        let more = Brand.roundButton("ellipsis", "Meer acties", self, #selector(showActions(_:)))
        more.isHidden = true
        addSubview(more)
        self.more = more
        moreGrid = [more.topAnchor.constraint(equalTo: topAnchor, constant: 2),
                    more.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)]
        moreList = [more.centerYAnchor.constraint(equalTo: centerYAnchor),
                    more.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)]
        setListStyle(false)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(url.lastPathComponent)
        toolTip = url.path
    }

    required init?(coder: NSCoder) { nil }

    override func setListStyle(_ list: Bool) {
        super.setListStyle(list)
        NSLayoutConstraint.deactivate(list ? moreGrid : moreList)
        NSLayoutConstraint.activate(list ? moreList : moreGrid)
    }

    override func hover(_ on: Bool) {
        super.hover(on)
        more?.isHidden = !on
    }

    var onSelect: (TileView) -> Void = { _ in }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        if event.clickCount == 2 { open() } else { onSelect(self) }
    }

    var iconFrameOnScreen: NSRect? {
        guard let window else { return nil }
        let frame = Thumbs.fitted(icon.image?.size ?? icon.frame.size, in: icon.frame)
        return window.convertToScreen(convert(frame, to: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(Thumbs.fitted(icon.image?.size ?? icon.frame.size, in: icon.frame), contents: icon.image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.move, .copy] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if !operation.isEmpty { onDropped(self) }
    }

    @objc func open() { NSWorkspace.shared.open(url) }
    @objc func revealInFinder() { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    @objc func removeFromShelf() { onRemove(self) }

    @objc func openWithApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc func rename() {
        name.isEditable = true
        name.isSelectable = true
        name.drawsBackground = true
        name.backgroundColor = .white
        window?.makeKey()
        window?.makeFirstResponder(name)
        let base = (url.lastPathComponent as NSString).deletingPathExtension as NSString
        name.currentEditor()?.selectedRange = NSRange(location: 0, length: base.length)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        name.stringValue = url.lastPathComponent
        window?.makeFirstResponder(nil)
        return true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        name.isEditable = false
        name.isSelectable = false
        name.drawsBackground = false
        let newName = name.stringValue.trimmingCharacters(in: .whitespaces)
        guard newName != url.lastPathComponent else { return }
        do {
            guard !newName.isEmpty, !newName.contains("/"), !newName.hasPrefix(".") else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            let target = url.deletingLastPathComponent().appendingPathComponent(newName)
            try FileManager.default.moveItem(at: url, to: target)
            url = target
            name.stringValue = newName
            toolTip = url.path
            setAccessibilityLabel(newName)
            onRenamed()
        } catch {
            name.stringValue = url.lastPathComponent
            NSSound.beep()
        }
    }

    private func actionsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(open), keyEquivalent: "").target = self
        let openWith = NSMenuItem(title: "Open met", action: nil, keyEquivalent: "")
        openWith.submenu = NSMenu()
        for app in NSWorkspace.shared.urlsForApplications(toOpen: url) {
            let item = NSMenuItem(title: FileManager.default.displayName(atPath: app.path), action: #selector(openWithApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app
            let appIcon = NSWorkspace.shared.icon(forFile: app.path)
            appIcon.size = NSSize(width: 16, height: 16)
            item.image = appIcon
            openWith.submenu?.addItem(item)
        }
        menu.addItem(openWith)
        menu.addItem(withTitle: "Toon in Finder", action: #selector(revealInFinder), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Hernoem…", action: #selector(rename), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Verwijder uit Bakje", action: #selector(removeFromShelf), keyEquivalent: "").target = self
        return menu
    }

    @objc func showActions(_ sender: NSButton) { popUp(actionsMenu(), under: sender) }
    override func menu(for event: NSEvent) -> NSMenu? { actionsMenu() }
}

final class GridView: NSView {
    override var isFlipped: Bool { true }
    var cells: [GridCell] = [] { didSet { needsLayout = true } }
    var list = false {
        didSet {
            cells.forEach { $0.setListStyle(list) }
            needsLayout = true
        }
    }
    var height: NSLayoutConstraint!

    override func layout() {
        super.layout()
        let gap: CGFloat = list ? 2 : 6
        if list {
            for (i, cell) in cells.enumerated() {
                cell.frame = NSRect(x: 0, y: CGFloat(i) * (GridCell.rowHeight + gap), width: bounds.width, height: GridCell.rowHeight)
            }
            height.constant = CGFloat(cells.count) * (GridCell.rowHeight + gap)
            return
        }
        let s = GridCell.tileSize
        let cols = max(1, Int((bounds.width + gap) / (s.width + gap)))
        let used = CGFloat(cols) * s.width + CGFloat(cols - 1) * gap
        let inset = max(0, (bounds.width - used) / 2)
        for (i, cell) in cells.enumerated() {
            cell.frame = NSRect(x: inset + CGFloat(i % cols) * (s.width + gap),
                                y: CGFloat(i / cols) * (s.height + gap), width: s.width, height: s.height)
        }
        height.constant = CGFloat((cells.count + cols - 1) / cols) * (s.height + gap)
    }
}

final class ViewToggle: NSView {
    var onChange: (Bool) -> Void = { _ in }
    private var gridButton: RoundButton!
    private var listButton: RoundButton!

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Brand.knopZacht.cgColor
        layer?.cornerRadius = RoundButton.size / 2
        translatesAutoresizingMaskIntoConstraints = false
        gridButton = Brand.roundButton("square.grid.2x2", "Rasterweergave", self, #selector(pickGrid))
        listButton = Brand.roundButton("list.bullet", "Lijstweergave", self, #selector(pickList))
        [gridButton, listButton].forEach(addSubview)
        NSLayoutConstraint.activate([
            gridButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            gridButton.topAnchor.constraint(equalTo: topAnchor),
            gridButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            listButton.leadingAnchor.constraint(equalTo: gridButton.trailingAnchor),
            listButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            listButton.topAnchor.constraint(equalTo: topAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func select(list: Bool) {
        gridButton.base = list ? nil : .white
        listButton.base = list ? .white : nil
    }

    @objc func pickGrid() { select(list: false); onChange(false) }
    @objc func pickList() { select(list: true); onChange(true) }
}

enum SortMode: String, CaseIterable {
    case added = "Toegevoegd op"
    case nameAsc = "Naam (A-Z)"
    case nameDesc = "Naam (Z-A)"
    case kind = "Soort"
    case size = "Grootte (grootste eerst)"
}

final class ShelfView: NSView {
    static let compactSize = NSSize(width: 198, height: 207)
    static let expandedSize = NSSize(width: 328, height: 300)
    static let headerHeight: CGFloat = 46
    var onClose: () -> Void = {}
    var onWillClose: ([URL]) -> Void = { _ in }
    var onChange: () -> Void = {}
    var onResize: (NSSize, Bool) -> Void = { _, _ in }
    private(set) var expanded = false
    private var tiles: [TileView] = []
    private var selected: TileView? {
        didSet {
            oldValue?.selected = false
            selected?.selected = true
        }
    }

    var previewURLs: [URL] { tiles.map(\.url) }
    var previewStartIndex: Int { selected.flatMap { s in tiles.firstIndex { $0 === s } } ?? 0 }

    func previewFrame(for url: URL) -> NSRect {
        if expanded, let tile = tiles.first(where: { $0.url == url }), let frame = tile.iconFrameOnScreen { return frame }
        guard let window = pile.window else { return .zero }
        return window.convertToScreen(pile.convert(pile.bounds, to: nil))
    }
    private let reveal = RevealCell()
    private var sort = SortMode(rawValue: UserDefaults.standard.string(forKey: "sort") ?? "") ?? .added {
        didSet { UserDefaults.standard.set(sort.rawValue, forKey: "sort") }
    }
    private var listView = UserDefaults.standard.bool(forKey: "listView") {
        didSet { UserDefaults.standard.set(listView, forKey: "listView") }
    }
    private let compact = NSView()
    private let full = NSView()
    private let pile = PileView()
    private let hint = Brand.label("Leg in Bakje", Brand.font("SuisseIntl-Regular", 16), Brand.tekstZacht)
    private let count = ClickPill()
    private let titleCount = Brand.label("", Brand.label)
    private let titleSize = Brand.label("", Brand.mini, Brand.tekstZacht)
    private let titleStack = NSStackView()
    private let grid = GridView()
    private let toggle = ViewToggle()
    private let grabber = Brand.box(NSColor.black.withAlphaComponent(0.18), radius: 2.5)
    private var closeButton: NSButton!
    private var backButton: NSButton!
    private var sortButton: NSButton!
    private var menuButton: NSButton!

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Brand.vlak.cgColor
        layer?.cornerRadius = 28
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        registerForDraggedTypes([.fileURL])

        closeButton = Brand.roundButton("xmark", "Sluit Bakje", self, #selector(closeShelf))
        backButton = Brand.roundButton("chevron.left", "Terug", self, #selector(collapse))
        sortButton = Brand.roundButton("arrow.up.arrow.down", "Sorteer", self, #selector(showSort(_:)))
        menuButton = Brand.roundButton("ellipsis", "Meer", self, #selector(showMenu(_:)))
        toggle.select(list: listView)
        toggle.onChange = { [weak self] list in
            self?.listView = list
            self?.grid.list = list
        }
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = -2
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [titleCount, titleSize].forEach {
            $0.lineBreakMode = .byTruncatingTail
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            titleStack.addArrangedSubview($0)
        }
        grabber.alphaValue = 0

        [compact, full].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        let tools = NSStackView(views: [toggle, sortButton, menuButton])
        tools.spacing = 6
        tools.translatesAutoresizingMaskIntoConstraints = false
        [closeButton, backButton, tools, titleStack, grabber].forEach(addSubview)

        pile.translatesAutoresizingMaskIntoConstraints = false
        pile.urls = { [weak self] in self?.tiles.map(\.url) ?? [] }
        pile.onDropped = { [weak self] in self?.clear() }
        pile.onClick = { [weak self] in self?.expand() }
        count.onClick = { [weak self] in self?.expand() }
        [pile, hint, count].forEach(compact.addSubview)

        reveal.onClick = { [weak self] in self?.revealAll() }
        let surface = Brand.box(.white, radius: 10)
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.height = grid.heightAnchor.constraint(equalToConstant: 0)
        grid.list = listView
        scroll.documentView = grid
        full.addSubview(surface)
        surface.addSubview(scroll)

        let h = Self.headerHeight
        NSLayoutConstraint.activate([
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: closeButton.leadingAnchor),
            backButton.topAnchor.constraint(equalTo: closeButton.topAnchor),
            tools.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            tools.topAnchor.constraint(equalTo: closeButton.topAnchor),
            titleStack.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 10),
            titleStack.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: tools.leadingAnchor, constant: -6),

            compact.topAnchor.constraint(equalTo: topAnchor, constant: h),
            compact.centerXAnchor.constraint(equalTo: centerXAnchor),
            compact.widthAnchor.constraint(equalToConstant: Self.compactSize.width),
            compact.heightAnchor.constraint(equalToConstant: Self.compactSize.height - h),
            full.topAnchor.constraint(equalTo: topAnchor, constant: h),
            full.centerXAnchor.constraint(equalTo: centerXAnchor),
            full.widthAnchor.constraint(equalToConstant: Self.expandedSize.width),
            full.heightAnchor.constraint(equalToConstant: Self.expandedSize.height - h),

            pile.leadingAnchor.constraint(equalTo: compact.leadingAnchor, constant: 12),
            pile.trailingAnchor.constraint(equalTo: compact.trailingAnchor, constant: -12),
            pile.topAnchor.constraint(equalTo: compact.topAnchor),
            pile.bottomAnchor.constraint(equalTo: count.topAnchor, constant: -10),
            hint.centerXAnchor.constraint(equalTo: pile.centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: pile.centerYAnchor),
            count.centerXAnchor.constraint(equalTo: compact.centerXAnchor),
            count.bottomAnchor.constraint(equalTo: compact.bottomAnchor, constant: -14),

            surface.leadingAnchor.constraint(equalTo: full.leadingAnchor, constant: 12),
            surface.trailingAnchor.constraint(equalTo: full.trailingAnchor, constant: -12),
            surface.topAnchor.constraint(equalTo: full.topAnchor, constant: 8),
            surface.bottomAnchor.constraint(equalTo: full.bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: surface.topAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -6),
            grid.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            grid.height,
        ])
        full.isHidden = true
        applyChrome()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { grabber.animator().alphaValue = 1 }
    override func mouseExited(with event: NSEvent) { grabber.animator().alphaValue = 0 }

    private func applyChrome() {
        closeButton.isHidden = expanded
        backButton.isHidden = !expanded
        titleStack.isHidden = !expanded
        toggle.isHidden = !expanded
        sortButton.isHidden = !expanded || tiles.count < 2
    }

    func setExpanded(_ on: Bool, animated: Bool = true) {
        guard on != expanded else { return }
        expanded = on
        applyChrome()
        let (show, hide) = on ? (full, compact) : (compact, full)
        show.isHidden = false
        onResize(on ? Self.expandedSize : Self.compactSize, animated)
        guard animated else {
            show.alphaValue = 1
            hide.isHidden = true
            return
        }
        show.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            show.animator().alphaValue = 1
            hide.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard self?.expanded == on else { return }
                hide.isHidden = true
                hide.alphaValue = 1
            }
        })
    }

    @objc func expand() { if !tiles.isEmpty { setExpanded(true) } }
    @objc func collapse() { setExpanded(false) }

    private func refresh() {
        let n = tiles.count
        hint.isHidden = n > 0
        pile.isHidden = n == 0
        pile.show(tiles.sorted { $0.added > $1.added }.map(\.url))
        if n == 0 {
            count.set("Leeg", fill: .clear, dot: Brand.darkGrey)
        } else {
            count.set("\(Brand.count(n))  ›", fill: Brand.lime, dot: Brand.ok)
        }
        count.clickable = n > 0
        titleCount.stringValue = Brand.count(n)
        titleSize.stringValue = Brand.bytes(tiles.reduce(0) { $0 + $1.bytes })
        if expanded && n == 0 { setExpanded(false) }
        applyChrome()
        onChange()
    }

    private func layoutCells() {
        grid.cells = tiles.isEmpty ? [] : tiles + [reveal]
        grid.list = listView
    }

    func add(_ url: URL) {
        guard !tiles.contains(where: { $0.url == url }) else { return }
        let tile = TileView(url: url)
        tile.onDropped = { [weak self] in self?.remove($0) }
        tile.onRemove = { [weak self] in self?.remove($0) }
        tile.onRenamed = { [weak self] in
            self?.sortItems()
            self?.onChange()
        }
        tile.onSelect = { [weak self] in self?.selected = $0 }
        tiles.append(tile)
        grid.addSubview(tile)
        if reveal.superview == nil { grid.addSubview(reveal) }
        sortItems()
        refresh()
    }

    private func remove(_ tile: TileView) {
        if selected === tile { selected = nil }
        tile.removeFromSuperview()
        tiles.removeAll { $0 === tile }
        layoutCells()
        refresh()
    }

    private func clear() {
        selected = nil
        tiles.forEach { $0.removeFromSuperview() }
        tiles = []
        layoutCells()
        refresh()
    }

    @objc func closeShelf() {
        onWillClose(previewURLs)
        clear()
        setExpanded(false, animated: false)
        onClose()
    }

    private func sortItems() {
        let key: (TileView) -> String = { $0.url.lastPathComponent }
        let byName: (TileView, TileView) -> Bool = { key($0).localizedStandardCompare(key($1)) == .orderedAscending }
        switch sort {
        case .added:
            tiles.sort { $0.added > $1.added }
        case .nameAsc:
            tiles.sort(by: byName)
        case .nameDesc:
            tiles.sort { byName($1, $0) }
        case .kind:
            tiles.sort {
                let (a, b) = ($0.url.pathExtension.lowercased(), $1.url.pathExtension.lowercased())
                return a == b ? byName($0, $1) : a < b
            }
        case .size:
            tiles.sort { $0.bytes == $1.bytes ? byName($0, $1) : $0.bytes > $1.bytes }
        }
        layoutCells()
    }

    @objc func pickSort(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String, let picked = SortMode(rawValue: mode) else { return }
        sort = picked
        sortItems()
    }

    @objc func showSort(_ sender: NSButton) {
        let menu = NSMenu()
        if #available(macOS 14, *) {
            menu.addItem(.sectionHeader(title: "Sorteer op"))
        } else {
            menu.addItem(withTitle: "Sorteer op", action: nil, keyEquivalent: "")
        }
        for mode in SortMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(pickSort(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == sort ? .on : .off
            menu.addItem(item)
        }
        popUp(menu, under: sender)
    }

    @objc func revealAll() { NSWorkspace.shared.activateFileViewerSelecting(tiles.map(\.url)) }
    @objc func emptyShelf() { clear() }

    @objc func showMenu(_ sender: NSButton) {
        let menu = NSMenu()
        if !tiles.isEmpty {
            menu.addItem(withTitle: "Toon alles in Finder", action: #selector(revealAll), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Maak Bakje leeg", action: #selector(emptyShelf), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Stop Bakje", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApplication.shared
        popUp(menu, under: sender)
    }

    private func highlight(_ on: Bool) {
        layer?.backgroundColor = (on ? Brand.lime.blended(withFraction: 0.45, of: .white)! : Brand.vlak).cgColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource == nil else { return [] }
        highlight(true)
        return .generic
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { highlight(false) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlight(false)
        let dropped = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        dropped.forEach(add)
        return !dropped.isEmpty
    }
}

final class NotchView: NSView {
    static let pad: CGFloat = 28
    var onDrop: ([URL]) -> Void = { _ in }
    var notchFill: NSColor = .black { didSet { base.fillColor = notchFill.cgColor } }
    private let base = CAShapeLayer()
    private let lit = CALayer()
    private let glow = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private let gradientMask = CAShapeLayer()
    private let border = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        base.fillColor = notchFill.cgColor
        glow.fillColor = Brand.lime.cgColor
        glow.shadowColor = Brand.lime.cgColor
        glow.shadowOffset = .zero
        glow.shadowRadius = 14
        glow.shadowOpacity = 1
        gradient.type = .radial
        gradient.colors = [Brand.lime.blended(withFraction: 0.4, of: .black)!.cgColor,
                           Brand.lime.blended(withFraction: 0.15, of: .black)!.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.05, y: 1.3)
        gradient.mask = gradientMask
        border.fillColor = nil
        border.strokeColor = Brand.lime.cgColor
        border.lineWidth = 2.5
        lit.opacity = 0
        [glow, gradient, border].forEach(lit.addSublayer)
        layer?.addSublayer(base)
        layer?.addSublayer(lit)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let p = Self.pad
        let notch = CGRect(x: p, y: p, width: bounds.width - 2 * p, height: bounds.height - p)
        let big = CGRect(x: notch.minX - 3, y: notch.minY - 3, width: notch.width + 6, height: notch.height + 3)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.path = Brand.roundedBottom(notch, 12)
        lit.frame = bounds
        glow.path = Brand.roundedBottom(big, 16)
        glow.shadowPath = glow.path
        gradient.frame = big
        gradientMask.path = Brand.roundedBottom(CGRect(origin: .zero, size: big.size), 16)
        border.path = Brand.roundedBottom(big.insetBy(dx: 1.25, dy: 0).offsetBy(dx: 0, dy: 1.25), 15)
        CATransaction.commit()
    }

    private func light(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(on ? 0.15 : 0.25)
        lit.opacity = on ? 1 : 0
        CATransaction.commit()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource == nil else { return [] }
        light(true)
        return .generic
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { light(false) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        light(false)
        let dropped = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        onDrop(dropped)
        return !dropped.isEmpty
    }
}

struct ShakeDetector {
    var minSwing: CGFloat = 40
    var window: TimeInterval = 0.8
    var reversalsNeeded = 3
    private var lastX: CGFloat = 0
    private var swingStart: CGFloat = 0
    private var direction: CGFloat = 0
    private var reversals: [TimeInterval] = []

    mutating func reset(at x: CGFloat) {
        lastX = x
        swingStart = x
        direction = 0
        reversals = []
    }

    mutating func feed(x: CGFloat, time: TimeInterval) -> Bool {
        let d: CGFloat = x > lastX ? 1 : (x < lastX ? -1 : direction)
        if d != direction {
            if direction != 0, abs(lastX - swingStart) >= minSwing { reversals.append(time) }
            swingStart = lastX
            direction = d
        }
        lastX = x
        reversals.removeAll { time - $0 > window }
        guard reversals.count >= reversalsNeeded else { return false }
        reversals = []
        return true
    }
}

@MainActor
final class ShelfController: NSObject, NSWindowDelegate {
    static let margin: CGFloat = 18
    let panel = KeyPanel(
        contentRect: NSRect(x: 0, y: 0, width: ShelfView.compactSize.width + 2 * ShelfController.margin,
                            height: ShelfView.compactSize.height + 2 * ShelfController.margin),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered, defer: false)
    let shelf = ShelfView()
    var onClosed: (ShelfController) -> Void = { _ in }
    var onWillClose: ([URL]) -> Void = { _ in }
    var onChange: () -> Void = {}
    var onSpace: (ShelfController) -> Bool = { _ in false }

    override init() {
        super.init()
        panel.isMovableByWindowBackground = true
        panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        let container = NSView()
        panel.contentView = container
        panel.onSpace = { [weak self] in
            guard let self else { return false }
            return self.onSpace(self)
        }
        container.addSubview(shelf)
        shelf.frame = container.bounds.insetBy(dx: Self.margin, dy: Self.margin)
        shelf.autoresizingMask = [.width, .height]
        shelf.onClose = { [weak self] in self?.dismiss() }
        shelf.onResize = { [weak self] size, animated in self?.resize(to: size, animated: animated) }
        shelf.onChange = { [weak self] in self?.onChange() }
        shelf.onWillClose = { [weak self] urls in self?.onWillClose(urls) }
    }

    func windowDidMove(_ notification: Notification) { onChange() }

    var isEmpty: Bool { shelf.previewURLs.isEmpty }
    var cardFrame: NSRect { panel.frame.insetBy(dx: Self.margin, dy: Self.margin) }

    func resize(to size: NSSize, animated: Bool) {
        let f = panel.frame
        let target = NSRect(x: f.midX - size.width / 2, y: f.maxY - Self.margin - size.height,
                            width: size.width, height: size.height).insetBy(dx: -Self.margin, dy: -Self.margin)
        guard animated else {
            panel.setFrame(target, display: true)
            return restoreShadow()
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.restoreShadow() }
        })
    }

    func restoreShadow() {
        panel.hasShadow = true
        panel.invalidateShadow()
    }

    func show(at card: NSRect) {
        panel.setFrame(card.insetBy(dx: -Self.margin, dy: -Self.margin), display: true)
        panel.orderFrontRegardless()
    }

    func present(_ card: NSRect, from pivot: CGPoint) {
        panel.setFrame(card.insetBy(dx: -Self.margin, dy: -Self.margin), display: true)
        panel.alphaValue = 0
        panel.hasShadow = false
        panel.orderFrontRegardless()
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated { self?.restoreShadow() }
        }
        defer { CATransaction.commit() }
        if let layer = shelf.layer {
            var start = CATransform3DMakeTranslation(pivot.x, pivot.y, 0)
            start = CATransform3DScale(start, 0.6, 0.6, 1)
            start = CATransform3DTranslate(start, -pivot.x, -pivot.y, 0)
            let pop = CASpringAnimation(keyPath: "transform")
            pop.fromValue = start
            pop.toValue = CATransform3DIdentity
            pop.mass = 1
            pop.stiffness = 320
            pop.damping = 20
            pop.duration = pop.settlingDuration
            layer.add(pop, forKey: "pop")
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.onClosed(self)
            }
        })
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSDraggingDestination,
    @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    let notch = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let notchView = NotchView()
    var notchRect = NSRect.zero
    var shelves: [ShelfController] = []
    var previewShelf: ShelfController?
    var shake = ShakeDetector()
    var shakeY = ShakeDetector()
    var dragChangeCount = 0
    var shookThisDrag = false
    var launchedAtLogin = false
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let statusMenu = NSMenu()

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        notch.backgroundColor = .clear
        notch.isOpaque = false
        notch.hasShadow = false
        notch.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        notch.contentView = notchView
        notchView.onDrop = { [weak self] urls in self?.newShelfUnderNotch(urls) }
        placeNotch()
        notch.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            self, selector: #selector(placeNotch), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.trackShake(event) }
        }

        statusItem.button?.image = Brand.menuBarIcon()
        statusItem.button?.window?.registerForDraggedTypes([.fileURL])
        statusItem.button?.window?.delegate = self
        statusItem.menu = statusMenu
        statusMenu.delegate = self

        restore()
        if shelves.isEmpty && !launchedAtLogin { newShelfCentered([]) }
    }

    func makeShelf() -> ShelfController {
        let c = ShelfController()
        c.onClosed = { [weak self] closed in
            self?.shelves.removeAll { $0 === closed }
            if self?.previewShelf === closed { self?.previewShelf = nil }
            self?.save()
        }
        c.onChange = { [weak self] in self?.save() }
        c.onWillClose = { [weak self] urls in self?.remember(urls) }
        c.onSpace = { [weak self] c in self?.togglePreview(for: c) ?? false }
        shelves.append(c)
        return c
    }

    func compactCard(topCenter: NSPoint) -> NSRect {
        let s = ShelfView.compactSize
        return NSRect(x: topCenter.x - s.width / 2, y: topCenter.y - s.height, width: s.width, height: s.height)
    }

    func cascade(_ card: NSRect) -> NSRect {
        let others = shelves.filter(\.panel.isVisible).map(\.cardFrame)
        let screen = NSScreen.screens.first { $0.frame.intersects(card) }?.visibleFrame ?? card
        var r = card
        while let hit = others.first(where: { $0.intersects(r) }) {
            r.origin.x = hit.maxX + 12
            if r.maxX > screen.maxX { break }
        }
        guard r.maxX > screen.maxX else { return r }
        r = card
        while others.contains(where: { abs($0.minX - r.minX) < 4 && abs($0.maxY - r.maxY) < 4 }), r.minY - 24 > screen.minY {
            r = r.offsetBy(dx: 24, dy: -24)
        }
        return r
    }

    func newShelf(_ urls: [URL], card: NSRect, pivot: CGPoint) {
        let c = makeShelf()
        c.present(cascade(card), from: pivot)
        urls.forEach(c.shelf.add)
    }

    func newShelfCentered(_ urls: [URL]) {
        let m = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(m) }) ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let s = ShelfView.compactSize
        newShelf(urls, card: NSRect(x: v.midX - s.width / 2, y: v.midY - s.height / 2, width: s.width, height: s.height),
                 pivot: CGPoint(x: s.width / 2, y: s.height / 2))
    }

    func newShelfUnderIcon(_ urls: [URL]) {
        guard let icon = statusItem.button?.window, let screen = icon.screen else { return newShelfCentered(urls) }
        let v = screen.visibleFrame
        let s = ShelfView.compactSize
        let x = min(max(icon.frame.midX, v.minX + 8 + s.width / 2), v.maxX - 8 - s.width / 2)
        newShelf(urls, card: compactCard(topCenter: NSPoint(x: x, y: v.maxY - 8)),
                 pivot: CGPoint(x: icon.frame.midX - (x - s.width / 2), y: s.height))
    }

    func newShelfUnderNotch(_ urls: [URL]) {
        guard let screen = notch.screen ?? NSScreen.main else { return }
        let s = ShelfView.compactSize
        newShelf(urls, card: compactCard(topCenter: NSPoint(x: notchRect.midX, y: screen.visibleFrame.maxY - 8)),
                 pivot: CGPoint(x: s.width / 2, y: s.height))
    }

    func save() {
        let data: [[String: Any]] = shelves.filter { !$0.isEmpty }.map { c in
            ["frame": NSStringFromRect(c.cardFrame),
             "items": c.shelf.previewURLs.compactMap { try? $0.bookmarkData() }]
        }
        UserDefaults.standard.set(data, forKey: "shelves")
    }

    func resolve(_ bookmarks: [Data]) -> [URL] {
        bookmarks.compactMap { data -> URL? in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
    }

    var recent: [[String: Any]] {
        get { UserDefaults.standard.array(forKey: "recent") as? [[String: Any]] ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(5)), forKey: "recent") }
    }

    func remember(_ urls: [URL]) {
        let items = urls.compactMap { try? $0.bookmarkData() }
        guard !items.isEmpty else { return }
        recent = [["items": items, "names": urls.map(\.lastPathComponent), "date": Date()]] + recent
    }

    @objc func reopenRecent(_ sender: NSMenuItem) {
        guard let i = sender.representedObject as? Int, recent.indices.contains(i) else { return }
        var list = recent
        let entry = list.remove(at: i)
        recent = list
        let urls = resolve(entry["items"] as? [Data] ?? [])
        guard !urls.isEmpty else { return NSSound.beep() }
        newShelfUnderIcon(urls)
    }

    func restore() {
        let saved = UserDefaults.standard.array(forKey: "shelves") as? [[String: Any]] ?? []
        for entry in saved {
            let urls = resolve(entry["items"] as? [Data] ?? [])
            guard !urls.isEmpty, let frame = (entry["frame"] as? String).map(NSRectFromString) else { continue }
            var card = compactCard(topCenter: NSPoint(x: frame.midX, y: frame.maxY))
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(card) }), let screen = notch.screen ?? NSScreen.main {
                card = compactCard(topCenter: NSPoint(x: notchRect.midX, y: screen.visibleFrame.maxY - 8))
            }
            let c = makeShelf()
            urls.forEach(c.shelf.add)
            c.show(at: cascade(card))
        }
        save()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "Nieuw bakje", action: #selector(openShelf), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Nieuw bakje uit klembord", action: #selector(shelfFromClipboard), keyEquivalent: "").target = self
        if !shelves.isEmpty {
            menu.addItem(withTitle: shelves.count == 1 ? "Sluit bakje" : "Sluit alle \(shelves.count) bakjes",
                         action: #selector(closeAll), keyEquivalent: "").target = self
        }
        let recents = recent
        if !recents.isEmpty {
            menu.addItem(.separator())
            if #available(macOS 14, *) {
                menu.addItem(.sectionHeader(title: "Recente bakjes"))
            } else {
                menu.addItem(withTitle: "Recente bakjes", action: nil, keyEquivalent: "")
            }
            let when = RelativeDateTimeFormatter()
            when.locale = Locale(identifier: "nl_NL")
            when.dateTimeStyle = .named
            for (i, entry) in recents.enumerated() {
                let names = entry["names"] as? [String] ?? []
                let title = names.first.map { names.count > 1 ? "\($0) + \(names.count - 1)" : $0 } ?? "Bakje"
                let item = NSMenuItem(title: title, action: #selector(reopenRecent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = i
                if let date = entry["date"] as? Date {
                    let detail = "\(Brand.count(names.count)) · \(when.localizedString(for: date, relativeTo: Date()))"
                    if #available(macOS 14.4, *) { item.subtitle = detail } else { item.toolTip = detail }
                }
                if let url = resolve(Array((entry["items"] as? [Data] ?? []).prefix(1))).first {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    icon.size = NSSize(width: 32, height: 32)
                    item.image = icon
                }
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Open bij inloggen", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Stop Bakje", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApplication.shared
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource == nil else { return [] }
        statusItem.button?.image = Brand.menuBarIcon(active: true)
        return .generic
    }

    func draggingExited(_ sender: NSDraggingInfo?) { statusItem.button?.image = Brand.menuBarIcon() }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        statusItem.button?.image = Brand.menuBarIcon()
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        newShelfUnderIcon(urls)
        return true
    }

    func togglePreview(for c: ShelfController) -> Bool {
        guard !c.shelf.previewURLs.isEmpty, let ql = QLPreviewPanel.shared() else { return false }
        if QLPreviewPanel.sharedPreviewPanelExists(), ql.isVisible, previewShelf === c {
            ql.orderOut(nil)
            return true
        }
        previewShelf = c
        NSApp.activate()
        ql.level = NSWindow.Level(rawValue: c.panel.level.rawValue + 1)
        if ql.isVisible {
            ql.reloadData()
            ql.currentPreviewItemIndex = c.shelf.previewStartIndex
        }
        ql.makeKeyAndOrderFront(nil)
        if let screen = c.panel.screen, ql.screen != screen {
            let v = screen.visibleFrame
            ql.setFrameOrigin(NSPoint(x: v.midX - ql.frame.width / 2, y: v.midY - ql.frame.height / 2))
        }
        return true
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = previewShelf?.shelf.previewStartIndex ?? 0
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewShelf?.shelf.previewURLs.count ?? 0 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let urls = previewShelf?.shelf.previewURLs, urls.indices.contains(index) else { return nil }
        return urls[index] as NSURL
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        guard let url = item.previewItemURL, let shelf = previewShelf?.shelf else { return .zero }
        return shelf.previewFrame(for: url)
    }

    @objc func openShelf() { newShelfUnderIcon([]) }
    @objc func closeAll() { shelves.forEach { $0.shelf.closeShelf() } }

    @objc func shelfFromClipboard() {
        let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return NSSound.beep() }
        newShelfUnderIcon(urls)
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        newShelfCentered(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if shelves.isEmpty { newShelfCentered([]) } else { shelves.forEach { $0.panel.orderFrontRegardless() } }
        return false
    }

    @objc func placeNotch() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let f = screen.frame
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let h = screen.safeAreaInsets.top
            notchRect = NSRect(x: left.maxX, y: f.maxY - h, width: right.minX - left.maxX, height: h)
            notchView.notchFill = .black
        } else {
            let h = max(f.maxY - screen.visibleFrame.maxY, 24)
            notchRect = NSRect(x: f.midX - 100, y: f.maxY - h, width: 200, height: h)
            notchView.notchFill = NSColor.black.withAlphaComponent(0.01)
        }
        let p = NotchView.pad
        notch.setFrame(NSRect(x: notchRect.minX - p, y: notchRect.minY - p,
                              width: notchRect.width + 2 * p, height: notchRect.height + p), display: true)
    }

    func trackShake(_ event: NSEvent) {
        let drag = NSPasteboard(name: .drag)
        let m = NSEvent.mouseLocation
        if event.type == .leftMouseDown {
            dragChangeCount = drag.changeCount
            shookThisDrag = false
            shake.reset(at: m.x)
            shakeY.reset(at: m.y)
            return
        }
        guard !shookThisDrag, drag.changeCount != dragChangeCount, drag.types?.contains(.fileURL) == true else { return }
        let horizontal = shake.feed(x: m.x, time: event.timestamp)
        let vertical = shakeY.feed(x: m.y, time: event.timestamp)
        guard horizontal || vertical, let screen = NSScreen.screens.first(where: { $0.frame.contains(m) }) else { return }
        shookThisDrag = true
        let v = screen.visibleFrame
        let size = ShelfView.compactSize
        let gap: CGFloat = 28
        let onRight = m.x + gap + size.width <= v.maxX
        let x = onRight ? m.x + gap : m.x - gap - size.width
        let y = min(max(m.y - size.height / 2, v.minY), v.maxY - size.height)
        newShelf([], card: NSRect(x: x, y: y, width: size.width, height: size.height),
                 pivot: CGPoint(x: onRight ? 0 : size.width, y: m.y - y))
    }
}

if CommandLine.arguments.contains("--login-item") {
    do {
        try SMAppService.mainApp.register()
        print("login item: \(SMAppService.mainApp.status == .enabled ? "enabled" : "status \(SMAppService.mainApp.status.rawValue)")")
        exit(0)
    } catch {
        print("login item failed: \(error.localizedDescription)")
        exit(1)
    }
}

if CommandLine.arguments.contains("--selftest") {
    var s = ShakeDetector()
    s.reset(at: 0)
    let wiggle: [CGFloat] = [0, 50, 100, 50, 0, 50, 100, 50, 0]
    assert(wiggle.enumerated().map { s.feed(x: $1, time: Double($0) * 0.05) }.contains(true),
           "shake should trigger after three reversals")
    var slow = ShakeDetector()
    slow.reset(at: 0)
    assert(![0, 10, 20, 10, 0, 10, 20].enumerated().map { slow.feed(x: CGFloat($1), time: Double($0) * 0.05) }.contains(true),
           "small wiggles must not trigger")
    print("selftest ok")
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
