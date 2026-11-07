import SwiftUI
import WebKit
import SafariServices

/// A WKWebView that loads the live FundiMtaani site.
///
/// The wrapper keeps 100% of the web features and the exact same UI:
/// auth, booking, the join wizard and the admin console all run inside
/// this view on the site's own Flask session cookie. The cookie store is
/// the persistent default store and is never cleared by the app, so a
/// 4-hour session survives an app restart. Each app has its own store
/// because it is a separate app; the two apps never share cookies.
///
/// Navigation rules (from the live-site audit):
/// - Top-level loads only; the site sends X-Frame-Options: DENY.
/// - wa.me, tel: and mailto: links leave the app via UIApplication.
/// - target="_blank" links are not swallowed: same-site document links
///   open in an in-app Safari sheet, everything else opens externally.
/// - Redirects are followed normally and are never treated as errors
///   (the technician join gate redirects on almost every endpoint).
/// - Failed logins are never auto-retried: the site rate-limits login
///   (10/hr) and admin login (3/hr), so a retry loop would lock the
///   user out. The server's own error page is shown instead.
struct WebViewContainer: UIViewRepresentable {
    @Binding var mode: SiteMode
    @Binding var progress: Double
    @Binding var isLoading: Bool
    @Binding var hasContent: Bool
    @Binding var isOffline: Bool
    @Binding var safariURL: SafariItem?
    var reloadTrigger: Int

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Persistent default store: the Flask session cookie survives
        // app restarts. Never use a non-persistent (ephemeral) store.
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Pull-to-refresh.
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.refreshPulled), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        context.coordinator.webView = webView
        webView.load(URLRequest(url: Brand.entryURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.reload()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate , WKDownloadDelegate {
        var parent: WebViewContainer
        weak var webView: WKWebView?
        var lastReloadTrigger = 0
        private var progressObservation: NSKeyValueObservation?
        private var awaiting503Classification = false
                private var pendingDownloadURL: URL?


        init(parent: WebViewContainer) {
            self.parent = parent
        }

        func attachProgressObservation() {
            guard let webView else { return }
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = view.estimatedProgress
                }
            }
        }

        @objc func refreshPulled() {
            webView?.reload()
        }

        // MARK: - External links

        private func openExternally(_ url: URL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        private func handleExternalLink(_ url: URL) -> Bool {
            guard let scheme = url.scheme?.lowercased() else { return false }
            if scheme == "tel" || scheme == "mailto" {
                openExternally(url)
                return true
            }
            if let host = url.host?.lowercased(), host == "wa.me" || host.hasSuffix(".wa.me") {
                openExternally(url)
                return true
            }
            return false
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if handleExternalLink(url) {
                decisionHandler(.cancel)
                return
            }
            // target="_blank" links arrive with no target frame. Same-site
            // document links open in an in-app Safari sheet; anything else
            // leaves the app instead of being swallowed.
            if navigationAction.targetFrame == nil {
                if url.host?.lowercased() == Brand.siteHost {
                    DispatchQueue.main.async { self.parent.safariURL = SafariItem(url: url) }
                } else {
                    openExternally(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
                        if isDownloadURL(navigationResponse.response.url) {
                decisionHandler(.download)
                return
            }

            guard navigationResponse.isForMainFrame,
                  let http = navigationResponse.response as? HTTPURLResponse else {
                decisionHandler(.allow)
                return
            }
            // Mode detection: the site has no status endpoint, so the HTTP
            // status of the top-level load is the only signal.
            switch http.statusCode {
            case 200:
                DispatchQueue.main.async {
                    self.parent.mode = .live
                    self.parent.isOffline = false
                }
                awaiting503Classification = false
            case 503:
                // Maintenance and pre-launch both return 503; the loaded
                // page's wording tells them apart (checked in didFinish).
                awaiting503Classification = true
                DispatchQueue.main.async { self.parent.isOffline = false }
            default:
                break
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if progressObservation == nil {
                attachProgressObservation()
            }
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasContent = true
                self.parent.progress = 1.0
                self.parent.isOffline = false
            }
            webView.scrollView.refreshControl?.endRefreshing()
            if awaiting503Classification {
                awaiting503Classification = false
                webView.evaluateJavaScript("document.title + ' ' + document.body.innerText.slice(0, 2000)") { result, _ in
                    guard let text = result as? String else { return }
                    let classified = SiteMode.classify503Page(text: text)
                    DispatchQueue.main.async { self.parent.mode = classified }
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleFailure(error: error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleFailure(error: error)
        }

        private func handleFailure(error: Error) {
            let code = (error as NSError).code
            // A cancelled load is not an error (e.g. a link opened
            // externally). Only a real failure shows the offline screen,
            // and only when nothing has loaded yet.
            guard code != NSURLErrorCancelled else { return }
            DispatchQueue.main.async {
                self.parent.isLoading = false
                if !self.parent.hasContent {
                    self.parent.mode = .offline
                    self.parent.isOffline = true
                }
            }
            webView?.scrollView.refreshControl?.endRefreshing()
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            if handleExternalLink(url) { return nil }
            if url.host?.lowercased() == Brand.siteHost {
                DispatchQueue.main.async { self.parent.safariURL = SafariItem(url: url) }
            } else {
                openExternally(url)
            }
            return nil
        }

        
        // MARK: - Downloads (admin only)

        /// Paths that download a file instead of showing a page:
        /// .sql backups, users CSV and the bookings / fundis CSV exports.
        /// Verification documents are served inline and open in the
        /// Safari sheet instead; they are not downloads.
        private func isDownloadURL(_ url: URL?) -> Bool {
            guard let url else { return false }
            let path = url.path
            return path.hasPrefix("/admin/backups/download/")
                || path == "/admin/users.csv"
                || path.hasPrefix("/admin/export/")
        }

        /// Shared destination for both decideDestination forms: the file
        /// lands in Documents and is offered through the share sheet
        /// once the download finishes.
        private func destinationURL(for suggestedFilename: String) -> URL {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destination = documents.appendingPathComponent(suggestedFilename)
            pendingDownloadURL = destination
            return destination
        }

        // WKDownloadDelegate methods take the WKDownload itself, not a
        // WKWebView: the webView(_:download:...) shapes never match the
        // protocol, so the compiler still reported non-conformance after
        // round 1. Both decideDestination forms are required on this SDK
        // (completion-handler and async); they share the destination
        // above so the behaviour is identical either way.
        @MainActor
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
            completionHandler(destinationURL(for: suggestedFilename))
        }

        @MainActor
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
            destinationURL(for: suggestedFilename)
        }

        @MainActor
        func downloadDidFinish(_ download: WKDownload) {
            guard let url = pendingDownloadURL else { return }
            pendingDownloadURL = nil
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            Self.present(activity)
        }

        @MainActor
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            pendingDownloadURL = nil
        }

        private static func present(_ viewController: UIViewController) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            top.present(viewController, animated: true)
        }

    }
}

/// In-app Safari sheet for same-site document links opened with
/// target="_blank" (admin verification documents, share links).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
