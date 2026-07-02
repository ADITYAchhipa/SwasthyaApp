import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

void downloadFile(List<int> bytes, String filename) {
  Printing.sharePdf(
    bytes: Uint8List.fromList(bytes),
    filename: filename,
  );
}

void launchUrlCompat(String url) {
  throw UnsupportedError('Cannot launch URL on this platform');
}

void printPdfBytes(List<int> bytes, String filename) {
  Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => Uint8List.fromList(bytes),
    name: filename,
  );
}
