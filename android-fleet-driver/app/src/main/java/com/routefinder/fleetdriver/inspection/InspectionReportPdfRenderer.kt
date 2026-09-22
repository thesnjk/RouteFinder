package com.routefinder.fleetdriver.inspection

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import java.io.ByteArrayOutputStream

/**
 * Renders a compact DVSA walkaround PDF from checklist items (Android PdfDocument).
 * Keeps fleet handoff light — photos remain optional base64 on the snapshot JSON.
 */
object InspectionReportPdfRenderer {
    fun pdfBytes(
        summary: InspectionSummary,
        items: List<InspectionChecklistItem>,
    ): ByteArray {
        val doc = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = doc.startPage(pageInfo)
        val canvas: Canvas = page.canvas
        val title = Paint().apply {
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textSize = 18f
            isAntiAlias = true
        }
        val body = Paint().apply {
            textSize = 11f
            isAntiAlias = true
        }
        var y = 48f
        canvas.drawText("RouteFinder DVSA walkaround", 40f, y, title)
        y += 28f
        canvas.drawText("Vehicle: ${summary.vehicleLabel}", 40f, y, body)
        y += 16f
        canvas.drawText("Plate: ${summary.registrationPlate ?: "—"}", 40f, y, body)
        y += 16f
        canvas.drawText("Defects: ${summary.defectCount}", 40f, y, body)
        y += 16f
        canvas.drawText("Completed: ${summary.completedAt}", 40f, y, body)
        y += 24f
        for (item in items) {
            if (y > 780f) break
            val photo = if (item.photoBase64 != null) " [photo]" else ""
            val line = "${item.zone.label}: ${item.label} — ${item.status.name}$photo"
            canvas.drawText(line, 40f, y, body)
            y += 14f
            if (item.note.isNotBlank()) {
                canvas.drawText("  Note: ${item.note.take(80)}", 40f, y, body)
                y += 14f
            }
        }
        doc.finishPage(page)
        val out = ByteArrayOutputStream()
        doc.writeTo(out)
        doc.close()
        return out.toByteArray()
    }
}
