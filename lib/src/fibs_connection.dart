import 'package:socket_io_client/socket_io_client.dart' as ws;

class FibsConnection {
  final String proxy;
  final int port;
  final void Function(String msg) onMessage;
  ws.Socket _socket;
  var _loggedIn = false;
  FibsConnection(this.proxy, this.port, this.onMessage);

  bool get connected => _socket != null;

  void login(String user, String pass) {
    assert(!connected);

    _socket = ws.io('ws://$proxy:$port', <String, dynamic>{
      'transports': ['websocket'],
      'forceNew': true,
    });

    _socket.on('connect', (data) {
      _receive('connect', data);
      _socket.emit('stream', '\n');
    });

    _socket.on('stream', (bytes) {
      final s = String.fromCharCodes(bytes);
      if (!_loggedIn) {
        if (s.endsWith('login: ')) {
          send(user);
        } else if (s.endsWith('Password: ') /* JIBS */ || s.endsWith('password: ') /*FIBS*/) {
          send(pass);
          // TODO: what if it fails?
          // TODO: notify client
          _loggedIn = true;
        } else {
          _receive('stream', s);
        }
      } else {
        _receive('stream', s);
      }
    });

    _socket.on('status', (status) {
      _receive('status', status);
      print('"$status"');
      if (status == 'Telnet disconnected.\n') close();
    });
  }

  void send(String s) {
    assert(connected);
    assert(!s.endsWith('\n'));
    _socket.emit('stream', '$s\n');
  }

  void _receive(String event, String message) {
    print(message == null || message.isEmpty ? event : '$event: $message');
    // TODO: turn into cookie messages and notify the client
  }

  void close() {
    print('close');
    assert(_socket != null);
    _socket.close();
    _socket = null;
    // TODO: notify client
  }
}

// import 'dart:collection';
// import 'package:logging/logging.dart';
// import 'package:socket_io_client/socket_io_client.dart' as ws;
// import 'package:meta/meta.dart';

// class CookieMonster {
//   CookieMessage eatCookie(String l) {}
// }

// // FIBS only takes one command at a time, so we need to implement queueing behavior
// // or commands get silently dropped
// // class CommandQueue {
// //   var _awaitingResponse = false;
// //   final _cmdQueue = Queue<String>();
// //   ws.Socket _socket;

// //   Future connect(String host, int port) async {
// //     assert(_socket == null);
// //     assert(_socket == null);

// //     _socket = ws.io('ws://localhost:8080', <String, dynamic>{
// //       'transports': ['websocket'],
// //       'forceNew': true,
// //     });

// //     _socket.on('connect', (data) {
// //       // _receive('connect', data);
// //       _socket.emit('stream', '\n');
// //     });

// //     _socket.on('stream', (bytes) {
// //       final s = String.fromCharCodes(bytes);
// //       // _receive('stream', s);
// //     });

// //     _socket.on('status', (status) {
// //       // _receive('status', status);
// //       if (status == 'Telnet disconnected.\n') close();
// //     });
// //   }

// //   Future send(String cmd) async {
// //     if (cmd.contains('\n')) throw FormatException('cmd cannot contain linefeed');

// //     // when we get a command, queue it and check if we can send it
// //     Logger.root.log(Level.FINE, 'queueing: $cmd');
// //     _cmdQueue.addLast(cmd);
// //     await checkSend();
// //   }

// //   Future checkSend() async {
// //     // only process a queued command if we're not awaiting a response to a previous command
// //     if (_awaitingResponse || _cmdQueue.isNotEmpty) return;
// //     final cmd = _cmdQueue.removeFirst();
// //     _awaitingResponse = true;
// //     Logger.root.log(Level.FINE, 'sending: $cmd');
// //     await write(cmd + "\n");
// //   }

// //   void _receive(String msg) async {
// //     // when we get a response to a previous command, send a queued command
// //     _awaitingResponse = false;
// //     await checkSend();
// //   }

// //   Future write(String s) async {
// //     if (_socket == null) throw Exception('not connected');
// //     _socket.emit('stream', s);
// //   }

// //   // clean up, clean up, everybody do their share...
// //   void close() {
// //     if (_socket != null) {
// //       _socket.close();
// //       _socket = null;
// //     }
// //   }
// // }

// class CookieMessage {
//   final FibsCookie cookie = null; // TODO
// }

// class FibsCookie {
//   final CookieMessage cookie;
//   FibsCookie(this.cookie);
//   static final FIBS_LoginPrompt = CookieMessage(); // TODO
//   static final CLIP_MOTD_END = CookieMessage();
//   static final FIBS_FailedLogin = CookieMessage();
// }

// class FibsSession {
//   static final _fibsVersion = '1008';
//   final String host;
//   final int port;
//   final _monster = CookieMonster();
//   ws.Socket _socket;

//   FibsSession({@required this.host, @required this.port});

//   void _connect(String host, int port) {
//     assert(_socket == null);
//     assert(_socket == null);

//     _socket = ws.io('ws://localhost:8080', <String, dynamic>{
//       'transports': ['websocket'],
//       'forceNew': true,
//     });

//     _socket.on('connect', (data) {
//       _receive('connect', data);
//       _socket.emit('stream', '\n');
//     });

//     _socket.on('stream', (bytes) {
//       final s = String.fromCharCodes(bytes);
//       _receive('stream', s);
//     });

//     _socket.on('status', (status) {
//       _receive('status', status);
//       if (status == 'Telnet disconnected.\n') close();
//     });
//   }

//   Future send(String cmd) async {
//     if (_socket == null) throw Exception('not connected');
//     if (cmd.contains('\n')) throw FormatException('cmd cannot contain linefeed');
//     _socket.emit('stream', cmd);
//   }

//   Future<List<CookieMessage>> login(String user, String password) async {
//     _connect(host, port);
//     final messages = <CookieMessage>[];
//     messages.addAll(await expect([FibsCookie(FibsCookie.FIBS_LoginPrompt)]));
//     await send('login dotnetcli $_fibsVersion $user $password');
//     messages.addAll(await expect([FibsCookie(FibsCookie.CLIP_MOTD_END), FibsCookie(FibsCookie.FIBS_FailedLogin)]));
//     if (messages.map((m) => m.cookie).contains(FibsCookie.FIBS_FailedLogin)) {
//       throw FailedLoginException(user);
//     }
//     return messages;
//   }

//   void _receive(String event, String msg) {
//     if (event != 'stream') return;

//     var lines = msg.split("\r\n");
//     final cms = lines.map((l) => _monster.eatCookie(l));
//     // TODO: notify client
//   }

//   Future<List<CookieMessage>> expect(List<FibsCookie> cookies) async {
//     var allMessages = <CookieMessage>[];
//     while (true) {
//       final s = await queue.read();
//       final someMessages = process(s);
//       allMessages.addAll(someMessages);
//       if (someMessages.any((cm) => cookies.contains(cm.cookie))) return allMessages;
//     }

//     // I had such low expectations...
//     // throw Exception($"None of these cookies found: {String.Join(", ", cookies)}");
//   }

//   // // clean up, clean up, everybody do their share...
//   void close() {
//     if (queue != null) {
//       queue.close();
//       queue = null;
//     }
//   }
// }

// class FailedLoginException implements Exception {
//   FailedLoginException(String user,
//       {Exception innerException}); // : base($"failed to login as {user}", innerException) {
// }
