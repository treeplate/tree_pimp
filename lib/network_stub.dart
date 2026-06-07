import 'dart:typed_data';

class Socket {
  static Future<Socket> connect(String url) async {
    throw UnsupportedError('Socket.connect');
  }

  void listen(void Function(Uint8List) listener) {
    throw UnsupportedError('Socket.listen');
  }
  void add(List<int> data) {
    throw UnsupportedError('Socket.add');
  }
}
