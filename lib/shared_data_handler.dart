// lib/share_handler.dart

import 'package:shared_preferences/shared_preferences.dart';

class ShareHandler {
  // Function to handle shared text
  Future<void> handleSharedText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    const textKey = 'shared_texts';
    List<String>? texts = prefs.getStringList(textKey);

    texts ??= [];

    texts.add(text);
    await prefs.setStringList(textKey, texts);
  }

  // Function to handle shared URL
  Future<void> handleSharedUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    const urlKey = 'shared_urls';
    List<String>? urls = prefs.getStringList(urlKey);

    urls ??= [];

    urls.add(url);
    await prefs.setStringList(urlKey, urls);
  }
}
