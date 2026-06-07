import 'dart:io' as io;
import 'dart:typed_data';

class Socket {
  final io.Socket _socket;
  Socket(this._socket);

  static Future<Socket> connect(String url) async {
    List<String> splitURL = url.split(':');
    io.Socket socket = await io.Socket.connect(
      (await io.InternetAddress.lookup(splitURL[0])).single,
      int.parse(splitURL[1]),
    );
    return Socket(socket);
  }

  void listen(void Function(Uint8List) listener) {
    _socket.listen(listener);
  }

  void add(List<int> data) {
    _socket.add(data);
  }
}
