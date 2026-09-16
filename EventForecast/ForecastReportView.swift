import PDFKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum ForecastReportBuilder {
    @MainActor
    static func make(
        for model: ForecastModel,
        eventName: String,
        includeItemization: Bool,
        includeThresholds: Bool = false
    ) -> String {
        let resultLabel: String
        if model.profit > 0 {
            resultLabel = "Projected profit"
        } else if model.profit < 0 {
            resultLabel = "Projected loss"
        } else {
            resultLabel = "Projected result"
        }

        let breakEvenAttendance = model.breakEvenTickets.map { "\($0) tickets" } ?? "Not reachable"
        let breakEvenPrice = model.breakEvenTicketPrice.map { ceil($0).formatted(ForecastTheme.currencyFormat) } ?? "Set attendance"
        let targetPrice = model.targetTicketPrice.map { ceil($0).formatted(ForecastTheme.currencyFormat) } ?? "Set attendance"
        let targetAttendance = model.profitTargetTickets.map { "\($0) tickets" } ?? "Not reachable"
        let targetStatus: String
        if model.profitTarget <= 0 {
            targetStatus = "Not set"
        } else if model.profitTargetDifference >= 0 {
            targetStatus = "Exceeded by \(model.profitTargetDifference.formatted(ForecastTheme.currencyFormat))"
        } else {
            targetStatus = "\(abs(model.profitTargetDifference).formatted(ForecastTheme.currencyFormat)) needed"
        }

        let trimmedEventName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayEventName = trimmedEventName.isEmpty ? "Untitled Event" : trimmedEventName
        var lines = [
            displayEventName,
            "EVENT BUDGET",
            "Generated: \(Date.now.formatted(date: .long, time: .shortened))",
            "",
            "TICKET PRICING",
            "Tickets available: \(Int(model.capacity).formatted())",
            "Expected attendance: \(model.ticketsSold.formatted())",
            "Current ticket price: \(model.ticketPrice.formatted(ForecastTheme.currencyFormat))",
            "Ticket revenue: \(model.ticketRevenue.formatted(ForecastTheme.currencyFormat))",
            "",
            "BUDGET",
            "Revenue: \(model.additionalRevenue.formatted(ForecastTheme.currencyFormat))",
            "Total revenue: \(model.totalRevenue.formatted(ForecastTheme.currencyFormat))",
            "Total expenses: \(model.totalExpenses.formatted(ForecastTheme.currencyFormat))",
            "\(resultLabel): \(abs(model.profit).formatted(ForecastTheme.currencyFormat))",
            "Profit margin: \(model.profitMargin.formatted(.percent.precision(.fractionLength(1))))"
        ]

        if includeThresholds {
            lines.append(contentsOf: [
                "",
                "THRESHOLDS",
                "Break-even ticket price: \(breakEvenPrice)",
                "Target ticket price: \(model.profitTarget > 0 ? targetPrice : "No target set")",
                "Break-even attendance: \(breakEvenAttendance)",
                "Profit target: \(model.profitTarget > 0 ? model.profitTarget.formatted(ForecastTheme.currencyFormat) : "Not set")",
                "Revenue required for target: \(model.profitTarget > 0 ? model.requiredRevenueForProfitTarget.formatted(ForecastTheme.currencyFormat) : "Not set")",
                "Attendance required for target: \(model.profitTarget > 0 ? targetAttendance : "Not set")",
                "Profit target status: \(targetStatus)"
            ])
        }

        if includeItemization {
            lines.append(contentsOf: ["", "ITEMIZED REVENUE"])
            if model.revenueItems.isEmpty {
                lines.append("No itemized revenue")
            } else {
                lines.append(contentsOf: model.revenueItems.map {
                    "\($0.name): \($0.amount.formatted(ForecastTheme.currencyFormat))"
                })
            }
            lines.append("Itemized revenue total: \(model.revenueItemizedTotal.formatted(ForecastTheme.currencyFormat))")
            lines.append(reconciliationLine(label: "Revenue", difference: model.revenueItemizedDifference))

            lines.append(contentsOf: ["", "ITEMIZED EXPENSES"])
            if model.expenseItems.isEmpty {
                lines.append("No itemized expenses")
            } else {
                lines.append(contentsOf: model.expenseItems.map {
                    "\($0.name): \($0.amount.formatted(ForecastTheme.currencyFormat))"
                })
            }
            lines.append("Itemized expense total: \(model.expenseItemizedTotal.formatted(ForecastTheme.currencyFormat))")
            lines.append(reconciliationLine(label: "Expense", difference: model.expenseItemizedDifference))
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    static func makeAttributed(
        for model: ForecastModel,
        eventName: String,
        includeItemization: Bool,
        includeThresholds: Bool = false
    ) -> NSAttributedString {
        let plain = make(
            for: model,
            eventName: eventName,
            includeItemization: includeItemization,
            includeThresholds: includeThresholds
        )
        let result = NSMutableAttributedString(
            string: plain,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1)
            ]
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 1
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))

        let neutralText = UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1)
        let secondaryText = UIColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
        let sectionTitles: Set<String> = [
            "TICKET PRICING", "BUDGET", "THRESHOLDS", "ITEMIZED REVENUE", "ITEMIZED EXPENSES"
        ]
        let nsString = plain as NSString
        var location = 0
        while location < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
            let line = nsString.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if lineRange.location == 0 {
                result.addAttributes([
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: neutralText
                ], range: lineRange)
            } else if line == "EVENT BUDGET" {
                result.addAttributes([
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: secondaryText
                ], range: lineRange)
            } else if sectionTitles.contains(line) {
                result.addAttributes([
                    .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: neutralText
                ], range: lineRange)
            } else if let colon = line.firstIndex(of: ":") {
                let labelLength = line.distance(from: line.startIndex, to: colon) + 1
                let valueLocation = lineRange.location + labelLength
                let valueLength = max(lineRange.length - labelLength, 0)
                result.addAttributes(
                    [
                        .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: neutralText
                    ],
                    range: NSRange(location: lineRange.location, length: labelLength)
                )
                if valueLength > 0, let color = totalColor(for: line) {
                    result.addAttributes(
                        [
                            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                            .foregroundColor: color
                        ],
                        range: NSRange(location: valueLocation, length: valueLength)
                    )
                }
            }
            location = NSMaxRange(lineRange)
        }
        return result
    }

    private static func totalColor(for line: String) -> UIColor? {
        let lower = line.lowercased()
        if lower.hasPrefix("total expenses:") ||
            lower.hasPrefix("itemized expense total:") ||
            lower.hasPrefix("projected loss:") {
            return UIColor(red: 0.82, green: 0.03, blue: 0.13, alpha: 1)
        }
        if lower.hasPrefix("profit target:") || lower.hasPrefix("revenue required for target:") {
            return UIColor(red: 0.55, green: 0.17, blue: 0.84, alpha: 1)
        }
        if lower.hasPrefix("ticket revenue:") {
            return UIColor(red: 0.90, green: 0.43, blue: 0.00, alpha: 1)
        }
        if lower.hasPrefix("total revenue:") ||
            lower.hasPrefix("itemized revenue total:") ||
            lower.hasPrefix("projected profit:") {
            return UIColor(red: 0.00, green: 0.52, blue: 0.22, alpha: 1)
        }
        return nil
    }

    private static func reconciliationLine(label: String, difference: Double) -> String {
        if difference > 0.005 {
            return "\(label) amount not itemized: \(difference.formatted(ForecastTheme.currencyFormat))"
        }
        if difference < -0.005 {
            return "\(label) itemization over total by: \(abs(difference).formatted(ForecastTheme.currencyFormat))"
        }
        return "\(label) itemization: Balanced"
    }
}

