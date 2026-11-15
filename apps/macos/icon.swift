import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func drawIcon(size: Int) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 78, y: 78, width: 868, height: 868), xRadius: 193, yRadius: 193)
    NSColor(srgbRed: 0.266, green: 0.184, blue: 0.157, alpha: 1).setFill()
    tile.fill()
    let page = NSBezierPath(roundedRect: NSRect(x: 271, y: 222, width: 482, height: 590), xRadius: 45, yRadius: 45)
    NSColor(srgbRed: 0.964, green: 0.925, blue: 0.865, alpha: 1).setFill()
    page.fill()
    NSColor(srgbRed: 0.551, green: 0.289, blue: 0.204, alpha: 1).setFill()
    let bookmark = NSBezierPath()
    bookmark.move(to: NSPoint(x: 624, y: 812))
    bookmark.line(to: NSPoint(x: 690, y: 812))
    bookmark.line(to: NSPoint(x: 690, y: 621))
    bookmark.line(to: NSPoint(x: 657, y: 648))
    bookmark.line(to: NSPoint(x: 624, y: 621))
    bookmark.close()
    bookmark.fill()
    for (index, width) in [280.0, 338.0, 227.0].enumerated() {
        NSBezierPath(roundedRect: NSRect(x: 343, y: 540 - index * 67, width: Int(width), height: 21),
                     xRadius: 10, yRadius: 10).fill()
    }
    image.unlockFocus()
    return NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(size: size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
