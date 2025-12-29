import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class BackendClient {
  BackendClient(this.baseUrl);

  final String baseUrl;

  Stream<SseEvent> streamCorrect({
    required String text,
    required String lang,
    required String platform,
  }) {
    final controller = StreamController<SseEvent>();
    final client = http.Client();
    StreamSubscription<String>? subscription;

    controller
      ..onListen = () async {
        try {
          final uri = Uri.parse(baseUrl).resolve('/v1/correct/stream');
          final request = http.Request('POST', uri);
          request.headers['Content-Type'] = 'application/json';
          request.headers['Accept'] = 'text/event-stream';
          request.body = jsonEncode({
            'text': text,
            'lang': lang,
            'client': {'platform': platform, 'version': 'flutter-0.1'},
          });

          final response = await client.send(request);
          if (response.statusCode != 200) {
            throw Exception('stream_failed:${response.statusCode}');
          }

          var buffer = '';
          var currentEvent = 'message';
          var currentData = '';

          subscription = response.stream
              .transform(utf8.decoder)
              .listen(
                (chunk) {
                  buffer += chunk;
                  while (buffer.contains('\n')) {
                    final index = buffer.indexOf('\n');
                    final line = buffer.substring(0, index).trimRight();
                    buffer = buffer.substring(index + 1);

                    if (line.isEmpty) {
                      if (currentData.isNotEmpty) {
                        final data =
                            jsonDecode(currentData) as Map<String, dynamic>;
                        controller.add(SseEvent(currentEvent, data));
                      }
                      currentEvent = 'message';
                      currentData = '';
                      continue;
                    }

                    if (line.startsWith('event:')) {
                      currentEvent = line.replaceFirst('event:', '').trim();
                    } else if (line.startsWith('data:')) {
                      final dataPart = line.replaceFirst('data:', '').trim();
                      if (currentData.isNotEmpty) {
                        currentData += '\n';
                      }
                      currentData += dataPart;
                    }
                  }
                },
                onDone: controller.close,
                onError: (Object err, StackTrace stack) {
                  controller.addError(err, stack);
                },
              );
        } on Object catch (err, stack) {
          client.close();
          controller.addError(err, stack);
          await controller.close();
        }
      }
      ..onCancel = () async {
        await subscription?.cancel();
        client.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      };

    return controller.stream;
  }
}
