import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void openPhotoViewer(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
}) {
  if (urls.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PhotoViewer(urls: urls, initialIndex: initialIndex),
    ),
  );
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.urls, this.initialIndex = 0});
  final List<String> urls;
  final int initialIndex;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF151918),
    appBar: AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: const Color(0xFF151918),
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: context.tr("Zatvori"),
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text('${_index + 1} / ${widget.urls.length}'),
    ),
    body: SafeArea(
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.urls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.urls[index],
              fit: BoxFit.contain,
              placeholder: (_, _) => const CircularProgressIndicator(),
              errorWidget: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
