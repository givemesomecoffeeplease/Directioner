//
//  LogicProController.swift
//  ClickTrackInserter
//

import Cocoa
import ApplicationServices

class LogicProController {

    static let bundleID = "com.apple.logic10"
    private let dragWindow = DragSourceWindow()

    // MARK: - Public

    /// 사용자가 클릭한 CG 좌표에 파일 드롭
    func insertAudio(url: URL, at clickCG: CGPoint, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let logicApp = runningLogicPro() else {
            completion(.failure(LPError.notRunning))
            return
        }
        print("[LogicPro] 드롭 좌표 (클릭): CG\(clickCG)")
        logicApp.activate(options: .activateIgnoringOtherApps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.dragWindow.startDrag(url: url, to: clickCG)
            completion(.success(()))
        }
    }

    /// Logic Pro 창 위의 좌표인지 확인 (CG 좌표계)
    func isOverLogicPro(point: CGPoint) -> Bool {
        guard let logicApp = runningLogicPro() else { return false }
        let pid = logicApp.processIdentifier
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let bounds = CGRect(x: boundsDict["X"] ?? 0, y: boundsDict["Y"] ?? 0,
                                width: boundsDict["Width"] ?? 0, height: boundsDict["Height"] ?? 0)
            if bounds.contains(point) { return true }
        }
        return false
    }

    // MARK: - AX 탐색

    private func runningLogicPro() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first
    }

    /// selected=true인 헤더 아이템의 midY(NSScreen 좌표)와 콘텐츠 AXLayoutArea를 반환
    private func findSelectedTrackInfo(in axApp: AXUIElement) -> (trackMidY: CGFloat, contentArea: AXUIElement)? {
        guard let trackHeader = findElement(in: axApp, matchingDesc: "트랙 헤더"),
              let headerItems = axChildren(of: trackHeader) else { return nil }

        var selectedItem: AXUIElement? = nil
        var selectedDesc: String? = nil
        for item in headerItems {
            var selRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXSelectedAttribute as CFString, &selRef)
            if let sel = selRef as? Bool, sel {
                selectedItem = item
                selectedDesc = axString(of: item, key: kAXDescriptionAttribute)
                break
            }
        }
        guard let item = selectedItem, let desc = selectedDesc else {
            print("[LogicPro] 선택된 트랙 헤더 항목 없음")
            return nil
        }
        print("[LogicPro] 선택된 트랙: \(desc)")

        // 헤더 아이템의 top Y + 15 = 해당 행 중앙 (그룹이 펼쳐져 있어도 첫 행만 타겟)
        guard let pos = axPosition(of: item), let size = axSize(of: item) else { return nil }
        let midY = pos.y + 15
        print("[LogicPro] 헤더 아이템 위치: \(pos), 크기: \(size), midY: \(midY)")

        // 콘텐츠 영역 (드롭 대상 확인용)
        guard let trackContent = findElement(in: axApp, matchingDesc: "트랙 콘텐츠"),
              let contentArea = findElement(in: trackContent, matchingDesc: desc) else {
            print("[LogicPro] 트랙 콘텐츠 영역 없음")
            return nil
        }
        return (midY, contentArea)
    }

    /// 재생헤드 썸네일의 X 좌표 반환 (NSScreen 좌표계)
    private func findPlayheadX(in axApp: AXUIElement) -> CGFloat? {
        guard let ruler = findElement(in: axApp, matchingDesc: "트랙 시간 눈금자") else {
            print("[LogicPro] 시간 눈금자 없음")
            return nil
        }
        guard let children = axChildren(of: ruler) else { return nil }
        for child in children {
            let desc = axString(of: child, key: kAXDescriptionAttribute) ?? ""
            if desc == "재생헤드 썸네일" {
                if let pos = axPosition(of: child), let size = axSize(of: child) {
                    print("[LogicPro] 재생헤드 위치: \(pos), 크기: \(size)")
                    return pos.x + size.width / 2
                }
            }
        }
        print("[LogicPro] 재생헤드 썸네일 없음")
        return nil
    }

    // MARK: - 드래그 시뮬레이션

    private func simulateDrop(url: URL, at nsPoint: CGPoint) {
        // NSPasteboard drag 타입에 파일 URL 등록
        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        pb.writeObjects([url as NSURL])

        // NSScreen좌표(좌상단) → CGEvent좌표(좌하단) 변환
        let cgPoint = flippedPoint(nsPoint)
        let src = CGEventSource(stateID: .combinedSessionState)
        let startPt = CGPoint(x: cgPoint.x, y: cgPoint.y - 10)

        func post(_ type: CGEventType, _ pt: CGPoint) {
            CGEvent(mouseEventSource: src, mouseType: type,
                    mouseCursorPosition: pt, mouseButton: .left)?.post(tap: .cgSessionEventTap)
            Thread.sleep(forTimeInterval: 0.04)
        }

        post(.leftMouseDown, startPt)
        for i in 1...6 {
            let t = CGFloat(i) / 6
            let mid = CGPoint(x: startPt.x + (cgPoint.x - startPt.x) * t,
                              y: startPt.y + (cgPoint.y - startPt.y) * t)
            post(.leftMouseDragged, mid)
        }
        post(.leftMouseUp, cgPoint)
        print("[LogicPro] 드래그 시뮬레이션 완료 → CG\(cgPoint)")
    }

    private func flippedPoint(_ pt: CGPoint) -> CGPoint {
        let h = NSScreen.screens.map { $0.frame.maxY }.max() ?? NSScreen.main!.frame.height
        return CGPoint(x: pt.x, y: h - pt.y)
    }

    // MARK: - AX 유틸

    private func findElement(in root: AXUIElement, matchingDesc target: String) -> AXUIElement? {
        let desc = axString(of: root, key: kAXDescriptionAttribute) ?? ""
        if desc == target { return root }
        guard let children = axChildren(of: root) else { return nil }
        for child in children {
            if let found = findElement(in: child, matchingDesc: target) { return found }
        }
        return nil
    }

    private func axChildren(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let arr = value as? [AXUIElement] else { return nil }
        return arr
    }

    private func axString(of element: AXUIElement, key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func axPosition(of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let axVal = value else { return nil }
        var pt = CGPoint.zero
        AXValueGetValue(axVal as! AXValue, .cgPoint, &pt)
        return pt
    }

    private func axSize(of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let axVal = value else { return nil }
        var sz = CGSize.zero
        AXValueGetValue(axVal as! AXValue, .cgSize, &sz)
        return sz
    }
}

// MARK: - Errors

enum LPError: LocalizedError {
    case notRunning
    case noSelectedTrack
    case cannotResolvePlayhead

    var errorDescription: String? {
        switch self {
        case .notRunning: return "Logic Pro가 실행 중이지 않습니다."
        case .noSelectedTrack: return "Logic Pro에서 선택된 트랙이 없습니다."
        case .cannotResolvePlayhead: return "재생헤드 위치를 찾을 수 없습니다."
        }
    }
}
