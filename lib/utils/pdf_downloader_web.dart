import 'dart:html' as html;
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

void downloadFile(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename;
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  
  // Delay revocation to prevent WebKitBlobResource error in Safari
  Future.delayed(const Duration(milliseconds: 1000), () {
    html.Url.revokeObjectUrl(url);
  });
}

void launchUrlCompat(String url) {
  html.window.open(url, '_blank');
}

void printPdfBytes(List<int> bytes, String filename) {
  Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => Uint8List.fromList(bytes),
    name: filename,
  );
}
