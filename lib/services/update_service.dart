import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String updateUrl =
      'https://canan-dev.github.io/Mackey_app/version.json';
  static const MethodChannel _installerChannel =
      MethodChannel('com.mmc.mmc_app/installer');

  static final ValueNotifier<bool> hasUpdateNotifier =
      ValueNotifier<bool>(false);

  /// Check for app updates. If [isManual] is true, shows a message when up-to-date.
  static Future<void> checkForUpdates(BuildContext context,
      {bool isManual = false}) async {
    try {
      final response = await http
          .get(Uri.parse(updateUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        if (isManual && context.mounted) {
          _showSnackBar(context, 'Unable to check for updates right now.');
        }
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final String serverVersion = data['version'] ?? '1.0.0';
      final String apkUrl = data['apk_url'] ??
          'https://canan-dev.github.io/Mackey_app/app-release.apk';
      final String changelog = data['changelog'] ?? 'General improvements.';
      final bool forceUpdate = data['force_update'] ?? false;

      PackageInfo packageInfo;
      try {
        packageInfo = await PackageInfo.fromPlatform();
      } catch (_) {
        packageInfo = PackageInfo(
          appName: 'MMC',
          packageName: 'com.mmc.mmc_app',
          version: '1.0.0',
          buildNumber: '1',
        );
      }

      final String currentVersion = packageInfo.version;

      if (_isVersionNewer(serverVersion, currentVersion)) {
        hasUpdateNotifier.value = true;
        if (context.mounted) {
          _showUpdateDialog(
            context: context,
            currentVersion: currentVersion,
            newVersion: serverVersion,
            changelog: changelog,
            apkUrl: apkUrl,
            forceUpdate: forceUpdate,
          );
        }
      } else {
        hasUpdateNotifier.value = false;
        if (isManual && context.mounted) {
          _showSnackBar(context, 'MMC is up to date (v$currentVersion)! ✨');
        }
      }
    } catch (e) {
      if (isManual && context.mounted) {
        _showSnackBar(context, 'Error checking for updates: $e');
      }
    }
  }

  /// Compares semantic versions (e.g. "1.0.1" vs "1.0.0")
  static bool _isVersionNewer(String server, String current) {
    try {
      final serverParts =
          server.split('.').map((e) => int.parse(e.trim())).toList();
      final currentParts =
          current.split('.').map((e) => int.parse(e.trim())).toList();

      for (int i = 0; i < serverParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (serverParts[i] > currentParts[i]) return true;
        if (serverParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (_) {
      return server != current;
    }
  }

  static void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1F2427),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static void _showUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
    required String changelog,
    required String apkUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => _UpdateDialogWidget(
        currentVersion: currentVersion,
        newVersion: newVersion,
        changelog: changelog,
        apkUrl: apkUrl,
        forceUpdate: forceUpdate,
      ),
    );
  }

  /// Downloads APK and triggers Android Package Installer
  static Future<bool> downloadAndInstallApk(
      String apkUrl, Function(double progress) onProgress) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) return false;

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/mmc_update.apk';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int downloadedBytes = 0;

      await response.stream.forEach((chunk) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          onProgress(downloadedBytes / contentLength);
        }
      });

      await sink.close();
      client.close();

      // Trigger native Android installation intent
      final bool success = await _installerChannel.invokeMethod('installApk', {
        'filePath': filePath,
      });

      return success;
    } catch (e) {
      debugPrint('Error downloading or installing APK: $e');
      return false;
    }
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final String currentVersion;
  final String newVersion;
  final String changelog;
  final String apkUrl;
  final bool forceUpdate;

  const _UpdateDialogWidget({
    required this.currentVersion,
    required this.newVersion,
    required this.changelog,
    required this.apkUrl,
    required this.forceUpdate,
  });

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    final success = await UpdateService.downloadAndInstallApk(
      widget.apkUrl,
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _isDownloading = false;
        _errorMessage =
            'Failed to download or install update. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const limeAccent = Color(0xFFD5F26A);
    const cardBg = Color(0xFF1F2427);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: limeAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_rounded,
                      color: limeAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available! 🚀',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v${widget.newVersion} (Current: v${widget.currentVersion})',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "What's New:",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.changelog,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Downloading update...',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: limeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(limeAccent),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!widget.forceUpdate)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Later',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _startUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: limeAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Update Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
