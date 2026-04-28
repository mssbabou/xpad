import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xpad/core/result.dart';
import 'package:xpad/services/octoprint/octoprint_models.dart';

class OctoPrintApi {
  final http.Client _client;

  OctoPrintApi({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String apiKey) => {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      };

  Future<Result<OctoPrintStatus>> getStatus(String baseUrl, String apiKey) async {
    try {
      final printerRes = await _client
          .get(Uri.parse('$baseUrl/api/printer'), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 8));

      if (printerRes.statusCode == 409) {
        // 409 = printer not operational (e.g. disconnected)
        return const Success(OctoPrintStatus(state: PrinterState.offline));
      }
      if (printerRes.statusCode != 200) {
        return Failure(AppError(
          kind: ErrorKind.network,
          message: 'Printer error ${printerRes.statusCode}',
        ));
      }

      final printerJson = jsonDecode(printerRes.body) as Map<String, dynamic>;
      final flags = printerJson['state']?['flags'] as Map<String, dynamic>? ?? {};
      final state = _parseState(flags);
      final temps = printerJson['temperature'] as Map<String, dynamic>? ?? {};
      final hotend = _parseTemp(temps['tool0'] as Map<String, dynamic>?);
      final bed = _parseTemp(temps['bed'] as Map<String, dynamic>?);

      final jobRes = await _client
          .get(Uri.parse('$baseUrl/api/job'), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 8));

      OctoPrintJob? job;
      if (jobRes.statusCode == 200) {
        final jobJson = jsonDecode(jobRes.body) as Map<String, dynamic>;
        job = _parseJob(jobJson);
      }

      return Success(OctoPrintStatus(state: state, job: job, hotend: hotend, bed: bed));
    } on SocketException {
      return const Success(OctoPrintStatus(state: PrinterState.offline));
    } on http.ClientException {
      return const Success(OctoPrintStatus(state: PrinterState.offline));
    } catch (e) {
      return Failure(AppError(kind: ErrorKind.unknown, message: 'Status error', debugDetail: '$e'));
    }
  }

  Future<Result<List<OctoPrintFile>>> getFiles(String baseUrl, String apiKey) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/files?recursive=true'), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return Failure(AppError(kind: ErrorKind.network, message: 'Files error ${res.statusCode}'));
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final files = _flattenFiles(json['files'] as List<dynamic>? ?? []);
      return Success(files);
    } catch (e) {
      return Failure(AppError(kind: ErrorKind.unknown, message: 'Could not load files', debugDetail: '$e'));
    }
  }

  Future<Result<void>> printFile(String baseUrl, String apiKey, String path) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/files/local/$path'),
            headers: _headers(apiKey),
            body: jsonEncode({'command': 'select', 'print': true}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 204 || res.statusCode == 200) return const Success(null);
      return Failure(AppError(kind: ErrorKind.network, message: 'Print failed ${res.statusCode}'));
    } catch (e) {
      return Failure(AppError(kind: ErrorKind.unknown, message: 'Print error', debugDetail: '$e'));
    }
  }

  Future<Result<void>> _jobCommand(
    String baseUrl,
    String apiKey,
    Map<String, dynamic> body, {
    String path = '/api/job',
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(apiKey),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 204 || res.statusCode == 200) return const Success(null);
      return Failure(AppError(kind: ErrorKind.network, message: 'Command failed ${res.statusCode}'));
    } catch (e) {
      return Failure(AppError(kind: ErrorKind.unknown, message: 'Command error', debugDetail: '$e'));
    }
  }

  Future<Result<void>> pause(String baseUrl, String apiKey) =>
      _jobCommand(baseUrl, apiKey, {'command': 'pause', 'action': 'pause'});

  Future<Result<void>> resume(String baseUrl, String apiKey) =>
      _jobCommand(baseUrl, apiKey, {'command': 'pause', 'action': 'resume'});

  Future<Result<void>> cancel(String baseUrl, String apiKey) =>
      _jobCommand(baseUrl, apiKey, {'command': 'cancel'});

  Future<Result<String>> getVersion(String baseUrl, String apiKey) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/version'), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final v = json['server'] as String? ?? '?';
        return Success('OctoPrint $v');
      }
      return Failure(AppError(kind: ErrorKind.network, message: 'HTTP ${res.statusCode}'));
    } on SocketException {
      return Failure(AppError(kind: ErrorKind.network, message: 'Could not reach OctoPrint'));
    } catch (e) {
      return Failure(AppError(kind: ErrorKind.unknown, message: 'Connection failed', debugDetail: '$e'));
    }
  }

  Future<Result<void>> setToolTemp(String baseUrl, String apiKey, int temp) =>
      _jobCommand(baseUrl, apiKey, {
        'command': 'target',
        'targets': {'tool0': temp},
      }, path: '/api/printer/tool');

  Future<Result<void>> setBedTemp(String baseUrl, String apiKey, int temp) =>
      _jobCommand(baseUrl, apiKey, {
        'command': 'target',
        'target': temp,
      }, path: '/api/printer/bed');

  OctoPrintTemperature? _parseTemp(Map<String, dynamic>? t) {
    if (t == null) return null;
    return OctoPrintTemperature(
      actual: (t['actual'] as num?)?.toDouble() ?? 0,
      target: (t['target'] as num?)?.toDouble() ?? 0,
    );
  }

  PrinterState _parseState(Map<String, dynamic> flags) {
    if (flags['printing'] == true) return PrinterState.printing;
    if (flags['pausing'] == true) return PrinterState.pausing;
    if (flags['paused'] == true) return PrinterState.paused;
    if (flags['cancelling'] == true) return PrinterState.cancelling;
    if (flags['error'] == true) return PrinterState.error;
    if (flags['ready'] == true || flags['operational'] == true) return PrinterState.operational;
    if (flags['closedOrError'] == true) return PrinterState.offline;
    return PrinterState.unknown;
  }

  OctoPrintJob? _parseJob(Map<String, dynamic> json) {
    final file = json['job']?['file'] as Map<String, dynamic>?;
    final name = file?['name'] as String?;
    if (name == null || name.isEmpty) return null;

    final progress = json['progress'] as Map<String, dynamic>? ?? {};
    final completion = (progress['completion'] as num?)?.toDouble() ?? 0.0;
    final printTime = (progress['printTime'] as num?)?.toInt() ?? 0;
    final printTimeLeft = (progress['printTimeLeft'] as num?)?.toInt();

    return OctoPrintJob(
      filename: name,
      completion: completion,
      printTimeSeconds: printTime,
      printTimeLeftSeconds: printTimeLeft,
    );
  }

  List<OctoPrintFile> _flattenFiles(List<dynamic> entries) {
    final result = <OctoPrintFile>[];
    for (final entry in entries) {
      final e = entry as Map<String, dynamic>;
      final type = e['type'] as String? ?? '';
      if (type == 'folder') {
        final children = e['children'] as List<dynamic>? ?? [];
        result.addAll(_flattenFiles(children));
      } else if (type == 'machinecode') {
        final name = e['name'] as String? ?? '';
        final path = e['path'] as String? ?? name;
        final size = (e['size'] as num?)?.toInt();
        final estimatedPrintTime =
            (e['gcodeAnalysis']?['estimatedPrintTime'] as num?)?.toInt();
        if (name.isNotEmpty) {
          result.add(OctoPrintFile(
            name: name,
            path: path,
            sizeBytes: size,
            estimatedPrintTimeSeconds: estimatedPrintTime,
          ));
        }
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  void dispose() => _client.close();
}