enum ForecastPDFBuilder {
    private static let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 44
    private static let revenuePDFColors = [
        UIColor(red: 0.00, green: 0.55, blue: 0.21, alpha: 1),
        UIColor(red: 0.13, green: 0.65, blue: 0.18, alpha: 1),
        UIColor(red: 0.41, green: 0.69, blue: 0.00, alpha: 1),
        UIColor(red: 0.00, green: 0.65, blue: 0.43, alpha: 1),
        UIColor(red: 0.20, green: 0.52, blue: 0.09, alpha: 1),
        UIColor(red: 0.00, green: 0.48, blue: 0.36, alpha: 1)
    ]
    private static let expensePDFColors = [
        UIColor(red: 0.85, green: 0.02, blue: 0.13, alpha: 1),
        UIColor(red: 0.69, green: 0.02, blue: 0.19, alpha: 1),
        UIColor(red: 0.94, green: 0.19, blue: 0.10, alpha: 1),
        UIColor(red: 0.76, green: 0.00, blue: 0.33, alpha: 1),
        UIColor(red: 0.82, green: 0.18, blue: 0.00, alpha: 1),
        UIColor(red: 0.62, green: 0.00, blue: 0.08, alpha: 1)
    ]

    private static func itemizedPDFSegments(
        items: [MoneyItem],
        total: Double,
        colors: [UIColor]
    ) -> [(Double, UIColor)] {
        let valid = items.enumerated().filter { $0.element.amount.isFinite && $0.element.amount > 0 }
        let itemizedTotal = valid.reduce(0) { $0 + $1.element.amount }
        let scale = itemizedTotal > total && itemizedTotal > 0 ? max(total, 0) / itemizedTotal : 1
        var result = valid.map { index, item in
            (item.amount * scale, colors[index % colors.count])
        }
        let unallocated = max(total - min(itemizedTotal, total), 0)
        if unallocated > 0.005 || result.isEmpty {
            result.append((result.isEmpty ? max(total, 0) : unallocated, colors[min(1, colors.count - 1)]))
        }
        return result.filter { $0.0 > 0 }
    }

    @MainActor
    static func makeURL(
        for model: ForecastModel,
        eventName: String,
        includeItemization: Bool,
        includeThresholds: Bool = false
    ) throws -> URL {
        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String: "\(eventName) Event Budget",
            kCGPDFContextCreator as String: "Event Budget"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: rendererFormat)

