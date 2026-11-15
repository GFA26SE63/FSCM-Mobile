abstract class PrintSession {
  Future<void> showHtml(String html, String title);
  void close();
}
