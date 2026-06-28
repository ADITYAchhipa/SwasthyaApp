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
