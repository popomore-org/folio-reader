import Foundation
import WebKit

@MainActor
final class ChartPreview: NSObject, WKNavigationDelegate {
    private var loading: CheckedContinuation<Void, any Error>?

    static func render(_ page: Data, resources: Bundle) async throws -> Data {
        guard let scriptURL = resources.url(forResource: "reader", withExtension: "js") else {
            throw CoreError(message: "The chart renderer is missing.")
        }
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        let size = PreviewProvider.previewSize
        let web = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        let navigation = ChartPreview()
        web.navigationDelegate = navigation
        try await withCheckedThrowingContinuation { continuation in
            navigation.loading = continuation
            if web.loadHTMLString(String(decoding: page, as: UTF8.self), baseURL: nil) == nil {
                navigation.complete(CoreError(message: "Could not load the chart preview."))
            }
        }
        try Task.checkCancellation()
        let height = try await web.callAsyncJavaScript("""
            await window.folioChartsReady;
            if (!document.querySelector('figure.diagram:not(.diagram-error)')) return 0;
            return document.documentElement.scrollHeight;
            """, contentWorld: .page)
        guard let height = height as? Double, height > 0, height <= 16_000 else {
            throw CoreError(message: "Could not lay out the chart preview as a PDF.")
        }
        let pdf = WKPDFConfiguration()
        pdf.rect = CGRect(x: 0, y: 0, width: size.width, height: max(size.height, height))
        return try await web.pdf(configuration: pdf)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { complete(nil) }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        complete(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        complete(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        complete(CoreError(message: "The chart preview renderer exited."))
    }

    private func complete(_ error: (any Error)?) {
        guard let continuation = loading else { return }
        loading = nil
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }
}
