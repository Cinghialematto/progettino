import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Document buildMonthlyPdf({
  required String monthLabel,
  required List<Map<String, dynamic>> rows,
  required double totalHours,
  bool includeFullNotes = false,
}) {
  final pdf = pw.Document();

  // PAGINA 1 — RIEPILOGO + TABELLA
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'HORES',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Riepilogo ore – $monthLabel',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Divider(),
            pw.SizedBox(height: 12),

            pw.Text(
              'Totale ore: ${_formatPdfHours(totalHours)}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),

            pw.Table.fromTextArray(
              headers: ['Data', 'Ore', 'Lettera', 'Nota'],
              data: rows.map((r) {
                return [
                  r['date'] ?? '',
                  r['hours'] ?? '',
                  r['letter'] ?? '',
                  r['notePreview'] ?? '',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(width: 0.5),
            ),

            pw.Spacer(),

            pw.Text(
              'Documento generato con Hores',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ],
        );
      },
    ),
  );

  // PAGINA 2 — NOTE COMPLETE (OPZIONALE)
  if (includeFullNotes) {
    final fullNotes = rows
        .where((r) => (r['noteFull'] as String?)?.trim().isNotEmpty == true)
        .toList();

    if (fullNotes.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'NOTE COMPLETE – $monthLabel',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 8),

                ...fullNotes.expand((r) => [
                      pw.Text(
                        r['date'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        r['noteFull'] ?? '',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 12),
                    ]),
              ],
            );
          },
        ),
      );
    }
  }

  return pdf;
}

String _formatPdfHours(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}
