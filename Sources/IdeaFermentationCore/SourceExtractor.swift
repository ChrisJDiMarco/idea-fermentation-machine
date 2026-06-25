import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision

public enum SourceExtractor {
    public static func extract(url: URL) throws -> SourceItem {
        let storedURL = try copyAttachment(url)
        return try extractStored(url: storedURL, originalURL: url)
    }

    private static func extractStored(url: URL, originalURL: URL) throws -> SourceItem {
        let ext = url.pathExtension.lowercased()
        let title = url.deletingPathExtension().lastPathComponent
        let metadata = metadata(for: url, originalURL: originalURL, ext: ext)
        switch ext {
        case "txt", "md", "markdown", "csv", "json":
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return SourceItem(type: .file, title: title, body: body, filePath: url.path, extractionStatus: status(for: body), metadata: metadata)
        case "pdf":
            let body = PDFDocument(url: url)?.string ?? ""
            return SourceItem(type: .document, title: title, body: body, filePath: url.path, extractionStatus: status(for: body), metadata: metadata)
        case "png", "jpg", "jpeg", "heic", "webp", "tif", "tiff", "gif", "bmp":
            return imageSource(url: url, title: title, metadata: metadata)
        default:
            if UTType(filenameExtension: ext)?.conforms(to: .image) == true {
                return imageSource(url: url, title: title, metadata: metadata)
            }
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return SourceItem(type: .file, title: title, body: body, filePath: url.path, extractionStatus: status(for: body), metadata: metadata)
        }
    }

    public static func readableURL(_ url: URL) async throws -> SourceItem {
        let (data, _) = try await URLSession.shared.data(from: url)
        let raw = String(data: data, encoding: .utf8) ?? ""
        let text = raw
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return SourceItem(type: .link, title: url.host ?? url.absoluteString, body: text, url: url.absoluteString, extractionStatus: .captured, metadata: SourceMetadata(contentType: "public.url"))
    }

    private static func copyAttachment(_ url: URL) throws -> URL {
        let folder = try IdeaStore.applicationSupportURL()
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    private static func metadata(for url: URL, originalURL: URL, ext: String) -> SourceMetadata {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value
        return SourceMetadata(
            originalFileName: originalURL.lastPathComponent,
            fileSize: size,
            contentType: UTType(filenameExtension: ext)?.identifier
        )
    }

    private static func imageSource(url: URL, title: String, metadata: SourceMetadata) -> SourceItem {
        let body = (try? recognizeText(in: url)) ?? ""
        return SourceItem(type: .screenshot, title: title, body: body, filePath: url.path, extractionStatus: status(for: body), metadata: metadata)
    }

    private static func status(for body: String) -> SourceExtractionStatus {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed : .captured
    }

    private static func recognizeText(in url: URL) throws -> String {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
