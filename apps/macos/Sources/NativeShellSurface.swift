import AppKit
import SwiftUI

enum NativeShellRegion: UInt32 {
    case status, tabs, outline, folders, gitHeader, gitChanges, gitHistory
}

struct NativeShellAction: Decodable {
    let name: String
    let id: String?
    let alternate: Bool
    let point: [Double]?

    @MainActor func showMenu(_ items: [NSMenuItem], in view: NSView) {
        guard !items.isEmpty, let point, point.count == 2, view.window != nil else { return }
        let menu = NSMenu()
        items.forEach(menu.addItem)
        menu.popUp(positioning: nil,
                   at: NSPoint(x: point[0], y: view.isFlipped ? point[1] : view.bounds.height - point[1]), in: view)
    }
}

@MainActor
final class NativeShellMenuItem: NSMenuItem {
    private let performAction: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.performAction = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("Menu items are created by the workspace") }

    @objc private func invoke() { performAction() }
}

struct NativeShellSurface<State: Encodable & Equatable>: NSViewRepresentable {
    let region: NativeShellRegion
    let state: State
    let action: @MainActor (NativeShellAction, NSView) -> Void

    func makeCoordinator() -> NativeShellCoordinator { NativeShellCoordinator() }

    func makeNSView(context: Context) -> NSView {
        let owner = context.coordinator
        let handle = folio_ui_create(region.rawValue, Unmanaged.passUnretained(owner).toOpaque()) { context, bytes, count in
            MainActor.assumeIsolated {
                let owner = Unmanaged<NativeShellCoordinator>.fromOpaque(context).takeUnretainedValue()
                guard let view = owner.view,
                      let action = try? JSONDecoder().decode(NativeShellAction.self, from: Data(bytes: bytes, count: count))
                else { return }
                owner.action?(action, view)
            }
        }
        guard let handle else { return NSView() }
        owner.handle = handle
        let view = Unmanaged<NSView>.fromOpaque(folio_ui_view(handle)).takeUnretainedValue()
        owner.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        let owner = context.coordinator
        owner.action = action
        guard owner.state as? State != state, let handle = owner.handle,
              let data = try? JSONEncoder().encode(state) else { return }
        owner.state = state
        data.withUnsafeBytes { bytes in
            guard let start = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            folio_ui_update(handle, start, bytes.count)
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: NativeShellCoordinator) {
        coordinator.action = nil
        if let handle = coordinator.handle {
            folio_ui_destroy(handle)
            coordinator.handle = nil
        }
    }

}

@MainActor
final class NativeShellCoordinator {
    var handle: UnsafeMutableRawPointer?
    weak var view: NSView?
    var state: Any?
    var action: (@MainActor (NativeShellAction, NSView) -> Void)?
}
