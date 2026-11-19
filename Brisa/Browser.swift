import SwiftUI
import WebKit

@MainActor
final class Browser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published private(set) var address: URL?
    @Published private(set) var isHome = true
    @Published private(set) var isLoading = false
    @Published private(set) var awaitingCommit = false
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canReturnFromHome = false
    @Published private(set) var canGoForward = false
    @Published private(set) var desktop: Bool
    @Published private(set) var blocking: Bool
    @Published private(set) var preparing = true
    @Published private(set) var rulesAvailable = false
    @Published private(set) var failure: String?
    @Published var notice: String?

    private let defaults: UserDefaults
    private var attemptedURL: URL?
    private var activeNavigation: WKNavigation?
    private var ruleList: WKContentRuleList?
    private var observations: [NSKeyValueObservation] = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
        desktop = defaults.bool(forKey: "desktop")
        blocking = defaults.object(forKey: "blocking") as? Bool ?? true

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        observations = [
            webView.observe(\.url) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.isLoading) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.estimatedProgress) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.canGoBack) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.canGoForward) { [weak self] _, _ in self?.scheduleRefresh() }
        ]

        guard let file = Bundle.main.url(forResource: "AdRules", withExtension: "json"),
              let rules = try? String(contentsOf: file, encoding: .utf8),
              let store = WKContentRuleListStore.default() else {
            preparing = false
            return
        }
        store.compileContentRuleList(forIdentifier: "BrisaAds", encodedContentRuleList: rules) {
            [weak self] list, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.ruleList = list
                self.rulesAvailable = list != nil
                self.applyRules()
                self.preparing = false
                if !self.isHome, let pending = self.attemptedURL {
                    self.load(pending)
                }
            }
        }
    }

    private nonisolated func scheduleRefresh() {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    private func refresh() {
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if !isHome, !awaitingCommit, failure == nil, let visible = BrowserAddress.webURL(webView.url) {
            address = visible
        }
    }

    func submit(_ text: String) {
        guard let url = BrowserAddress.resolve(text) else {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notice = "Confira o endereço. O Brisa abre links HTTP e HTTPS."
            }
            return
        }
        load(url)
    }

    func load(_ url: URL) {
        isHome = false
        awaitingCommit = true
        failure = nil
        attemptedURL = url
        address = url
        guard !preparing else { return }
        activeNavigation = webView.load(URLRequest(url: url))
    }

    func home() {
        isHome = true
        awaitingCommit = false
        activeNavigation = nil
        webView.stopLoading()
        address = nil
        failure = nil
        canReturnFromHome = webView.backForwardList.currentItem != nil
    }

    func back() {
        if isHome {
            if let url = BrowserAddress.webURL(webView.backForwardList.currentItem?.url) {
                isHome = false
                address = url
            }
        } else if webView.canGoBack {
            awaitingCommit = true
            failure = nil
            activeNavigation = webView.goBack()
        } else {
            home()
        }
    }

    func forward() {
        guard !isHome, webView.canGoForward else { return }
        awaitingCommit = true
        failure = nil
        activeNavigation = webView.goForward()
    }

    func reloadOrStop() {
        if isLoading {
            activeNavigation = nil
            webView.stopLoading()
            awaitingCommit = false
            if let url = BrowserAddress.webURL(webView.backForwardList.currentItem?.url) {
                address = url
                attemptedURL = url
            } else {
                home()
            }
        } else {
            reload()
        }
    }

    private func reload() {
        guard !isHome, !preparing else { return }
        if failure == nil, webView.url != nil {
            awaitingCommit = true
            activeNavigation = webView.reload()
        } else if let attemptedURL {
            load(attemptedURL)
        }
    }

    func toggleDesktop() {
        desktop.toggle()
        defaults.set(desktop, forKey: "desktop")
        reload()
    }

    func toggleBlocking() {
        guard rulesAvailable else { return }
        blocking.toggle()
        defaults.set(blocking, forKey: "blocking")
        applyRules()
        reload()
    }

    private func applyRules() {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        if blocking, let ruleList {
            controller.add(ruleList)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        let url = action.request.url
        if action.targetFrame?.isMainFrame == false {
            let allowed = BrowserAddress.webURL(url) != nil || url?.scheme == "about" || url?.scheme == "blob"
            decisionHandler(allowed ? .allow : .cancel, preferences)
            return
        }
        guard BrowserAddress.webURL(url) != nil else {
            if action.navigationType == .linkActivated {
                notice = "Este link solicita outro aplicativo."
            }
            decisionHandler(.cancel, preferences)
            return
        }
        preferences.preferredContentMode = desktop ? .desktop : .mobile
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, BrowserAddress.webURL(action.request.url) != nil {
            activeNavigation = webView.load(action.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard !isHome else { return }
        activeNavigation = navigation
        awaitingCommit = true
        failure = nil
        refresh()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard !isHome, navigation === activeNavigation else { return }
        awaitingCommit = false
        refresh()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === activeNavigation else { return }
        awaitingCommit = false
        attemptedURL = BrowserAddress.webURL(webView.url) ?? attemptedURL
        refresh()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        showFailure(error, for: navigation)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure(error, for: navigation)
    }

    private func showFailure(_ error: Error, for navigation: WKNavigation?) {
        let underlying = error as NSError
        guard !isHome, navigation === activeNavigation,
              !(underlying.domain == NSURLErrorDomain && underlying.code == NSURLErrorCancelled) else { return }
        awaitingCommit = false
        let failedURL = underlying.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        attemptedURL = BrowserAddress.webURL(failedURL) ?? attemptedURL
        failure = underlying.localizedDescription
        address = attemptedURL
        refresh()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !isHome else { return }
        awaitingCommit = false
        failure = "O iOS encerrou a página. Tente carregar de novo."
        refresh()
    }
}
