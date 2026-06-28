import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

void downloadFile(List<int> bytes, String filename) {
  throw UnsupportedError('Cannot download file on this platform');
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
