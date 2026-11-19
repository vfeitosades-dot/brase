import SwiftUI
import WebKit

@main
@MainActor
struct BrisaApp: App {
    @StateObject private var browser = Browser(defaults: .standard)

    var body: some Scene {
        WindowGroup {
            BrowserView(browser: browser)
        }
    }
}

@MainActor
struct BrowserView: View {
    @ObservedObject var browser: Browser
    @State private var input = ""
    @FocusState private var editing: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        colorScheme == .dark
            ? Color(red: 0.45, green: 0.85, blue: 0.80)
            : Color(red: 0.02, green: 0.36, blue: 0.34)
    }

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            ZStack {
                Rectangle().fill(Color(UIColor.separator)).frame(height: 1)
                if browser.isLoading {
                    ProgressView(value: browser.progress)
                        .progressViewStyle(.linear)
                        .accessibilityLabel("Carregando página")
                }
            }
            .frame(height: 2)

            ZStack {
                let showPage = !browser.isHome && browser.failure == nil && !browser.awaitingCommit
                WebSurface(webView: browser.webView)
                    .opacity(showPage ? 1 : 0)
                    .allowsHitTesting(showPage)
                    .accessibilityHidden(!showPage)

                if browser.isHome {
                    startPage
                } else if let failure = browser.failure {
                    errorPage(failure)
                } else if browser.awaitingCommit {
                    ProgressView("Carregando página")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))

            Divider()
            toolbar
        }
        .background(Color(UIColor.systemBackground))
        .tint(tint)
        .onChange(of: browser.address) { url in
            if !editing { input = url?.absoluteString ?? "" }
        }
        .onChange(of: editing) { isEditing in
            if !isEditing { input = browser.address?.absoluteString ?? "" }
        }
        .alert("Brisa", isPresented: Binding(
            get: { browser.notice != nil },
            set: { if !$0 { browser.notice = nil } }
        )) {
            Button("OK", role: .cancel) { browser.notice = nil }
        } message: {
            Text(browser.notice ?? "")
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            if browser.address?.scheme == "http" && !editing {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Conexão sem HTTPS")
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            TextField("Endereço ou busca", text: $input)
                .focused($editing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.URL)
                .submitLabel(.go)
                .accessibilityIdentifier("address")
                .onSubmit {
                    browser.submit(input)
                    editing = false
                }

            if editing && !input.isEmpty {
                Button {
                    input = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Limpar endereço")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, editing && !input.isEmpty ? 0 : 12)
        .frame(minHeight: 44)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var startPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "wind")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(Color(red: 0.02, green: 0.36, blue: 0.34), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)

                Text("Brisa")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                Button {
                    editing = false
                    browser.load(BrowserAddress.instagram)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.title3)
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Instagram").font(.headline).foregroundStyle(.primary)
                            Text("Entrar pelo site").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("instagram")
            }
            .frame(maxWidth: 420, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func errorPage(_ failure: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Página indisponível", systemImage: "exclamationmark.circle")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(failure).foregroundStyle(.secondary)
                Button("Tentar novamente", action: browser.reloadOrStop)
                    .buttonStyle(.borderedProminent)
                if browser.address?.host == "www.instagram.com" || browser.address?.host == "instagram.com" {
                    Button(browser.desktop ? "Tentar versão móvel" : "Tentar versão para computador",
                           action: browser.toggleDesktop)
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            tool("Voltar", "chevron.left", action: browser.back)
                .disabled(browser.isHome && !browser.canReturnFromHome)
            tool("Avançar", "chevron.right", action: browser.forward)
                .disabled(browser.isHome || !browser.canGoForward)
            tool("Início", "house", action: browser.home)
                .disabled(browser.isHome)
            tool(browser.isLoading ? "Parar" : "Recarregar",
                 browser.isLoading ? "xmark" : "arrow.clockwise", action: browser.reloadOrStop)
                .disabled(browser.isHome || browser.preparing)

            Menu {
                Button(action: browser.toggleBlocking) {
                    Label(browser.blocking && browser.rulesAvailable ? "Desativar bloqueio de anúncios" : "Ativar bloqueio de anúncios",
                          systemImage: browser.blocking && browser.rulesAvailable ? "shield.slash" : "shield")
                }
                .disabled(!browser.rulesAvailable)
                if !browser.preparing && !browser.rulesAvailable {
                    Text("Bloqueio de anúncios indisponível")
                }

                Button(action: browser.toggleDesktop) {
                    Label(browser.desktop ? "Solicitar versão móvel" : "Solicitar versão para computador",
                          systemImage: browser.desktop ? "iphone" : "desktopcomputer")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Opções")
        }
        .padding(.horizontal, 4)
    }

    private func tool(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            editing = false
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
    }
}

struct WebSurface: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
