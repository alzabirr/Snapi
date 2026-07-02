import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/screenshot_item.dart';

class ExportService {
  static Future<void> shareAsText(List<ScreenshotItem> items) async {
    if (items.isEmpty) return;

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("=== Snapi Exported Notes & Texts ===");
    buffer.writeln("Exported on: ${DateTime.now().toLocal()}\n");

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln("Screenshot ${i + 1}");
      buffer.writeln("Date: ${item.createdAt.toLocal().toString().split('.')[0]}");
      buffer.writeln("Category: ${item.category}");
      if (item.note.isNotEmpty) {
        buffer.writeln("Note: ${item.note}");
      }
      if (item.extractedText.isNotEmpty) {
        buffer.writeln("Extracted Text:\n${item.extractedText}");
      }
      buffer.writeln("\n-----------------------------------\n");
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/snapi_export_${DateTime.now().millisecondsSinceEpoch}.txt');
    await tempFile.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(tempFile.path)], text: 'Exported Screenshot Text from Snapi');
  }

  static Future<void> shareAsPDF(List<ScreenshotItem> items) async {
    if (items.isEmpty) return;

    final pdf = pw.Document();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      
      // Try to load image
      pw.Widget? imageWidget;
      final file = File(item.path);
      if (await file.exists()) {
        try {
          final imageBytes = await file.readAsBytes();
          final pdfImage = pw.MemoryImage(imageBytes);
          imageWidget = pw.Image(pdfImage, height: 350, fit: pw.BoxFit.contain);
        } catch (e) {
          // If reading image failed, we skip image widget but still write text
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Screenshot ${i + 1}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text(item.category.toUpperCase(), style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Date: ${item.createdAt.toLocal().toString().split('.')[0]}", style: const pw.TextStyle(fontSize: 11)),
              if (item.note.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text("Note:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text(item.note, style: const pw.TextStyle(fontSize: 11)),
              ],
              pw.SizedBox(height: 12),
              if (imageWidget != null) ...[
                pw.Center(child: imageWidget),
                pw.SizedBox(height: 12),
              ],
              if (item.extractedText.isNotEmpty) ...[
                pw.Text("Extracted Text:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 4),
                pw.Text(item.extractedText, style: const pw.TextStyle(fontSize: 9)),
              ],
            ];
          },
        ),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/snapi_export_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await tempFile.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(tempFile.path)], text: 'Exported PDF Document from Snapi');
  }
}
