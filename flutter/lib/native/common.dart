import 'dart:io';

final isAndroid_ = Platform.isAndroid;
final isIOS_ = Platform.isIOS;
final isWindows_ = Platform.isWindows;
final isMacOS_ = Platform.isMacOS;
final isLinux_ = Platform.isLinux;
final isWeb_ = false;
final isWebDesktop_ = false;

final isDesktop_ = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

String get screenInfo_ => '';

final isWebOnWindows_ = false;
final isWebOnLinux_ = false;
final isWebOnMacOS_ = false;

void logUpdateError_(String message) {
  try {
    String logDir = '';
    if (Platform.isWindows) {
      logDir = '${Platform.environment['APPDATA']}\\AcilBir\\log';
    } else if (Platform.isMacOS) {
      logDir = '${Platform.environment['HOME']}/Library/Logs/AcilBir';
    } else if (Platform.isLinux) {
      logDir = '${Platform.environment['HOME']}/.local/share/AcilBir/log';
    }
    if (logDir.isNotEmpty) {
      final dir = Directory(logDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('$logDir/update_ui.log');
      final time = DateTime.now().toIso8601String();
      file.writeAsStringSync('[$time] $message\n', mode: FileMode.append);
    }
  } catch (_) {
    // Fail silently if we can't write the log
  }
}
