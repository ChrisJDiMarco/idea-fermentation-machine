import Foundation

/// Payload POSTed by the Chrome extension to `/capture`. Every field except `url`
/// is optional so the extension can degrade gracefully (e.g. a context-menu save
/// with only a selection, or a page where extraction found little).
public struct CapturePayload: Codable, Equatable, Sendable {
    public var url: String
    public var title: String?
    public var selectionText: String?
    public var pageText: String?
    public var excerpt: String?
    public var siteName: String?
    public var author: String?
    public var publishedTime: String?
    public var faviconURL: String?
    /// Coarse hint from the extension ("article", "repo", "video", "social", "pdf", "doc", "page").
    public var kindHint: String?
    public var note: String?
    public var tags: [String]?
    public var neverSendToCloud: Bool?
    /// "source" (default) or "idea".
    public var saveAs: String?
    public var capturedAt: Double?

    public init(
        url: String,
        title: String? = nil,
        selectionText: String? = nil,
        pageText: String? = nil,
        excerpt: String? = nil,
        siteName: String? = nil,
        author: String? = nil,
        publishedTime: String? = nil,
        faviconURL: String? = nil,
        kindHint: String? = nil,
        note: String? = nil,
        tags: [String]? = nil,
        neverSendToCloud: Bool? = nil,
        saveAs: String? = nil,
        capturedAt: Double? = nil
    ) {
        self.url = url
        self.title = title
        self.selectionText = selectionText
        self.pageText = pageText
        self.excerpt = excerpt
        self.siteName = siteName
        self.author = author
        self.publishedTime = publishedTime
        self.faviconURL = faviconURL
        self.kindHint = kindHint
        self.note = note
        self.tags = tags
        self.neverSendToCloud = neverSendToCloud
        self.saveAs = saveAs
        self.capturedAt = capturedAt
    }

    public enum SaveMode: String, Sendable {
        case source
        case idea
    }

    public var mode: SaveMode {
        SaveMode(rawValue: (saveAs ?? "source").lowercased()) ?? .source
    }
}

/// The app's response, surfaced verbatim in the extension's confirmation toast.
public struct CaptureResult: Codable, Equatable, Sendable {
    public var ok: Bool
    public var deduped: Bool
    public var sourceID: String
    public var ideaID: String?
    public var type: String
    public var category: String
    public var title: String
    public var tags: [String]
    public var linkedIdeas: [String]
    public var message: String

    public init(ok: Bool, deduped: Bool, sourceID: String, ideaID: String? = nil, type: String, category: String, title: String, tags: [String], linkedIdeas: [String], message: String) {
        self.ok = ok
        self.deduped = deduped
        self.sourceID = sourceID
        self.ideaID = ideaID
        self.type = type
        self.category = category
        self.title = title
        self.tags = tags
        self.linkedIdeas = linkedIdeas
        self.message = message
    }
}

/// Persisted (port + enabled) in app_settings. The bearer token lives in Keychain.
public struct CaptureServerConfig: Codable, Equatable, Sendable {
    public var port: Int
    public var isEnabled: Bool

    public static let defaultPort = 51720

    public init(port: Int = CaptureServerConfig.defaultPort, isEnabled: Bool = true) {
        self.port = port
        self.isEnabled = isEnabled
    }
}

/// Maps a captured web page onto the app's existing `SourceType` plus a richer,
/// human-readable category label (kept in `SourceMetadata.category`).
public enum SourceClassifier {
    public static func classify(url: String, kindHint: String? = nil) -> (type: SourceType, category: String) {
        let host = host(of: url).lowercased()
        let path = url.lowercased()

        if kindHint == "pdf" || path.hasSuffix(".pdf") {
            return (.document, "PDF")
        }
        if host.contains("github.") || host.contains("gitlab.") || host.contains("bitbucket.") || kindHint == "repo" {
            return (.link, "Repository")
        }
        if host.contains("youtube.") || host.contains("youtu.be") || host.contains("vimeo.") || kindHint == "video" {
            return (.link, "Video")
        }
        if host.contains("twitter.") || host == "x.com" || host.hasSuffix(".x.com") || host.contains("reddit.")
            || host.contains("news.ycombinator.") || host.contains("mastodon") || host.contains("bsky.")
            || host.contains("threads.net") || host.contains("linkedin.") || kindHint == "social" {
            return (.conversation, "Discussion")
        }
        if host.contains("notion.") || host.contains("docs.google.") || host.contains("figma.") || kindHint == "doc" {
            return (.document, "Document")
        }
        if kindHint == "article" {
            return (.article, "Article")
        }
        return (.link, "Web page")
    }

    public static func host(of url: String) -> String {
        guard let parsed = URL(string: url), let host = parsed.host else {
            return url
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