        let data = renderer.pdfData { rendererContext in
            var pageNumber = 0

            func drawFooter() {
                let footer = "Event Budget  •  \(Date.now.formatted(date: .abbreviated, time: .omitted))  •  Page \(pageNumber)"
                drawText(
                    footer,
                    in: CGRect(x: margin, y: 760, width: pageBounds.width - margin * 2, height: 16),
                    font: .systemFont(ofSize: 8, weight: .medium),
                    color: UIColor(white: 0.42, alpha: 1),
                    alignment: .center
                )
            }

            func beginPage(sectionTitle: String? = nil) -> CGFloat {
                rendererContext.beginPage()
                pageNumber += 1

                UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1).setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageBounds.width, height: 74)).fill()

                drawText(
                    "EVENT BUDGET",
                    in: CGRect(x: margin, y: 24, width: 210, height: 20),
                    font: .systemFont(ofSize: 11, weight: .bold),
                    color: .white
                )
                drawText(
                    eventName,
                    in: CGRect(x: 250, y: 20, width: pageBounds.width - margin - 250, height: 26),
                    font: .systemFont(ofSize: 16, weight: .semibold),
                    color: .white,
                    alignment: .right
                )

                if let sectionTitle {
                    drawText(
                        sectionTitle,
                        in: CGRect(x: margin, y: 98, width: pageBounds.width - margin * 2, height: 28),
                        font: .systemFont(ofSize: 22, weight: .bold),
                        color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
                    )
                    return 142
                }
                return 96
            }

            var y = beginPage()
            y = drawHeadlineMetrics(model: model, includeThresholds: includeThresholds, at: y)
            y = drawBudgetVisualization(model: model, includeItemization: includeItemization, at: y)
            if includeThresholds {
                _ = drawThresholds(model: model, at: y)
            }
            drawFooter()

            if includeItemization {
                y = beginPage(sectionTitle: "Itemized budget")
                y = drawReconciliation(
                    title: "Revenue",
                    total: model.additionalRevenue,
                    itemized: model.revenueItemizedTotal,
                    difference: model.revenueItemizedDifference,
                    color: UIColor(red: 0.04, green: 0.55, blue: 0.25, alpha: 1),
                    at: y
                )
                y += 12

                y = drawItemTable(
                    title: "Revenue items",
                    items: model.revenueItems,
                    colors: revenuePDFColors,
                    startY: y,
                    newPage: {
                        drawFooter()
                        return beginPage(sectionTitle: "Itemized revenue - continued")
                    }
                )
                y += 18

                if y > 620 {
                    drawFooter()
                    y = beginPage(sectionTitle: "Itemized expenses")
                }

                y = drawReconciliation(
                    title: "Expenses",
                    total: model.expenseBudget,
                    itemized: model.expenseItemizedTotal,
                    difference: model.expenseItemizedDifference,
                    color: UIColor(red: 0.76, green: 0.06, blue: 0.13, alpha: 1),
                    at: y
                )
                y += 12

                _ = drawItemTable(
                    title: "Expense items",
                    items: model.expenseItems,
                    colors: expensePDFColors,
                    startY: y,
                    newPage: {
                        drawFooter()
                        return beginPage(sectionTitle: "Itemized expenses - continued")
                    }
                )
                drawFooter()
            }
        }

        let safeName = eventName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let filename = "\(safeName.isEmpty ? "Event" : safeName)-Budget.pdf"
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EventBudget-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let url = exportDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    private static func drawHeadlineMetrics(model: ForecastModel, includeThresholds: Bool, at y: CGFloat) -> CGFloat {
        drawText(
            "PROJECTED \(model.profit >= 0 ? "PROFIT" : "LOSS")",
            in: CGRect(x: margin, y: y, width: 220, height: 18),
            font: .systemFont(ofSize: 9, weight: .bold),
            color: UIColor(white: 0.38, alpha: 1)
        )
        drawText(
            ForecastTheme.compactCurrency(abs(model.profit)),
            in: CGRect(x: margin, y: y + 18, width: 220, height: 44),
            font: .systemFont(ofSize: 32, weight: .bold),
            color: model.profit >= 0
                ? UIColor(red: 0.03, green: 0.50, blue: 0.24, alpha: 1)
                : UIColor(red: 0.75, green: 0.05, blue: 0.12, alpha: 1)
        )
        drawText(
            "Margin \(model.profitMargin.formatted(.percent.precision(.fractionLength(1))))",
            in: CGRect(x: margin, y: y + 61, width: 220, height: 18),
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: UIColor(white: 0.32, alpha: 1)
        )

        drawText(
            "TICKET PRICE",
            in: CGRect(x: 300, y: y, width: 120, height: 18),
            font: .systemFont(ofSize: 9, weight: .bold),
            color: UIColor(white: 0.38, alpha: 1)
        )
        drawText(
            model.ticketPrice.formatted(ForecastTheme.currencyFormat),
            in: CGRect(x: 300, y: y + 18, width: 120, height: 34),
            font: .systemFont(ofSize: 24, weight: .bold),
            color: UIColor(red: 0.00, green: 0.43, blue: 0.64, alpha: 1)
        )

        drawText(
            includeThresholds ? "TARGET PRICE" : "TOTAL REVENUE",
            in: CGRect(x: 438, y: y, width: 130, height: 18),
            font: .systemFont(ofSize: 9, weight: .bold),
            color: UIColor(white: 0.38, alpha: 1)
        )
        drawText(
            includeThresholds
                ? (model.recommendedTicketPrice.map(ForecastTheme.compactCurrency) ?? "-")
                : ForecastTheme.compactCurrency(model.totalRevenue),
            in: CGRect(x: 438, y: y + 18, width: 130, height: 34),
            font: .systemFont(ofSize: 24, weight: .bold),
            color: includeThresholds
                ? UIColor(red: 0.47, green: 0.21, blue: 0.76, alpha: 1)
                : UIColor(red: 0.04, green: 0.55, blue: 0.25, alpha: 1)
        )

        return y + 100
    }

    @MainActor
    private static func drawBudgetVisualization(model: ForecastModel, includeItemization: Bool, at y: CGFloat) -> CGFloat {
        drawText(
            "Mix and budget",
            in: CGRect(x: margin, y: y, width: 250, height: 24),
            font: .systemFont(ofSize: 16, weight: .bold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
        )

        let chartY = y + 34
        let center = CGPoint(x: 116, y: chartY + 62)
        let radius: CGFloat = 48
        var segments: [(Double, UIColor)] = [
            (model.ticketRevenue, UIColor(red: 0.90, green: 0.43, blue: 0.00, alpha: 1))
        ]
        if includeItemization {
            segments += itemizedPDFSegments(
                items: model.revenueItems,
                total: model.additionalRevenue,
                colors: revenuePDFColors
            )
            segments += itemizedPDFSegments(
                items: model.expenseItems,
                total: model.totalExpenses,
                colors: expensePDFColors
            )
        } else {
            segments += [
                (model.additionalRevenue, revenuePDFColors[1]),
                (model.totalExpenses, expensePDFColors[0])
            ]
        }
        let segmentTotal = max(segments.reduce(0) { $0 + $1.0 }, 1)

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setLineWidth(17)
        context?.setLineCap(.butt)
        var startAngle = -CGFloat.pi / 2
        for segment in segments where segment.0 > 0 {
            let endAngle = startAngle + CGFloat(segment.0 / segmentTotal) * .pi * 2
            context?.setStrokeColor(segment.1.cgColor)
            context?.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context?.strokePath()
            startAngle = endAngle
        }
        context?.restoreGState()

        drawText(
            ForecastTheme.compactCurrency(abs(model.profit)),
            in: CGRect(x: center.x - 42, y: center.y - 9, width: 84, height: 18),
            font: .systemFont(ofSize: 11, weight: .bold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1),
            alignment: .center
        )

        let barX: CGFloat = 210
        let barWidth: CGFloat = 350
        let bars: [(String, Double, UIColor)] = [
            ("Ticket revenue", model.ticketRevenue, UIColor(red: 0.90, green: 0.43, blue: 0.00, alpha: 1)),
            ("Revenue", model.additionalRevenue, UIColor(red: 0.28, green: 0.62, blue: 0.18, alpha: 1)),
            ("Expenses", model.totalExpenses, UIColor(red: 0.76, green: 0.06, blue: 0.13, alpha: 1))
        ]
        let baseline = max(bars.map(\.1).max() ?? 0, 1)

        for (index, bar) in bars.enumerated() {
            let rowY = chartY + CGFloat(index) * 29
            drawText(
                bar.0,
                in: CGRect(x: barX, y: rowY, width: 120, height: 14),
                font: .systemFont(ofSize: 8, weight: .semibold),
                color: UIColor(white: 0.32, alpha: 1)
            )
            UIColor(white: 0.91, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: barX + 122, y: rowY + 2, width: barWidth - 190, height: 10), cornerRadius: 5).fill()
            bar.2.setFill()
            UIBezierPath(
                roundedRect: CGRect(x: barX + 122, y: rowY + 2, width: max((barWidth - 190) * bar.1 / baseline, 2), height: 10),
                cornerRadius: 5
            ).fill()
            drawText(
                ForecastTheme.compactCurrency(bar.1),
                in: CGRect(x: barX + barWidth - 64, y: rowY - 1, width: 64, height: 15),
                font: .monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
                color: bar.2,
                alignment: .right
            )
        }

        let attendanceY = chartY + 122
        drawAttendanceVisualization(model: model, at: attendanceY)

        let pricingY = attendanceY + 76
        drawPricingVisualization(model: model, at: pricingY)

        return pricingY + 102
    }

    @MainActor
    private static func drawAttendanceVisualization(model: ForecastModel, at y: CGFloat) {
        let ticketOrange = UIColor(red: 0.90, green: 0.43, blue: 0.00, alpha: 1)
        let blue = UIColor(red: 0.00, green: 0.39, blue: 0.85, alpha: 1)
        let purple = UIColor(red: 0.55, green: 0.17, blue: 0.84, alpha: 1)
        let breakEven = Double(model.breakEvenTickets ?? 0)
        let target = Double(model.profitTargetTickets ?? 0)
        let upperBound = max(model.capacity, breakEven, target, 1)
        let track = CGRect(x: margin, y: y + 28, width: pageBounds.width - margin * 2, height: 12)

        drawText(
            "Attendance",
            in: CGRect(x: margin, y: y, width: 150, height: 18),
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
        )
        drawText(
            "Expected \(model.ticketsSold)  •  Capacity \(Int(model.capacity))",
            in: CGRect(x: 250, y: y, width: pageBounds.width - margin - 250, height: 18),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: UIColor(white: 0.34, alpha: 1),
            alignment: .right
        )

        UIColor(white: 0.91, alpha: 1).setFill()
        UIBezierPath(roundedRect: track, cornerRadius: 6).fill()
        ticketOrange.setFill()
        UIBezierPath(
            roundedRect: CGRect(
                x: track.minX,
                y: track.minY,
                width: max(track.width * CGFloat((model.attendance / upperBound).clamped(to: 0 ... 1)), 2),
                height: track.height
            ),
            cornerRadius: 6
        ).fill()
        drawRailMarker(value: breakEven, upperBound: upperBound, track: track, color: blue)
        if model.profitTarget > 0 {
            drawRailMarker(value: target, upperBound: upperBound, track: track, color: purple)
        }

        drawText(
            "Break even \(model.breakEvenTickets.map(String.init) ?? "-")",
            in: CGRect(x: margin, y: y + 46, width: 220, height: 14),
            font: .systemFont(ofSize: 8, weight: .semibold),
            color: blue
        )
        drawText(
            "Target \(model.profitTargetTickets.map(String.init) ?? "-")",
            in: CGRect(x: 350, y: y + 46, width: pageBounds.width - margin - 350, height: 14),
            font: .systemFont(ofSize: 8, weight: .semibold),
            color: purple,
            alignment: .right
        )
    }

    @MainActor
    private static func drawPricingVisualization(model: ForecastModel, at y: CGFloat) {
        let red = UIColor(red: 0.76, green: 0.06, blue: 0.13, alpha: 1)
        let green = UIColor(red: 0.03, green: 0.50, blue: 0.24, alpha: 1)
        let blue = UIColor(red: 0.00, green: 0.39, blue: 0.85, alpha: 1)
        let purple = UIColor(red: 0.55, green: 0.17, blue: 0.84, alpha: 1)
        let breakEven = ceil(model.breakEvenTicketPrice ?? 0)
        let target = ceil(model.targetTicketPrice ?? 0)
        let upperBound = max(model.ticketPrice, breakEven, target, 25) * 1.25
        let track = CGRect(x: margin, y: y + 28, width: pageBounds.width - margin * 2, height: 12)

        drawText(
            "Pricing",
            in: CGRect(x: margin, y: y, width: 150, height: 18),
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
        )
        drawText(
            "Current \(model.ticketPrice.formatted(ForecastTheme.currencyFormat))",
            in: CGRect(x: 330, y: y, width: pageBounds.width - margin - 330, height: 18),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: model.profit >= 0 ? green : red,
            alignment: .right
        )

        red.withAlphaComponent(0.78).setFill()
        UIBezierPath(roundedRect: track, cornerRadius: 6).fill()
        let breakEvenX = track.minX + track.width * CGFloat((breakEven / upperBound).clamped(to: 0 ... 1))
        green.withAlphaComponent(0.84).setFill()
        UIBezierPath(
            roundedRect: CGRect(x: breakEvenX, y: track.minY, width: max(track.maxX - breakEvenX, 0), height: track.height),
            cornerRadius: 6
        ).fill()
        drawRailMarker(value: breakEven, upperBound: upperBound, track: track, color: blue)
        if model.profitTarget > 0 {
            drawRailMarker(value: target, upperBound: upperBound, track: track, color: purple)
        }

        let currentX = track.minX + track.width * CGFloat((model.ticketPrice / upperBound).clamped(to: 0 ... 1))
        (model.profit >= 0 ? green : red).setFill()
        UIBezierPath(ovalIn: CGRect(x: currentX - 6, y: track.midY - 6, width: 12, height: 12)).fill()
        UIColor.white.setStroke()
        let currentRing = UIBezierPath(ovalIn: CGRect(x: currentX - 6, y: track.midY - 6, width: 12, height: 12))
        currentRing.lineWidth = 1.5
        currentRing.stroke()

        drawText(
            "Break even \(ForecastTheme.compactCurrency(breakEven))",
            in: CGRect(x: margin, y: y + 46, width: 220, height: 14),
            font: .systemFont(ofSize: 8, weight: .semibold),
            color: blue
        )
        drawText(
            "Target \(model.profitTarget > 0 ? ForecastTheme.compactCurrency(target) : "-")",
            in: CGRect(x: 350, y: y + 46, width: pageBounds.width - margin - 350, height: 14),
            font: .systemFont(ofSize: 8, weight: .semibold),
            color: purple,
            alignment: .right
        )
    }

    private static func drawRailMarker(value: Double, upperBound: Double, track: CGRect, color: UIColor) {
        guard value.isFinite, upperBound.isFinite, upperBound > 0 else { return }
        let x = track.minX + track.width * CGFloat((value / upperBound).clamped(to: 0 ... 1))
        color.setFill()
        UIBezierPath(roundedRect: CGRect(x: x - 1.5, y: track.minY - 4, width: 3, height: track.height + 8), cornerRadius: 1.5).fill()
    }

    @MainActor
    private static func drawPriceCurve(model: ForecastModel, rect: CGRect) {
        let upperPrice = max(model.ticketPrice, model.recommendedTicketPrice ?? 0, 25) * 1.65
        let samples = (0 ... 20).map { index -> (Double, Double) in
            let price = upperPrice * Double(index) / 20
            return (price, model.projectedProfit(at: price))
        }
        let minimumProfit = min(samples.map(\.1).min() ?? 0, 0)
        let maximumProfit = max(samples.map(\.1).max() ?? 1, 1)
        let span = max(maximumProfit - minimumProfit, 1)

        UIColor(white: 0.93, alpha: 1).setStroke()
        let framePath = UIBezierPath(rect: rect)
        framePath.lineWidth = 1
        framePath.stroke()

        let zeroY = rect.maxY - CGFloat((0 - minimumProfit) / span) * rect.height
        let zeroPath = UIBezierPath()
        zeroPath.move(to: CGPoint(x: rect.minX, y: zeroY))
        zeroPath.addLine(to: CGPoint(x: rect.maxX, y: zeroY))
        UIColor(red: 0.76, green: 0.06, blue: 0.13, alpha: 0.38).setStroke()
        zeroPath.setLineDash([4, 4], count: 2, phase: 0)
        zeroPath.stroke()

        let curve = UIBezierPath()
        for (index, sample) in samples.enumerated() {
            let x = rect.minX + CGFloat(sample.0 / upperPrice) * rect.width
            let y = rect.maxY - CGFloat((sample.1 - minimumProfit) / span) * rect.height
            if index == 0 { curve.move(to: CGPoint(x: x, y: y)) }
            else { curve.addLine(to: CGPoint(x: x, y: y)) }
        }
        UIColor(red: 0.00, green: 0.43, blue: 0.64, alpha: 1).setStroke()
        curve.lineWidth = 2.5
        curve.lineCapStyle = .round
        curve.lineJoinStyle = .round
        curve.stroke()

        let currentX = rect.minX + CGFloat(model.ticketPrice / upperPrice) * rect.width
        let currentY = rect.maxY - CGFloat((model.profit - minimumProfit) / span) * rect.height
        UIColor(red: 0.03, green: 0.50, blue: 0.24, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: currentX - 4, y: currentY - 4, width: 8, height: 8)).fill()

        drawText(
            "$0",
            in: CGRect(x: rect.minX, y: rect.maxY + 3, width: 40, height: 12),
            font: .systemFont(ofSize: 7, weight: .medium),
            color: UIColor(white: 0.42, alpha: 1)
        )
        drawText(
            ForecastTheme.compactCurrency(upperPrice),
            in: CGRect(x: rect.maxX - 55, y: rect.maxY + 3, width: 55, height: 12),
            font: .systemFont(ofSize: 7, weight: .medium),
            color: UIColor(white: 0.42, alpha: 1),
            alignment: .right
        )
    }

    @MainActor
    private static func drawThresholds(model: ForecastModel, at y: CGFloat) -> CGFloat {
        drawText(
            "Decision points",
            in: CGRect(x: margin, y: y, width: 220, height: 22),
            font: .systemFont(ofSize: 16, weight: .bold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
        )
        let data: [(String, String, UIColor)] = [
            ("Expected attendance", "\(model.ticketsSold) tickets", UIColor(red: 0.90, green: 0.43, blue: 0.00, alpha: 1)),
            ("Break-even attendance", model.breakEvenTickets.map { "\($0) tickets" } ?? "Not reachable", UIColor(red: 0.00, green: 0.39, blue: 0.85, alpha: 1)),
            ("Profit target", model.profitTarget > 0 ? ForecastTheme.compactCurrency(model.profitTarget) : "Not set", UIColor(red: 0.55, green: 0.17, blue: 0.84, alpha: 1)),
            ("Target attendance", model.profitTargetTickets.map { "\($0) tickets" } ?? "Not set", UIColor(red: 0.55, green: 0.17, blue: 0.84, alpha: 1))
        ]
        for (index, datum) in data.enumerated() {
            let column = CGFloat(index % 2)
            let row = CGFloat(index / 2)
            let x = margin + column * 264
            let rowY = y + 34 + row * 48
            drawText(
                datum.0,
                in: CGRect(x: x, y: rowY, width: 160, height: 14),
                font: .systemFont(ofSize: 8, weight: .semibold),
                color: UIColor(white: 0.42, alpha: 1)
            )
            drawText(
                datum.1,
                in: CGRect(x: x, y: rowY + 15, width: 210, height: 19),
                font: .systemFont(ofSize: 12, weight: .bold),
                color: datum.2
            )
        }
        return y + 136
    }

    private static func drawReconciliation(
        title: String,
        total: Double,
        itemized: Double,
        difference: Double,
        color: UIColor,
        at y: CGFloat
    ) -> CGFloat {
        drawText(
            title,
            in: CGRect(x: margin, y: y, width: 160, height: 24),
            font: .systemFont(ofSize: 16, weight: .bold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
        )
        let metrics = [
            ("SET TOTAL", total, color),
            ("ITEMIZED", itemized, UIColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1)),
            (difference >= 0 ? "UNALLOCATED" : "OVER BY", abs(difference), difference == 0 ? UIColor(red: 0.03, green: 0.50, blue: 0.24, alpha: 1) : UIColor(red: 0.68, green: 0.38, blue: 0.00, alpha: 1))
        ]
        for (index, metric) in metrics.enumerated() {
            let x = margin + CGFloat(index) * 176
            drawText(
                metric.0,
                in: CGRect(x: x, y: y + 32, width: 150, height: 14),
                font: .systemFont(ofSize: 8, weight: .bold),
                color: UIColor(white: 0.42, alpha: 1)
            )
            drawText(
                ForecastTheme.compactCurrency(metric.1),
                in: CGRect(x: x, y: y + 47, width: 150, height: 24),
                font: .monospacedDigitSystemFont(ofSize: 14, weight: .bold),
                color: metric.2
            )
        }
        return y + 82
    }

    private static func drawItemTable(
        title: String,
        items: [MoneyItem],
        colors: [UIColor],
        startY: CGFloat,
        newPage: () -> CGFloat
    ) -> CGFloat {
        var y = startY
        drawText(
            title,
            in: CGRect(x: margin, y: y, width: 260, height: 20),
            font: .systemFont(ofSize: 12, weight: .bold),
            color: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1)
        )
        y += 26

        let displayedItems = items.isEmpty ? [MoneyItem(name: "No itemized entries", amount: 0)] : items
        let maximum = max(displayedItems.map(\.amount).max() ?? 0, 1)
        for (index, item) in displayedItems.enumerated() {
            if y > 718 {
                y = newPage()
            }
            if Int((y - startY) / 30).isMultiple(of: 2) {
                UIColor(white: 0.965, alpha: 1).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y - 4, width: pageBounds.width - margin * 2, height: 28)).fill()
            }
            let color = colors[index % colors.count]
            color.setFill()
            UIBezierPath(ovalIn: CGRect(x: margin + 8, y: y + 5, width: 7, height: 7)).fill()
            drawText(
                item.name,
                in: CGRect(x: margin + 22, y: y, width: 250, height: 18),
                font: .systemFont(ofSize: 10, weight: .medium),
                color: UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
            )
            UIColor(white: 0.89, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 328, y: y + 4, width: 96, height: 9), cornerRadius: 4.5).fill()
            if item.amount > 0 {
                color.setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: 328, y: y + 4, width: max(96 * CGFloat(item.amount / maximum), 3), height: 9),
                    cornerRadius: 4.5
                ).fill()
            }
            drawText(
                item.amount.formatted(ForecastTheme.currencyFormat),
                in: CGRect(x: 438, y: y, width: 122, height: 18),
                font: .monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
                color: color,
                alignment: .right
            )
            y += 30
        }
        return y
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

