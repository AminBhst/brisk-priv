import 'dart:io';

import 'package:brisk/util/settings_cache.dart';

class DownloadSettings extends ConnectionSettings {
  final Directory baseSaveDir;
  int totalConnections;

  DownloadSettings({
    required this.baseSaveDir,
    required this.totalConnections,
    required super.baseTempDir,
    required super.connectionRetryTimeout,
    required super.maxConnectionRetryCount,
  });

  factory DownloadSettings.fromSettingsCache() {
    return DownloadSettings(
      baseTempDir: SettingsCache.temporaryDir,
      baseSaveDir: SettingsCache.saveDir,
      totalConnections: SettingsCache.connectionsNumber,
      connectionRetryTimeout: SettingsCache.connectionRetryTimeout * 1000,
      maxConnectionRetryCount: SettingsCache.connectionRetryCount,
    );
  }
}

class ConnectionSettings {
  final Directory baseTempDir;
  final int connectionRetryTimeout;
  final int maxConnectionRetryCount;

  ConnectionSettings({
    required this.baseTempDir,
    required this.connectionRetryTimeout,
    required this.maxConnectionRetryCount,
  });
}
