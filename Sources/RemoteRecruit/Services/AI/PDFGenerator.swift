// PDFGenerator.swift
// RemoteRecruit

import Foundation
import PDFKit
import CoreText
import CoreGraphics

// MARK: - PDF Generator

public enum PDFGenerator {

    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 54
    private static let contentWidth: CGFloat = pageWidth - (margin * 2)

    private static let fontFamily = "Helvetica Neue"

    private static func makeFont(size: CGFloat, bold: Bool = false) -> CTFont {
        let name = bold ? "\(fontFamily)-Bold" : fontFamily
        return CTFontCreateWithName(name as CFString, size, nil)
    }

    public static func generatePDF(from resume: OptimizedResume) -> Data? {
        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "RemoteRecruit AI",
            kCGPDFContextAuthor: resume.name,
            kCGPDFContextTitle: "\(resume.name) - Optimized Resume"
        ]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let mutableData = NSMutableData()

        guard let consumer = CGDataConsumer(data: mutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, pdfMetaData as CFDictionary) else {
            return nil
        }

        var textY = pageHeight - margin
        var mutablePageRect = pageRect
        context.beginPage(mediaBox: &mutablePageRect)
        textY = drawContent(context: context, resume: resume, y: textY, pageRect: &mutablePageRect)
        context.endPage()
        context.closePDF()