private enum ExportPreviewMode: String, CaseIterable, Identifiable {
    case richText = "Text"
    case pdf = "PDF"

    var id: Self { self }
}

private struct ExportRevision: Equatable {
    let snapshot: ForecastPersistenceSnapshot
    let eventName: String
    let includeItemization: Bool
    let includeThresholds: Bool
}

struct ForecastReportView: View {
    let model: ForecastModel
    let eventName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var includeItemization = false
    @State private var includeThresholds = false
    @State private var previewMode: ExportPreviewMode = .richText
    @State private var copiedMode: ExportPreviewMode?
    @State private var pdfURL: URL?
    @State private var rtfURL: URL?
    @State private var pdfError: String?
    @State private var isBuildingExport = false

    private var exportRevision: ExportRevision {
        ExportRevision(
            snapshot: model.persistenceSnapshot,
            eventName: eventName,
            includeItemization: includeItemization,
            includeThresholds: includeThresholds
        )
    }

    private var report: String {
        ForecastReportBuilder.make(
            for: model,
            eventName: eventName,
            includeItemization: includeItemization,
            includeThresholds: includeThresholds
        )
    }

    private var attributedReport: NSAttributedString {
        ForecastReportBuilder.makeAttributed(
            for: model,
            eventName: eventName,
            includeItemization: includeItemization,
            includeThresholds: includeThresholds
        )
    }

