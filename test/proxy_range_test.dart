import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

class _Matcher extends UrlMatcherDefault {
  @override
  bool matchMp4(Uri uri) => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('invalid ranges and HEAD serve the whole resource', () async {
    final temp = await Directory.systemTemp.createTemp('fvc_range_test');
    final data = List<int>.generate(100000, (i) => i % 251);

    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 18091);
    origin.listen((req) async {
      final range = req.headers.value('range');
      if (req.method == 'HEAD') {
        req.response.headers.set('Content-Type', 'video/mp4');
        req.response.headers.set('Accept-Ranges', 'bytes');
        req.response.contentLength = data.length;
        await req.response.close();
        return;
      }
      final match = range == null
          ? null
          : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
      if (match != null) {
        final startText = match.group(1)!;
        final endText = match.group(2)!;
        var start = startText.isEmpty
            ? data.length - int.parse(endText)
            : int.parse(startText);
        if (start < 0) start = 0;
        final rawEnd = startText.isEmpty || endText.isEmpty
            ? data.length - 1
            : int.parse(endText);
        final end = rawEnd >= data.length ? data.length - 1 : rawEnd;
        req.response.statusCode = 206;
        req.response.headers.set('Content-Type', 'video/mp4');
        req.response.headers.set('Accept-Ranges', 'bytes');
        req.response.headers.set(
          'Content-Range',
          'bytes $start-$end/${data.length}',
        );
        req.response.contentLength = end - start + 1;
        req.response.add(data.sublist(start, end + 1));
        await req.response.close();
        return;
      }
      req.response.headers.set('Content-Type', 'video/mp4');
      req.response.headers.set('Accept-Ranges', 'bytes');
      req.response.contentLength = data.length;
      req.response.add(data);
      await req.response.close();
    });

    await VideoProxy.init(
      port: 20261,
      segmentSizeInBytes: 1024 * 1024,
      firstSegmentSizeInBytes: 256 * 1024,
      cacheDir: temp.path,
      urlMatcher: _Matcher(),
    );

    final originB64 = base64Url.encode(utf8.encode('http://127.0.0.1:18091'));
    final proxyUrl = Uri.parse(
      'http://127.0.0.1:20261/video.mp4?origin=$originB64',
    );

    Future<(int, int, int)> request({String? range, bool head = false}) async {
      final client = HttpClient();
      try {
        final req = head
            ? await client.headUrl(proxyUrl)
            : await client.getUrl(proxyUrl);
        if (range != null) req.headers.set('range', range);
        final resp = await req.close().timeout(const Duration(seconds: 20));
        final body = await resp.fold<List<int>>([], (p, e) => p..addAll(e));
        return (
          resp.statusCode,
          int.parse(resp.headers.value('content-length') ?? '-1'),
          body.length,
        );
      } finally {
        client.close(force: true);
      }
    }

    expect(await request(range: 'bytes=-'), (200, data.length, data.length));
    expect(await request(range: '-'), (200, data.length, data.length));
    expect(await request(), (200, data.length, data.length));
    expect(await request(head: true), (200, data.length, 0));
    expect(await request(range: 'bytes=0-'), (206, data.length, data.length));
    expect(await request(range: 'bytes=0-1'), (206, 2, 2));
    expect(await request(range: 'bytes=-100'), (206, 100, 100));
    expect(await request(range: 'bytes=99000-99999'), (206, 1000, 1000));
    // Unsatisfiable ranges fall back to the whole resource instead of a
    // malformed 206 that breaks Windows Media Foundation.
    expect(await request(range: 'bytes=200000-'), (200, data.length, data.length));

    await origin.close(force: true);
    await temp.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