        return mutableData as Data
    }

    // MARK: - Content Layout

    private static func drawContent(context: CGContext, resume: OptimizedResume, y: CGFloat, pageRect: inout CGRect) -> CGFloat {
        var currentY = y

        // Name header
        currentY = drawText(context: context, text: resume.name, font: makeFont(size: 24, bold: true), color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), y: currentY)
        currentY -= 4

        // Accent line under name
        currentY = drawLine(context: context, from: CGPoint(x: margin, y: currentY), to: CGPoint(x: margin + contentWidth, y: currentY), color: accentCGColor, width: 2)
        currentY -= 20

        // Professional Summary
        if !resume.summary.isEmpty {
            currentY = ensureSpace(y: currentY, needed: 80, context: context, pageRect: &pageRect)
            currentY = drawSectionTitle(context: context, title: "PROFESSIONAL SUMMARY", y: currentY)
            currentY -= 6
            currentY = drawWrappedText(context: context, text: resume.summary, font: makeFont(size: 11), color: CGColor(gray: 0.33, alpha: 1.0), y: currentY)
            currentY -= 8
        }

        // Skills
        if !resume.skills.isEmpty {
            currentY = ensureSpace(y: currentY, needed: 60, context: context, pageRect: &pageRect)
            currentY = drawSectionTitle(context: context, title: "SKILLS", y: currentY)
            currentY -= 6
            let skillsText = resume.skills.joined(separator: "  |  ")
            currentY = drawWrappedText(context: context, text: skillsText, font: makeFont(size: 11), color: CGColor(gray: 0.33, alpha: 1.0), y: currentY)
            currentY -= 8
        }

        // Experience
        if !resume.experience.isEmpty {
            currentY = ensureSpace(y: currentY, needed: 60, context: context, pageRect: &pageRect)
            currentY = drawSectionTitle(context: context, title: "EXPERIENCE", y: currentY)
            currentY -= 6
            for exp in resume.experience {
                currentY = ensureSpace(y: currentY, needed: 100, context: context, pageRect: &pageRect)
                currentY = drawExperienceEntry(context: context, entry: exp, y: currentY)
                currentY -= 8
            }
        }

        // Projects
        if !resume.projects.isEmpty {
            currentY = ensureSpace(y: currentY, needed: 60, context: context, pageRect: &pageRect)
            currentY = drawSectionTitle(context: context, title: "PROJECTS", y: currentY)
            currentY -= 6
            for project in resume.projects {
                currentY = ensureSpace(y: currentY, needed: 100, context: context, pageRect: &pageRect)
                currentY = drawProjectEntry(context: context, entry: project, y: currentY)
                currentY -= 8
            }
        }

        return currentY
    }

    // MARK: - Section Title

    private static func drawSectionTitle(context: CGContext, title: String, y: CGFloat) -> CGFloat {
        var currentY = drawText(context: context, text: title, font: makeFont(size: 14, bold: true), color: accentCGColor, y: y)
        let lineY = currentY - 4
        _ = drawLine(context: context, from: CGPoint(x: margin, y: lineY), to: CGPoint(x: margin + contentWidth, y: lineY), color: accentCGColor, width: 0.5)
        currentY -= 12
        return currentY
    }

    // MARK: - Experience Entry

    private static func drawExperienceEntry(context: CGContext, entry: OptimizedExperienceSection, y: CGFloat) -> CGFloat {
        var currentY = y
        currentY = drawText(context: context, text: entry.role, font: makeFont(size: 12, bold: true), color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), y: currentY)
        currentY -= 2
        let detail = "\(entry.company)  |  \(entry.duration)"
        currentY = drawText(context: context, text: detail, font: makeFont(size: 10), color: CGColor(gray: 0.33, alpha: 1.0), y: currentY)
        currentY -= 4
        for bullet in entry.bullets {
            let bulletText = "  \u{2022}  \(bullet)"
            currentY = drawWrappedText(context: context, text: bulletText, font: makeFont(size: 11), color: CGColor(gray: 0.2, alpha: 1.0), y: currentY)
            currentY -= 2
        }
        return currentY
    }

    // MARK: - Project Entry

    private static func drawProjectEntry(context: CGContext, entry: OptimizedProjectSection, y: CGFloat) -> CGFloat {
        var currentY = y
        currentY = drawText(context: context, text: entry.title, font: makeFont(size: 12, bold: true), color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), y: currentY)
        let detail = "\(entry.duration)  |  \(entry.technologies.joined(separator: ", "))"
        currentY = drawText(context: context, text: detail, font: makeFont(size: 10), color: CGColor(gray: 0.33, alpha: 1.0), y: currentY)
        currentY -= 4
        for bullet in entry.bullets {
            let bulletText = "  \u{2022}  \(bullet)"
            currentY = drawWrappedText(context: context, text: bulletText, font: makeFont(size: 11), color: CGColor(gray: 0.2, alpha: 1.0), y: currentY)
            currentY -= 2
        }
        return currentY
    }

    // MARK: - Single-line Text

    private static func drawText(context: CGContext, text: String, font: CTFont, color: CGColor, y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let lineHeight = ascent + descent
        context.saveGState()
        context.setFillColor(color)
        context.textPosition = CGPoint(x: margin, y: y - descent)
        CTLineDraw(line, context)
        context.restoreGState()
        return y - lineHeight
    }

    // MARK: - Wrapped (Multi-line) Text

    private static func drawWrappedText(context: CGContext, text: String, font: CTFont, color: CGColor, y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let maxWidth = contentWidth
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, CGSize(width: maxWidth, height: .greatestFiniteMagnitude), nil)
        let frameHeight = ceil(suggestedSize.height)
        let framePath = CGPath(rect: CGRect(x: 0, y: 0, width: maxWidth, height: frameHeight), transform: nil)
        context.saveGState()
        context.translateBy(x: margin, y: y)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -frameHeight)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(), framePath, nil)
        context.setFillColor(color)
        CTFrameDraw(frame, context)
        context.restoreGState()
        return y - frameHeight
    }

    // MARK: - Horizontal Line

    private static func drawLine(context: CGContext, from start: CGPoint, to end: CGPoint, color: CGColor, width: CGFloat) -> CGFloat {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        return start.y - 4
    }

    // MARK: - Page Break

    private static func ensureSpace(y: CGFloat, needed: CGFloat, context: CGContext, pageRect: inout CGRect) -> CGFloat {
        if y - needed < margin {
            context.endPage()
            context.beginPage(mediaBox: &pageRect)
            return pageHeight - margin
        }
        return y
    }

    // MARK: - Accent Color

    private static var accentCGColor: CGColor {
        CGColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
    }
}
