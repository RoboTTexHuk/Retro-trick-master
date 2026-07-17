import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';




/// Отдельный экран с WebView для загрузки игры.
///
/// Использование:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const GameWebView()));
/// ```
/// или сразу как home:
/// ```dart
/// MaterialApp(home: GameWebView())
/// ```
class GameWebView extends StatefulWidget {
  const GameWebView({
    super.key,
    this.url = 'https://gameapps.retrotrickmaster.guru/',
  });

  final String url;

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  @override
  void initState() {
    // TODO: implement initState

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.initState();
  }
  // Основные настройки InAppWebView.
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    // JS и хранилища
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    domStorageEnabled: true,
    databaseEnabled: true,

    // Медиа
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,

    // Зум / скролл
    supportZoom: false,
    disableHorizontalScroll: false,
    disableVerticalScroll: false,

    // Кэш и сеть
    cacheEnabled: true,
    clearCache: false,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

    // Внешний вид
    transparentBackground: true,
    supportMultipleWindows: false,

    // Прочее
    useShouldOverrideUrlLoading: true,
    useOnLoadResource: false,
    allowsBackForwardNavigationGestures: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: _settings,
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
              },
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) async {
                setState(() => _isLoading = false);
              },
              onReceivedError: (controller, request, error) {
                setState(() => _isLoading = false);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                return NavigationActionPolicy.ALLOW;
              },
            ),

            // Лоадер поверх WebView, пока страница грузится.

          ],
        ),
      ),
    );
  }

  /// Перезагрузить страницу.
  Future<void> reload() async {
    await _controller?.reload();
  }

  /// Назад по истории WebView.
  Future<bool> goBackIfPossible() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
      return true;
    }
    return false;
  }
}
