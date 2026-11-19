import Foundation

enum BrowserAddress {
    static let instagram = URL(string: "https://www.instagram.com/accounts/login/")!

    static func resolve(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if text.hasPrefix("//") {
            return webURL(URL(string: "https:" + text))
        }
        if text.range(of: #"^https?:"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return webURL(URL(string: text))
        }
        let host = text.prefix { !"/?#".contains($0) }
        let domain = host.split(separator: ":", maxSplits: 1).first ?? ""
        let resemblesAddress = domain.contains(".") || domain == "localhost" || host.hasPrefix("[")
        if resemblesAddress && host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            return webURL(URL(string: "https://" + text))
        }
        if text.range(of: #"^[a-z][a-z0-9+.-]*:"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return nil
        }

        var search = URLComponents()
        search.scheme = "https"
        search.host = "duckduckgo.com"
        search.path = "/"
        search.queryItems = [URLQueryItem(name: "q", value: text)]
        search.percentEncodedQuery = search.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return search.url
    }

    static func webURL(_ url: URL?) -> URL? {
        guard let url, let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}
