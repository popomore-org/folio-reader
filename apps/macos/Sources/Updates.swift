import AppKit
import CryptoKit
import Sparkle
import SwiftUI

@MainActor
final class FolioUpdates: NSObject, ObservableObject, SPUUpdaterDelegate, SPUUserDriver {
    enum SettingsPage: Hashable { case appearance, updates }

    private enum Phase {
        case idle, checking, offered, downloading, downloaded, waiting, installing, failed
    }

    private struct Offer: Equatable {
        let version: String
        let build: String
        let notes: String
        let url: URL
        let length: Int
        let signature: Data
    }

    @Published var settingsPage: SettingsPage = .appearance
    @Published private var phase: Phase = .idle
    @Published private var offer: Offer?
    @Published private(set) var status = "Check for a new version of Folio."
    @Published private(set) var automaticChecks = false
    @Published private(set) var hasPrivateCredential = false
    @AppStorage("folioAutomaticallyDownload") var automaticDownloads = false
    @AppStorage("folioAutomaticallyInstall") var automaticInstalls = false {
        didSet { restartAfter = nil }
    }

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "FolioPreviewVersion") as? String ??
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    private let feed = (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String).flatMap { URL(string: $0) }
    private let privateChannel: PrivateUpdateChannel? = {
        guard Bundle.main.object(forInfoDictionaryKey: "FolioPrivateUpdates") as? Bool == true,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), let id = Bundle.main.bundleIdentifier else { return nil }
        return PrivateUpdateChannel(feed: url, bundleID: id)
    }()
    private let key = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
        .flatMap { Data(base64Encoded: $0) }
        .flatMap { try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }
    private let defaults = UserDefaults.standard
    private let transferSession = URLSession(configuration: .ephemeral, delegate: UpdateTransport(), delegateQueue: nil)
    private weak var model: ReaderModel?
    private var updater: SPUUpdater?
    private var privateSnapshot: PrivateUpdateChannel.Snapshot?
    private var privateCheck: Task<Void, Never>?
    private var privateToken: String? {
        didSet { hasPrivateCredential = privateToken != nil }
    }
    private var checkCancellation: (() -> Void)?
    private var transfer: URLSessionDownloadTask?
    private var archive: Data?
    private var authorized: Offer?
    private var cachedRequest: URLRequest?
    private var previousCacheCapacity: Int?
    var showSettings: OpenSettingsAction?
    private var retryTermination: (() -> Void)?
    private var postponeRelaunch: (() -> Void)?
    private var manualCheck = false
    @Published private var installationProgress: Double?
    private var presentingConsent = false
    private var deferredOffer: Offer?
    private var restartAfter: ContinuousClock.Instant?
    private static let consentKey = "folioUpdateConsentRecorded"
    private static let privateAutomaticKey = "folioPrivateAutomaticChecks"
    private static let privateLastCheckKey = "folioPrivateLastUpdateCheck"
    private static let maximumArchiveSize = 64 * 1024 * 1024

    var isConfigured: Bool { feed != nil && !InstanceMode.isSeparate }
    var privateRepository: String? { privateChannel?.repository }
    var releasesURL: URL? { privateChannel?.releasesURL }
    var canEditPrivateCredential: Bool { !isWorking && updater?.sessionInProgress != true }
    var version: String? { offer?.version }
    var notes: String { offer?.notes ?? "" }
    var canCheck: Bool {
        updater != nil && authorized == nil && (privateChannel == nil || hasPrivateCredential) &&
            [.idle, .offered, .downloaded, .waiting, .failed].contains(phase)
    }
    var canDownload: Bool { phase == .offered || (phase == .failed && offer != nil && archive == nil) }
    var canInstall: Bool { archive != nil && [.downloaded, .waiting, .failed].contains(phase) }
    var canCancel: Bool { privateCheck != nil || (phase == .checking && checkCancellation != nil) || transfer != nil }
    var canDefer: Bool { canInstall && automaticInstalls && deferredOffer != offer }
    private var isInstalling: Bool { authorized != nil && (phase == .installing || retryTermination != nil || postponeRelaunch != nil) }
    var isWorking: Bool { [.checking, .downloading, .installing].contains(phase) }
    var lastCheckFailed: Bool { phase == .failed }
    var downloadProgress: Double? {
        guard let transfer, let offer else { return installationProgress }
        return min(1, Double(transfer.countOfBytesReceived) / Double(offer.length))
    }

    func start(model: ReaderModel) {
        self.model = model
        guard isConfigured, updater == nil else { return }
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
        if let privateChannel {
            privateToken = privateChannel.token()
            updater.automaticallyChecksForUpdates = false
            if !hasPrivateCredential {
                set(.idle, "Add GitHub access to check for updates.")
            }
        }
        do {
            try updater.start()
            self.updater = updater
            automaticChecks = privateChannel == nil ? updater.automaticallyChecksForUpdates : defaults.bool(forKey: Self.privateAutomaticKey)
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                MainActor.assumeIsolated {
                    self.installWhenIdle()
                    self.checkPrivateUpdatesIfDue()
                }
            }
        } catch {
            set(.failed, "Couldn’t start the updater. \(error.localizedDescription)")
        }
    }

    func offerUpdateChecks(on window: NSWindow?) {
        guard updater != nil, (privateChannel == nil || hasPrivateCredential), let window,
              !presentingConsent, !defaults.bool(forKey: Self.consentKey) else { return }
        presentingConsent = true
        let alert = NSAlert()
        alert.messageText = "Check for Folio updates automatically?"
        alert.informativeText = "Folio checks at startup when a check is due and every 24 hours while it’s open. You can change this in Settings."
        alert.addButton(withTitle: "Check Automatically")
        alert.addButton(withTitle: "Not Now")
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.presentingConsent = false
            self?.setAutomaticChecks(response == .alertFirstButtonReturn)
        }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard let updater else { return }
        automaticChecks = enabled
        if privateChannel != nil {
            defaults.set(enabled, forKey: Self.privateAutomaticKey)
        } else {
            updater.automaticallyChecksForUpdates = enabled
        }
        defaults.set(true, forKey: Self.consentKey)
    }

    func openUpdateSettings() {
        settingsPage = .updates
        showSettings?()
        check()
    }

    func savePrivateCredential(_ value: String) {
        guard let privateChannel, canEditPrivateCredential else { return }
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try privateChannel.storeToken(token)
            clearOffer()
            privateSnapshot = nil
            privateToken = token.isEmpty ? nil : token
            defaults.removeObject(forKey: Self.privateLastCheckKey)
            set(.idle, token.isEmpty ? "Add GitHub access to check for updates." : "GitHub access saved.")
        } catch {
            set(.failed, error.localizedDescription)
        }
    }

    func check() {
        guard canCheck, updater?.sessionInProgress == false else { return }
        if privateChannel != nil {
            checkPrivateUpdates(userInitiated: true)
            return
        }
        manualCheck = true
        set(.checking, "Checking for updates…")
        updater?.checkForUpdates()
    }

    private func checkPrivateUpdatesIfDue() {
        guard privateChannel != nil, automaticChecks, canCheck, updater?.sessionInProgress == false else { return }
        if let last = defaults.object(forKey: Self.privateLastCheckKey) as? Date,
           Date().timeIntervalSince(last) < 86400 { return }
        checkPrivateUpdates(userInitiated: false)
    }

    private func checkPrivateUpdates(userInitiated: Bool) {
        guard let privateChannel, let privateToken, privateCheck == nil else { return }
        defaults.set(Date(), forKey: Self.privateLastCheckKey)
        set(.checking, "Checking for updates…")
        privateCheck = Task {
            defer { privateCheck = nil }
            do {
                let snapshot = try await privateChannel.latest(token: privateToken, using: transferSession)
                try Task.checkCancellation()
                privateSnapshot = snapshot
                manualCheck = userInitiated
                if userInitiated {
                    updater?.checkForUpdates()
                } else {
                    updater?.checkForUpdatesInBackground()
                }
            } catch {
                if Task.isCancelled {
                    set(.idle, "Check canceled.")
                } else {
                    set(.failed, "Couldn’t check for updates. \(error.localizedDescription)")
                }
            }
        }
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        privateSnapshot?.feed.appcast.absoluteString
    }

    func download() {
        guard canDownload, let offer, let key else { return }
        let request: URLRequest
        if let privateChannel {
            guard let privateSnapshot, privateSnapshot.archiveURL == offer.url, let privateToken else { return }
            request = privateChannel.archiveRequest(privateSnapshot, token: privateToken)
        } else {
            request = URLRequest(url: offer.url, cachePolicy: .reloadIgnoringLocalCacheData)
        }
        set(.downloading, "Downloading Folio \(offer.version)…")
        let task = transferSession.downloadTask(with: request) { [weak self] file, response, error in
            let result = Result {
                if let error { throw error }
                guard let file, let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let finalURL = response.url,
                      finalURL.scheme == offer.url.scheme,
                      (offer.url.scheme == "https" || finalURL.host == "localhost") else {
                    throw UpdateFailure("The update server didn’t return an archive.")
                }
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize
                guard size == offer.length else { throw UpdateFailure("The archive size doesn’t match the signed update.") }
                let bytes = try Data(contentsOf: file, options: .mappedIfSafe)
                guard key.isValidSignature(offer.signature, for: bytes) else {
                    throw UpdateFailure("The update signature couldn’t be verified.")
                }
                return bytes
            }
            Task { @MainActor [weak self] in self?.downloadFinished(result, for: offer) }
        }
        transfer = task
        task.resume()
    }

    private func downloadFinished(_ result: Result<Data, any Error>, for offer: Offer) {
        guard self.offer == offer, transfer != nil else { return }
        transfer = nil
        switch result {
        case .success(let data):
            archive = data
            set(.downloaded, "Folio \(offer.version) is ready to install.")
        case .failure(let error):
            if (error as NSError).code == NSURLErrorCancelled {
                set(.offered, "Download canceled.")
            } else {
                set(.failed, "Couldn’t download the update. \(error.localizedDescription)")
            }
        }
    }

    func cancel() {
        if let privateCheck {
            privateCheck.cancel()
        } else if let transfer {
            transfer.cancel()
        } else {
            set(.idle, "Check canceled.")
            checkCancellation?()
            checkCancellation = nil
        }
    }

    func deferInstallation() {
        deferredOffer = offer
        restartAfter = nil
        if let offer { set(.downloaded, "Folio \(offer.version) is ready to install.") }
    }

    func install() {
        guard canInstall, let offer else { return }
        guard canRestart else {
            set(.waiting, restartDelayMessage)
            return
        }
        guard let updater, !updater.sessionInProgress else { return }
        if privateChannel != nil {
            guard let privateSnapshot, privateSnapshot.archiveURL == offer.url, let archive else { return }
            privateSnapshot.feed.setArchive(archive)
        }
        authorized = offer
        set(.installing, "Preparing to install Folio \(offer.version)…")
        updater.checkForUpdates()
    }

    private var otherInstancesRunning: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).contains {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated
        }
    }

    private var canRestart: Bool {
        !presentingConsent && model?.hasUpdateActivity == false && !otherInstancesRunning
    }

    private var restartDelayMessage: String {
        otherInstancesRunning
            ? "Close the other Folio instances before installing the update."
            : "Finish editing, opening files, or playing media before restarting."
    }

    private func installWhenIdle() {
        if let resume = postponeRelaunch, canRestart {
            postponeRelaunch = nil
            set(.installing, "Restarting to finish the update…")
            resume()
        } else if let retry = retryTermination, canRestart {
            retryTermination = nil
            set(.installing, "Restarting to finish the update…")
            retry()
        } else if authorized == nil, automaticInstalls, deferredOffer != offer, canInstall, !lastCheckFailed {
            guard canRestart else {
                restartAfter = nil
                if phase != .waiting { set(.waiting, restartDelayMessage) }
                return
            }
            let now = ContinuousClock.now
            if let restartAfter {
                if now >= restartAfter { install() }
            } else {
                restartAfter = now.advanced(by: .seconds(10))
                set(.downloaded, "Folio will restart in 10 seconds to install the update.")
            }
        }
    }

    func allowUpdateTermination() -> Bool {
        guard isInstalling, !canRestart else { return true }
        set(.waiting, restartDelayMessage)
        return false
    }

    private func clearOffer() {
        transfer?.cancel()
        transfer = nil
        offer = nil
        archive = nil
    }

    private func set(_ phase: Phase, _ status: String) {
        self.phase = phase
        self.status = status
    }

    private func candidate(_ item: SUAppcastItem) throws -> Offer {
        let bundleID = Bundle.main.bundleIdentifier
        let qa = bundleID == "org.popomore.folio.update-qa"
        guard item.signingValidationStatus == .succeeded, item.channel == nil, !item.isInformationOnlyUpdate,
              item.installationType == "application", item.arm64HardwareRequirementIsOK,
              item.minimumOperatingSystemVersionIsOK, let url = item.fileURL,
              url.pathExtension == "zip", url.user == nil, url.password == nil,
              url.scheme == (qa ? "http" : "https"),
              let feed,
              qa ? (url.host == "localhost" && url.port == feed.port) :
                  (url.host == "github.com" && url.pathComponents.prefix(3) == feed.pathComponents.prefix(3)),
              privateChannel == nil || privateSnapshot?.archiveURL == url,
              item.minimumSystemVersion == "14.0", item.hardwareRequirements.contains("arm64"),
              item.contentLength > 0, item.contentLength <= Self.maximumArchiveSize,
              let enclosure = item.propertiesDictionary["enclosure"] as? [String: Any],
              let encoded = enclosure["sparkle:edSignature"] as? String,
              let signature = Data(base64Encoded: encoded), signature.count == 64 else {
            throw UpdateFailure("The signed update doesn’t match this build’s distribution requirements.")
        }
        return Offer(version: item.displayVersionString, build: item.versionString,
                     notes: item.itemDescription ?? "Release notes are unavailable.", url: url,
                     length: Int(item.contentLength), signature: signature)
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        _ = try candidate(item)
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { checkCancellation = cancellation }

    func showUpdateFound(with item: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        checkCancellation = nil
        guard let newOffer = try? candidate(item) else {
            set(.failed, "Couldn’t verify the signed update.")
            reply(state.stage == .installing ? .skip : .dismiss)
            return
        }
        if offer == newOffer, transfer != nil {
            reply(.dismiss)
            return
        }
        if offer != newOffer {
            transfer?.cancel()
            transfer = nil
            archive = nil
        }
        offer = newOffer
        if authorized == newOffer, archive != nil, state.stage == .notDownloaded {
            reply(.install)
            return
        }
        if authorized == newOffer, state.stage == .installing, canRestart {
            // Sparkle can resume an installer from a previously authorized handoff.
            reply(.install)
            return
        }
        authorized = nil
        if state.stage == .installing {
            reply(.skip)
            return
        }
        if archive != nil {
            set(.downloaded, "Folio \(newOffer.version) is ready to install.")
        } else {
            set(.offered, "Folio \(newOffer.version) is available.")
            if !state.userInitiated && automaticChecks && automaticDownloads { download() }
        }
        reply(.dismiss)
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        guard let url = item.fileURL, let archive, let authorized,
              offer == authorized, url == authorized.url else { return }
        if let privateSnapshot {
            request.url = privateSnapshot.feed.archive
            return
        }
        // Sparkle owns extraction, validation and installation. It can use the verified
        // bytes, or fetch the same signed asset again if CFNetwork has evicted the cache.
        guard let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/zip", "Content-Length": String(archive.count),
                           "Content-Disposition": "attachment; filename=Folio.zip", "Cache-Control": "max-age=600"]
        ) else { return }
        request.cachePolicy = .returnCacheDataElseLoad
        let cacheRequest = request as URLRequest
        let cache = URLCache.shared
        if previousCacheCapacity == nil { previousCacheCapacity = cache.memoryCapacity }
        cache.memoryCapacity = max(cache.memoryCapacity, Self.maximumArchiveSize * 6)
        cache.storeCachedResponse(CachedURLResponse(response: response, data: archive, storagePolicy: .allowedInMemoryOnly), for: cacheRequest)
        cachedRequest = cacheRequest
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        checkCancellation = nil
        clearOffer()
        set(.idle, "Folio \(currentVersion) is up to date.")
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        checkCancellation = nil
        set(.failed, "Update failed. \(error.localizedDescription)")
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { set(.installing, "Verifying and preparing the update…") }
    func showExtractionReceivedProgress(_ progress: Double) { installationProgress = progress }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard authorized != nil, canRestart else {
            // Dismiss would leave Sparkle's installer running and install on an ordinary quit.
            set(.waiting, restartDelayMessage)
            reply(.skip)
            return
        }
        reply(.install)
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock install: @escaping () -> Void) -> Bool {
        guard !canRestart else { return false }
        postponeRelaunch = install
        set(.waiting, restartDelayMessage)
        return true
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        set(.installing, "Installing the update and restarting…")
        if !applicationTerminated { retryTermination = retryTerminatingApplication }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        set(.idle, "Folio is up to date.")
        acknowledgement()
    }

    func dismissUpdateInstallation() { checkCancellation = nil }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        privateSnapshot?.feed.setArchive(nil)
        if let cachedRequest {
            URLCache.shared.removeCachedResponse(for: cachedRequest)
            self.cachedRequest = nil
        }
        if let previousCacheCapacity {
            URLCache.shared.memoryCapacity = previousCacheCapacity
            self.previousCacheCapacity = nil
        }
        if !manualCheck, let error, ![.failed, .waiting].contains(phase) {
            let info = error as NSError
            if info.domain == SUSparkleErrorDomain && info.code == 1001 {
                clearOffer()
                set(.idle, "Folio \(currentVersion) is up to date.")
            } else {
                set(.failed, "Couldn’t check for updates. \(error.localizedDescription)")
            }
        }
        if phase == .checking, error == nil {
            set(.idle, "Check for a new version of Folio.")
        }
        if phase == .installing, error == nil, authorized != nil, archive != nil {
            set(.downloaded, "The update was deferred. You can try restarting again.")
        }
        installationProgress = nil
        checkCancellation = nil
        authorized = nil
        retryTermination = nil
        postponeRelaunch = nil
        manualCheck = false
    }
}
