import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

class Socket {
  final WebSocket _webSocket;
  Socket(this._webSocket);

  static Future<Socket> connect(String url) async {
    WebSocket webSocket = WebSocket(url);
    await webSocket.onOpen.first;
    return Socket(webSocket);
  }

  void listen(void Function(Uint8List) listener) {
    _webSocket.onMessage.map((MessageEvent message) => message.data).listen((
      message,
    ) {
      if (message.isA<JSString>()) {
        throw FormatException('got text packet from server');
      } else {
        JSPromise<JSArrayBuffer> promise = (message as Blob).arrayBuffer();
        promise.toDart.then((JSArrayBuffer arrayBuffer) {
          listener(arrayBuffer.toDart.asUint8List());
        });
      }
    });
  }

  void add(List<int> data) {
    _webSocket.send(Blob(data.map<JSAny>((e) => e.toJS).toList().toJS));
  }
}
