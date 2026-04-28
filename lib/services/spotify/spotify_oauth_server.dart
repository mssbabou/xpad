import 'dart:async';
import 'dart:io';

class SpotifyOAuthServer {
  HttpServer? _server;

  Future<String> waitForCode() async {
    final completer = Completer<String>();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8888);

    _server!.listen((request) async {
      if (request.uri.path == '/callback') {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        const html = '''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Spotify Connected</title>
<style>body{font-family:-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f0f0f5;}
.card{background:#fff;border-radius:20px;padding:40px 48px;text-align:center;box-shadow:0 4px 24px rgba(0,0,0,.08);}
h1{font-size:22px;font-weight:600;color:#18182a;margin:0 0 8px;}
p{font-size:14px;color:#8888a8;margin:0;}</style>
</head>
<body><div class="card"><h1>Connected to Spotify</h1><p>You can close this tab and return to xpad.</p></div></body>
</html>''';

        request.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'text/html; charset=utf-8')
          ..write(html);
        await request.response.close();

        await _server?.close(force: false);
        _server = null;

        if (error != null && !completer.isCompleted) {
          completer.completeError(Exception('Spotify auth error: $error'));
        } else if (code != null && !completer.isCompleted) {
          completer.complete(code);
        } else if (!completer.isCompleted) {
          completer.completeError(Exception('No code in callback'));
        }
      } else {
        request.response
          ..statusCode = 404
          ..write('Not found');
        await request.response.close();
      }
    });

    return completer.future;
  }

  void cancel() {
    _server?.close(force: true);
    _server = null;
  }
}
