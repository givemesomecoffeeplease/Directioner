#!/usr/bin/env swift
import Cocoa

func drawIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(size)

    // 배경: 연한 파란색 둥근 사각형
    let bgColor = NSColor(red: 0.82, green: 0.93, blue: 0.95, alpha: 1.0)
    bgColor.setFill()
    let radius = s * 0.22
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: radius, yRadius: radius)
    bgPath.fill()

    let vbW: CGFloat = 200
    let vbH: CGFloat = 200
    let margin = s * 0.10
    let drawW = s - margin * 2
    let drawH = s - margin * 2

    func tx(_ x: CGFloat) -> CGFloat {
        return margin + (x - 240) / vbW * drawW
    }
    func ty(_ y: CGFloat) -> CGFloat {
        let relY = (y - 40) / vbH
        return s - margin - relY * drawH
    }

    // 파일 아이콘 (반투명)
    let fileColor = NSColor(red: 0.68, green: 0.84, blue: 0.95, alpha: 0.8)
    fileColor.setFill()
    let fileRect = NSRect(x: tx(318), y: ty(186), width: (75/vbW)*drawW, height: (95/vbH)*drawH)
    let filePath = NSBezierPath(roundedRect: fileRect, xRadius: s*0.03, yRadius: s*0.03)
    filePath.fill()

    // 접힌 모서리 삼각형
    let foldColor = NSColor(red: 0.53, green: 0.76, blue: 0.90, alpha: 0.9)
    foldColor.setFill()
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: tx(355), y: ty(91)))
    fold.line(to: NSPoint(x: tx(393), y: ty(117)))
    fold.line(to: NSPoint(x: tx(355), y: ty(117)))
    fold.close()
    fold.fill()

    // 커서
    let cursorColor = NSColor(red: 0.10, green: 0.32, blue: 0.47, alpha: 1.0)
    cursorColor.setFill()
    let cursor = NSBezierPath()
    cursor.move(to:    NSPoint(x: tx(288), y: ty(85)))
    cursor.line(to:    NSPoint(x: tx(288), y: ty(178)))
    cursor.line(to:    NSPoint(x: tx(313), y: ty(153)))
    cursor.line(to:    NSPoint(x: tx(330), y: ty(195)))
    cursor.line(to:    NSPoint(x: tx(344), y: ty(189)))
    cursor.line(to:    NSPoint(x: tx(327), y: ty(147)))
    cursor.line(to:    NSPoint(x: tx(355), y: ty(147)))
    cursor.close()
    cursor.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG 변환 실패: \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("✅ \(path)")
    } catch {
        print("❌ \(path): \(error)")
    }
}

let base = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/ClickTrackInserter/Assets.xcassets/AppIcon.appiconset"

let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let rep = drawIcon(size: size)
    savePNG(rep, to: base + "/" + name)
}

print("완료! \(base)")
