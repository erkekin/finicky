import Foundation

class ResolveShortUrls: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    fileprivate var shortUrlResolver: FNShortUrlResolver?

    init(shortUrlResolver: FNShortUrlResolver) {
        self.shortUrlResolver = shortUrlResolver
        super.init()
    }

    func urlSession(_: URLSession, task _: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        var newRequest: URLRequest? = request

        if [301, 302, 309].contains(response.statusCode) {
            if let newUrl = URL(string: (response.allHeaderFields["Location"] as? String)!) {
                if !shortUrlResolver!.isShortUrl(newUrl) {
                    newRequest = nil
                }
            }
        }

        completionHandler(newRequest)
    }
}

let defaultUrlShorteners = [
    "adf.ly",
    "bit.do",
    "bit.ly",
    "buff.ly",
    "deck.ly",
    "fur.ly",
    "goo.gl",
    "is.gd",
    "mcaf.ee",
    "ow.ly",
    "spoti.fi",
    "su.pr",
    "t.co",
    "tiny.cc",
    "tinyurl.com",
]

class FNShortUrlResolver {
    private var shortUrlProviders: [String] = []
    var version: String

    init() {
        shortUrlProviders = defaultUrlShorteners
        version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }

    init(shortUrlProviders: [String]?) {
        self.shortUrlProviders = shortUrlProviders ?? defaultUrlShorteners
        version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }

    func isShortUrl(_ url: URL) -> Bool {
        if url.host == nil {
            return false
        }

        let isShortUrlProvider = shortUrlProviders.contains(url.host!)

        if !isShortUrlProvider {
            return false
        }

        // Can't load insecure cleartext HTTP
        // https://stackoverflow.com/questions/31254725/transport-security-has-blocked-a-cleartext-http
        if url.scheme == "https" {
            return true
        }

        return false
    }

    func resolveUrl(_ url: URL, callback: @escaping ((URL) -> Void)) {
        if !isShortUrl(url) {
            callback(url)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("finicky/\(version)", forHTTPHeaderField: "User-Agent")
        let myDelegate = ResolveShortUrls(shortUrlResolver: self)
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: myDelegate, delegateQueue: nil)

        let task = session.dataTask(with: request, completionHandler: { (_, response, _) -> Void in

            if let httpResponse: HTTPURLResponse = response as? HTTPURLResponse {
                let newUrl = URL(string: httpResponse.allHeaderFields["Location"] as? String ?? url.absoluteString)
                callback(newUrl ?? url)
            } else {
                callback(url)
            }

        })

        task.resume()
        return
    }
}
