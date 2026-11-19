import Foundation

let exact = [
    ("instagram.com", "https://instagram.com"),
    (" //www.instagram.com/accounts/login/ ", "https://www.instagram.com/accounts/login/"),
    ("http://example.com/test?mode=test#sec", "http://example.com/test?mode=test#sec"),
    ("localhost:8080", "https://localhost:8080"),
    ("[::1]:8080", "https://[::1]:8080"),
]
for (input, expected) in exact {
    precondition(BrowserAddress.resolve(input)?.absoluteString == expected, input)
}
for input in ["  ", "https://", "file:///tmp/test", "javascript:alert(1)", "https://user:pass@example.com"] {
    precondition(BrowserAddress.resolve(input) == nil, input)
}
let query = BrowserAddress.resolve("café com leite & C++")!
precondition(query.host == "duckduckgo.com")
precondition(URLComponents(url: query, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "café com leite & C++")
precondition(query.absoluteString.contains("C%2B%2B"))
print("Verificações de endereço passaram.")
