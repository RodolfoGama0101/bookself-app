import 'package:flutter/material.dart';
import '../../utils/error_handler.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.url,
    required this.placeholderBuilder,
  });

  final String url;
  final WidgetBuilder placeholderBuilder;

  static String? canonicalUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.replace(scheme: 'https').toString();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = canonicalUrl(url);
    if (imageUrl == null) return placeholderBuilder(context);
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      frameBuilder: (context, child, frame, synchronouslyLoaded) =>
          synchronouslyLoaded || frame != null
          ? child
          : placeholderBuilder(context),
      errorBuilder: (context, error, stackTrace) {
        ErrorHandler.report(error, operation: ErrorOperation.loadBookCover);
        return placeholderBuilder(context);
      },
    );
  }
}
