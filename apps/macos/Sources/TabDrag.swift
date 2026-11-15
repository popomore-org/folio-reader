import SwiftUI
import UniformTypeIdentifiers

enum TabDrag {
    static let type = UTType(exportedAs: "org.popomore.folio.reader-tab", conformingTo: .data)

    static func itemProvider(for id: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess) { completion in
            completion(Data(id.uuidString.utf8), nil)
            return nil
        }
        return provider
    }

    static func receive(_ providers: [NSItemProvider], in pane: Pane, before anchor: UUID?, model: ReaderModel,
                        createRightPane: Bool = false) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
            guard let data, let id = UUID(uuidString: String(decoding: data, as: UTF8.self)) else { return }
            Task { @MainActor in model.dropTab(id, in: pane, before: anchor, createRightPane: createRightPane) }
        }
        return true
    }
}

struct SplitOnTabDrop: DropDelegate {
    let model: ReaderModel
    @Binding var targetingSplit: Bool

    func validateDrop(info: DropInfo) -> Bool { !model.split }

    func dropEntered(info: DropInfo) { targetingSplit = true }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func dropExited(info: DropInfo) { targetingSplit = false }

    func performDrop(info: DropInfo) -> Bool {
        targetingSplit = false
        guard !model.split else { return false }
        return TabDrag.receive(info.itemProviders(for: [TabDrag.type]), in: .right, before: nil, model: model,
                               createRightPane: true)
    }
}

struct TabStripDrop: DropDelegate {
    let model: ReaderModel
    let pane: Pane
    let tabs: [UUID]
    let frames: [UUID: CGRect]
    @Binding var insertionX: CGFloat?

    func dropEntered(info: DropInfo) {
        insertionX = placement(at: info.location.x).x
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        insertionX = placement(at: info.location.x).x
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { insertionX = nil }

    func performDrop(info: DropInfo) -> Bool {
        insertionX = nil
        return TabDrag.receive(info.itemProviders(for: [TabDrag.type]), in: pane,
                               before: placement(at: info.location.x).anchor, model: model)
    }

    private func placement(at x: CGFloat) -> (anchor: UUID?, x: CGFloat) {
        let bounds = tabs.compactMap { id in frames[id].map { (id: id, rect: $0) } }
        if let next = bounds.first(where: { x < $0.rect.midX }) { return (next.id, next.rect.minX) }
        return (nil, bounds.last?.rect.maxX ?? 0)
    }
}
