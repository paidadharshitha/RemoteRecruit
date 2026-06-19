// PDFTextExtractor.swift
// RemoteRecruit

import Foundation
import PDFKit
import Compression

// MARK: - PDF / DOCX Text Extractor

/// Extracts raw text content from PDF and DOCX files.
/// Used in the resume processing pipeline.
public enum PDFTextExtractor {

    // MARK: - PDF Extraction

    /// Extracts all text from a PDF document.
    /// - Parameter data: Raw PDF file data.
    /// - Returns: A concatenated string of all page text, or an empty string if the PDF is invalid.
    public static func extractText(from data: Data) -> String {
        guard let document = PDFDocument(data: data) else {
            return ""
        }

        var fullText = ""
        let pageCount = document.pageCount

        for index in 0..<pageCount {
            guard let page = document.page(at: index),
                  let pageText = page.string else { continue }
            fullText += pageText + "\n"
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - DOCX Extraction

    /// Extracts text from a DOCX file by unzipping and parsing the internal XML.
    /// - Parameter data: Raw DOCX file data (ZIP archive).
    /// - Returns: Concatenated text content, or an empty string on failure.
    public static func extractTextFromDOCX(from data: Data) -> String {
        // 1. Find the End-of-Central-Directory record
        guard let eocdOffset = ZipParser.findEOCD(in: data) else {
            return ""
        }

        // 2. Read the central-directory offset stored in the EOCD
        let cdOffset = ZipParser.readUInt32(from: data, at: eocdOffset + 16)

        // 3. Parse central directory to find word/document.xml
        guard let documentEntry = ZipParser.findEntry(
            named: "word/document.xml",
            centralDirectoryOffset: Int(cdOffset),
            in: data
        ) else {
            return ""
        }

        // 4. Extract and decompress the entry
        guard let xmlData = ZipParser.extract(entry: documentEntry, from: data) else {
            return ""
        }

        // 5. Parse XML for w:t tag text content
        guard let xmlString = String(data: xmlData, encoding: .utf8) else {
            return ""
        }

        return parseWordML(xmlString)
    }

    /// Determines if the given file extension is a supported document type.
    public static func isSupportedFile(_ fileName: String) -> Bool {
        let ext = fileName.lowercased()
            .split(separator: ".", omittingEmptySubsequences: true)
            .last
            .map(String.init) ?? ""
        return ext == "pdf" || ext == "docx" || ext == "txt"
    }

    // MARK: - Private XML Parsing

    /// Extracts text content from w:t tags in Word XML.
    private static func parseWordML(_ xml: String) -> String {
        var result = [String]()
        let openMarker = "<w:t"
        let closeMarker = "</w:t>"
        var searchStart = xml.startIndex

        while let openRange = xml.range(of: openMarker, range: searchStart..<xml.endIndex) {
            // Advance past "<w:t" then find the closing '>'
            guard let tagClose = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) else {
                break
            }

            // Find the matching closing tag
            guard let endTag = xml.range(of: closeMarker, range: tagClose.upperBound..<xml.endIndex) else {
                break
            }

            let text = String(xml[tagClose.upperBound..<endTag.lowerBound])
            if !text.isEmpty {
                result.append(text)
            }
            searchStart = endTag.upperBound
        }

        return result.joined(separator: " ")
    }
}

// MARK: - ZIP Parser (DOCX is a ZIP archive)

/// Minimal ZIP parser that reads central-directory entries and decompresses
/// DEFLATE and STORED file data. Sufficient for DOCX parsing.
private enum ZipParser {

    // MARK: - Entry Model

    struct ZipEntry {
        let fileName: String
        let dataOffset: Int
        let compressedSize: Int
        let compressionMethod: UInt16
    }

    // MARK: - Public API

    /// Searches backward from the end of data for the EOCD signature.
    static func findEOCD(in data: Data) -> Int? {
        let sig0: UInt8 = 0x50
        let sig1: UInt8 = 0x4B
        let sig2: UInt8 = 0x05
        let sig3: UInt8 = 0x06
        guard data.count >= 22 else { return nil }

        let maxSearch = min(data.count - 22, 65_535)
        for i in stride(from: data.count - 22, through: data.count - 22 - maxSearch, by: -1) {
            guard i >= 0, i + 4 <= data.count else { continue }
            if data[i] == sig0,
               data[i + 1] == sig1,
               data[i + 2] == sig2,
               data[i + 3] == sig3 {
                return i
            }
        }
        return nil
    }

    /// Walks the central directory and returns the first entry matching targetName.
    static func findEntry(
        named targetName: String,
        centralDirectoryOffset cdOffset: Int,
        in data: Data
    ) -> ZipEntry? {
        guard cdOffset >= 0, cdOffset + 46 <= data.count else { return nil }

        var cursor = cdOffset
        while cursor + 46 <= data.count {
            let sig = readUInt32(from: data, at: cursor)
            guard sig == 0x02014B50 else { break }

            let compMethod  = readUInt16(from: data, at: cursor + 10)
            let compSize    = Int(readUInt32(from: data, at: cursor + 20))
            let nameLen     = Int(readUInt16(from: data, at: cursor + 28))
            let extraLen    = Int(readUInt16(from: data, at: cursor + 30))
            let commentLen  = Int(readUInt16(from: data, at: cursor + 32))
            let localOffset = Int(readUInt32(from: data, at: cursor + 42))

            let nameStart = cursor + 46
            guard nameStart + nameLen <= data.count else { break }

            let fileName = String(data: data[nameStart..<nameStart + nameLen], encoding: .utf8) ?? ""

            if fileName == targetName {
                guard localOffset + 30 <= data.count else { return nil }
                let localNameLen  = Int(readUInt16(from: data, at: localOffset + 26))
                let localExtraLen = Int(readUInt16(from: data, at: localOffset + 28))
                let dataOffset    = localOffset + 30 + localNameLen + localExtraLen

                return ZipEntry(
                    fileName: fileName,
                    dataOffset: dataOffset,
                    compressedSize: compSize,
                    compressionMethod: compMethod
                )
            }

            cursor += 46 + nameLen + extraLen + commentLen
        }
        return nil
    }

    /// Decompresses the raw bytes of a ZIP entry.
    static func extract(entry: ZipEntry, from data: Data) -> Data? {
        let end = entry.dataOffset + entry.compressedSize
        guard entry.dataOffset >= 0, end <= data.count else { return nil }
        let slice = data[entry.dataOffset..<end]

        switch entry.compressionMethod {
        case 0:
            return Data(slice)
        case 8:
            return inflateDeflate(Data(slice))
        default:
            return nil
        }
    }

    // MARK: - Integer Readers

    static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        }
    }

    static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
    }

    // MARK: - DEFLATE Decompression

    /// Decompresses raw DEFLATE data using Apple Compression framework.
    static func inflateDeflate(_ compressed: Data) -> Data? {
        let estimatedSize = max(compressed.count * 10, 65_536)
        var outputBuffer = [UInt8](repeating: 0, count: estimatedSize)

        let decodedSize = compressed.withUnsafeBytes { compressedPtr in
            outputBuffer.withUnsafeMutableBufferPointer { outputPtr in
                guard let srcPtr = compressedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dstPtr = outputPtr.baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    dstPtr,
                    estimatedSize,
                    srcPtr,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decodedSize > 0 else { return nil }
        return Data(outputBuffer.prefix(decodedSize))
    }
}
