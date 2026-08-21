#!/usr/bin/env python3
"""Generate a clean, readable PDF from the BrisConnect SQL schema."""

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    PageBreak,
    Preformatted,
    Table,
    TableStyle,
)


def main():
    schema_path = Path(__file__).with_name("brisconnect_schema.sql")
    pdf_path = schema_path.with_suffix(".pdf")
    schema_text = schema_path.read_text(encoding="utf-8")

    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        rightMargin=1.5 * cm,
        leftMargin=1.5 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "TitleCustom",
        parent=styles["Title"],
        fontSize=24,
        textColor=colors.HexColor("#FF7A1A"),
        spaceAfter=18,
    )
    heading1_style = ParagraphStyle(
        "Heading1Custom",
        parent=styles["Heading1"],
        fontSize=16,
        textColor=colors.HexColor("#0D1B3F"),
        spaceBefore=16,
        spaceAfter=8,
    )
    body_style = ParagraphStyle(
        "BodyCustom",
        parent=styles["BodyText"],
        fontSize=10,
        leading=14,
    )
    code_style = ParagraphStyle(
        "CodeCustom",
        parent=styles["Code"],
        fontSize=8,
        leading=10,
        leftIndent=0.5 * cm,
    )

    story = []

    # Title page
    story.append(Paragraph("BrisConnect+", title_style))
    story.append(Paragraph("Full Database Schema", styles["Title"]))
    story.append(Spacer(1, 0.5 * cm))
    story.append(
        Paragraph(
            "PostgreSQL-compatible relational schema mapped from the BrisConnect Firestore collections.",
            body_style,
        )
    )
    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph(f"Generated: 2026-08-09", body_style))
    story.append(Spacer(1, 0.3 * cm))
    story.append(
        Paragraph(
            "Total tables: 42 &nbsp;|&nbsp; Total indexes: 45+",
            body_style,
        )
    )
    story.append(PageBreak())

    # Table of contents
    story.append(Paragraph("Table of Contents", heading1_style))
    sections = [
        "1. Auth / Users",
        "2. Businesses",
        "3. Attractions & Discover",
        "4. Events",
        "5. Business Events & Promotions",
        "6. Reviews & Recommendations",
        "7. Social & Engagement",
        "8. Reports & Feedback",
        "9. Notifications & Messaging",
        "10. Payments & Subscriptions",
        "11. Curated Content",
        "12. System / Config",
    ]
    toc_data = [[Paragraph(s, body_style)] for s in sections]
    toc_table = Table(toc_data, colWidths=[16 * cm])
    toc_table.setStyle(
        TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("LINEBELOW", (0, 0), (-1, -1), 0.5, colors.HexColor("#E5E7EB")),
        ])
    )
    story.append(toc_table)
    story.append(PageBreak())

    # Schema code section
    story.append(Paragraph("Complete SQL Schema", heading1_style))
    story.append(
        Paragraph(
            "The full schema is reproduced below. Each table includes primary keys, foreign keys, indexes, and default values.",
            body_style,
        )
    )
    story.append(Spacer(1, 0.4 * cm))

    # Split into blocks separated by section headers for cleaner page breaks
    lines = schema_text.splitlines()
    current_block = []
    for line in lines:
        if line.startswith("-- ==="):
            if current_block:
                story.append(Preformatted("\n".join(current_block), code_style))
                current_block = []
            story.append(PageBreak())
        current_block.append(line)
    if current_block:
        story.append(Preformatted("\n".join(current_block), code_style))

    doc.build(story)
    print(f"PDF generated: {pdf_path}")


if __name__ == "__main__":
    main()
