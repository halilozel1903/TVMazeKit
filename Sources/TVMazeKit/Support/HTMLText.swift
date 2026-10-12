import Foundation

/// Turns TVMaze's HTML summaries into plain text.
///
/// Summaries are short HTML fragments such as `<p><b>Show</b> is a drama &amp; more.</p>`. This
/// removes the tags, keeps paragraphs and line breaks as newlines, decodes character references
/// and collapses runs of whitespace. It runs anywhere (no `NSAttributedString`, no main thread).
public enum HTMLText {
    /// Plain text for an HTML fragment. Paragraphs are separated by a blank line.
    public static func plainText(from html: String) -> String {
        var output = ""
        output.reserveCapacity(html.count)
        var index = html.startIndex

        while index < html.endIndex {
            let character = html[index]
            if character == "<" {
                guard let close = html[index...].firstIndex(of: ">") else {
                    // A lone "<" is text.
                    output.append(character)
                    index = html.index(after: index)
                    continue
                }
                let tag = html[html.index(after: index)..<close]
                output.append(contentsOf: separator(forTag: tag))
                index = html.index(after: close)
            } else if character == "&" {
                let (decoded, next) = decodeEntity(in: html, at: index)
                output.append(contentsOf: decoded)
                index = next
            } else {
                output.append(character)
                index = html.index(after: index)
            }
        }
        return normalizeWhitespace(output)
    }

    // MARK: - Tags

    /// Block-level tags become line breaks; inline tags disappear.
    private static func separator(forTag tag: Substring) -> String {
        let name = tag
            .trimmingCharacters(in: .whitespaces)
            .drop(while: { $0 == "/" })
            .prefix(while: { $0.isLetter || $0.isNumber })
            .lowercased()
        switch name {
        case "br":
            return "\n"
        case "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "ul", "ol":
            return "\n\n"
        case "li":
            return tag.hasPrefix("/") ? "\n" : "\n• "
        default:
            return ""
        }
    }

    // MARK: - Character references

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "mdash": "—", "ndash": "–", "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "laquo": "«", "raquo": "»", "copy": "©", "reg": "®", "trade": "™", "eacute": "é", "egrave": "è",
        "aacute": "á", "agrave": "à", "iacute": "í", "oacute": "ó", "uacute": "ú", "ntilde": "ñ", "ccedil": "ç",
        "ouml": "ö", "uuml": "ü", "auml": "ä", "szlig": "ß", "bull": "•", "middot": "·", "deg": "°",
    ]

    /// Decodes `&name;`, `&#123;` or `&#x1F;` at `start`. Anything else is kept as a literal "&".
    private static func decodeEntity(in html: String, at start: String.Index) -> (String, String.Index) {
        let afterAmpersand = html.index(after: start)
        // References are short; don't scan the whole string for a ";".
        let limit = html.index(afterAmpersand, offsetBy: 10, limitedBy: html.endIndex) ?? html.endIndex
        guard let semicolon = html[afterAmpersand..<limit].firstIndex(of: ";") else {
            return ("&", afterAmpersand)
        }
        let body = html[afterAmpersand..<semicolon]
        let next = html.index(after: semicolon)
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let value: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits, radix: 10)
            }
            if let value, let scalar = Unicode.Scalar(value) {
                return (String(Swift.Character(scalar)), next)
            }
            return ("&", afterAmpersand)
        }
        if let named = namedEntities[String(body)] {
            return (named, next)
        }
        return ("&", afterAmpersand)
    }

    // MARK: - Whitespace

    /// Collapses spaces and tabs, trims every line and keeps at most one blank line between
    /// paragraphs.
    private static func normalizeWhitespace(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let words = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" || $0 == "\u{00A0}" })
            lines.append(words.joined(separator: " "))
        }
        var result: [String] = []
        for line in lines {
            if line.isEmpty {
                if let last = result.last, !last.isEmpty {
                    result.append("")
                }
            } else {
                result.append(line)
            }
        }
        while result.last?.isEmpty == true {
            result.removeLast()
        }
        return result.joined(separator: "\n")
    }
}

extension String {
    /// This string with HTML tags removed and character references decoded. See ``HTMLText``.
    public var strippingHTML: String { HTMLText.plainText(from: self) }
}
