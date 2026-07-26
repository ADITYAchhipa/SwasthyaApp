import 'package:http/http.dart' as http;
import 'pdf_downloader_stub.dart'
    if (dart.library.html) 'pdf_downloader_web.dart';

void downloadPdfFile(List<int> bytes, String filename) {
  downloadFile(bytes, filename);
}

void launchShareUrl(String url) {
  launchUrlCompat(url);
}

void printPdfFile(List<int> bytes, String filename) {
  printPdfBytes(bytes, filename);
}

Future<void> downloadPdfFromUrl(String url, String filename) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    downloadPdfFile(response.bodyBytes, filename);
  } else {
    throw Exception('Failed to load PDF from URL: ${response.statusCode}');
  }
}