    private var displayedAttributedReport: NSAttributedString {
        guard colorScheme == .dark else { return attributedReport }
        let displayed = NSMutableAttributedString(attributedString: attributedReport)
        displayed.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: displayed.length)
        ) { value, range, _ in
            guard let color = value as? UIColor else { return }
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
                if saturation >= 0.45, brightness >= 0.32 { return }
                if brightness < 0.70 {
                    displayed.addAttribute(
                        .foregroundColor,
                        value: brightness < 0.20 ? UIColor.white : UIColor(white: 0.76, alpha: 1),
                        range: range
                    )
                    return
                }
            }
            var white: CGFloat = 0
            var grayscaleAlpha: CGFloat = 0
            if color.getWhite(&white, alpha: &grayscaleAlpha), white < 0.70 {
                displayed.addAttribute(
                    .foregroundColor,
                    value: white < 0.18 ? UIColor.white : UIColor(white: 0.76, alpha: 1),
                    range: range
                )
                return
            }
        }
        return displayed
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Toggle("Include itemized budget", isOn: $includeItemization)
                        .tint(ForecastTheme.warning)
                        .frame(height: 42)
                    Toggle("Include pricing thresholds", isOn: $includeThresholds)
                        .tint(ForecastTheme.warning)
                        .frame(height: 42)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)

                Divider().overlay(ForecastTheme.divider)

                exportModePicker
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().overlay(ForecastTheme.divider)

                preview
            }
            .background(ForecastTheme.canvas)
            .navigationTitle("Export budget")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                exportActions
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: exportRevision) {
            await rebuildExports()
        }
        .onChange(of: includeItemization) { _, _ in copiedMode = nil }
        .onChange(of: includeThresholds) { _, _ in copiedMode = nil }
        .onChange(of: previewMode) { _, _ in copiedMode = nil }
    }

    private var exportModePicker: some View {
        HStack(spacing: 8) {
            ForEach(ExportPreviewMode.allCases) { mode in
                let isSelected = previewMode == mode
                Button {
                    if reduceMotion { previewMode = mode }
                    else { withAnimation(ForecastMotion.paging) { previewMode = mode } }
                } label: {
                    Label(mode.rawValue, systemImage: mode == .richText ? "text.document" : "doc.richtext")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.black : ForecastTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            isSelected ? ForecastTheme.warning : ForecastTheme.raised,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var exportActions: some View {
        HStack(spacing: 10) {
            Button(action: copyCurrentExport) {
                exportActionLabel(
                    copiedMode == previewMode ? "Copied" : "Copy \(previewMode.rawValue)",
                    systemImage: copiedMode == previewMode ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.plain)
            .disabled(isBuildingExport || (previewMode == .pdf && pdfURL == nil))

            switch previewMode {
            case .richText:
                if let rtfURL {
                    ShareLink(
                        item: rtfURL,
                        preview: SharePreview("\(eventName) Budget", image: Image(systemName: "text.document"))
                    ) {
                        exportActionLabel("Share text", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isBuildingExport)
                } else {
                    exportActionLabel("Building text", systemImage: "doc.badge.clock")
                        .opacity(0.55)
                }
            case .pdf:
                if let pdfURL {
                    ShareLink(
                        item: pdfURL,
                        preview: SharePreview("\(eventName) Budget", image: Image(systemName: "doc.richtext"))
                    ) {
                        exportActionLabel("Share PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isBuildingExport)
                } else {
                    exportActionLabel(pdfError == nil ? "Building PDF" : "PDF unavailable", systemImage: pdfError == nil ? "doc.badge.clock" : "exclamationmark.triangle")
                        .opacity(0.55)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ForecastTheme.surface)
    }

    private func exportActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(ForecastTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ForecastTheme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ForecastTheme.divider, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            switch previewMode {
            case .richText:
                ScrollView {
                    Text(AttributedString(displayedAttributedReport))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .background(ForecastTheme.canvas)
                .accessibilityLabel("Text budget preview")
            case .pdf:
                if let pdfURL {
                    PDFDocumentPreview(url: pdfURL)
                        .id(pdfURL)
                } else if let pdfError {
                    ContentUnavailableView("PDF unavailable", systemImage: "exclamationmark.triangle", description: Text(pdfError))
                } else {
                    ProgressView("Building PDF preview")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isBuildingExport {
                Label("Updating", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ForecastTheme.primaryText)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .budgetGlassSurface(tint: ForecastTheme.warning, cornerRadius: 14)
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private func copyCurrentExport() {
        switch previewMode {
        case .richText:
            let fullRange = NSRange(location: 0, length: attributedReport.length)
            let rtf = try? attributedReport.data(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            var item: [String: Any] = [UTType.plainText.identifier: report]
            if let rtf { item[UTType.rtf.identifier] = rtf }
            UIPasteboard.general.setItems([item])
        case .pdf:
            guard let pdfURL,
                  let data = try? Data(contentsOf: pdfURL) else { return }
            UIPasteboard.general.setData(data, forPasteboardType: UTType.pdf.identifier)
        }
        if reduceMotion {
            copiedMode = previewMode
        } else {
            withAnimation(ForecastMotion.control) {
                copiedMode = previewMode
            }
        }
    }

    @MainActor
    private func rebuildExports() async {
        isBuildingExport = true
        do {
            try await Task.sleep(for: .milliseconds(180))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        buildExports()
        isBuildingExport = false
    }

    @MainActor
    private func buildExports() {
        do {
            let newPDFURL = try ForecastPDFBuilder.makeURL(
                for: model,
                eventName: eventName,
                includeItemization: includeItemization,
                includeThresholds: includeThresholds
            )
            let fullRange = NSRange(location: 0, length: attributedReport.length)
            let rtf = try attributedReport.data(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            let safeName = eventName
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let rtfDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("EventBudget-RTF-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: rtfDirectory, withIntermediateDirectories: true)
            let newRTFURL = rtfDirectory
                .appendingPathComponent("\(safeName.isEmpty ? "Event" : safeName)-Budget.rtf")
            try rtf.write(to: newRTFURL, options: .atomic)
            pdfURL = newPDFURL
            rtfURL = newRTFURL
            pdfError = nil
        } catch {
            pdfURL = nil
            rtfURL = nil
            pdfError = error.localizedDescription
        }
    }
}

private struct PDFDocumentPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageShadowsEnabled = true
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
            view.autoScales = true
        }
    }
}
