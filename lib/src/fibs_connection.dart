import 'dart:async';
import 'dart:typed_data';
import 'package:fibscli_lib/src/cookie_monster.dart';
import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/status.dart' as wsStatus;

enum _LoginState {
  prelogin,
  sentcred,
  postlogin,
}

class FibsConnection {
  static final _fibsVersion = '1008';
  final String proxy;
  final int port;
  final _streamController = StreamController<CookieMessage>();
  IOWebSocketChannel? _channel;
  final _monster = CookieMonster();
  Completer<FibsCookie>? _loginCompleter;
  _LoginState? _loginState;

  FibsConnection(this.proxy, this.port);

  bool get connected => _channel != null;
  Stream<CookieMessage> get stream => _streamController.stream;

  Future<FibsCookie> login(String user, String pass) {
    assert(!connected);

    _channel = IOWebSocketChannel.connect('ws://$proxy:$port');

    _channel!.stream.listen(
      (dynamic bytes) {
        final message = String.fromCharCodes(bytes as Uint8List);
        print('stream.message: $message');
        final cms = _receive(message).toList();

        switch (_loginState) {
          case _LoginState.prelogin:
            // wait for login prompt
            final expecting = [FibsCookie.FIBS_LoginPrompt];
            final found = cms
                .map((cm) => cm.cookie)
                .where((c) => expecting.contains(c))
                .toList();
            if (found.isEmpty) return; // wait for next batch

            // send credentials
            send('login flutter-fibs $_fibsVersion $user $pass');
            _loginState = _LoginState.sentcred;
            break;

          case _LoginState.sentcred:
            // wait for login prompt
            final expecting = [
              FibsCookie.CLIP_WELCOME,
              FibsCookie.FIBS_FailedLogin,
              FibsCookie.FIBS_LoginPrompt
            ];
            final found = cms
                .map((cm) => cm.cookie)
                .where((c) => expecting.contains(c))
                .toList();
            if (found.isEmpty) return; // wait for next batch

            // complete the login
            final cookie = found.single;
            _loginCompleter!.complete(cookie);
            _loginCompleter = null;
            _loginState = _LoginState.postlogin;
            break;

          case _LoginState.postlogin:
          case null:
            break;
        }
      },
      onDone: () {
        print('stream.onDone');
        close();
      },
      onError: (Object error) {
        print('stream.onError: $error');
        close();
      },
      cancelOnError: false,
    );

    _loginState = _LoginState.prelogin;
    _loginCompleter = Completer<FibsCookie>();
    return _loginCompleter!.future;
  }

  void send(String s) {
    assert(connected);
    assert(!s.endsWith('\n'));
    print('SEND: $s');
    _channel!.sink.add('$s\n');
  }

  Iterable<CookieMessage> _receive(String message) sync* {
    print('RECEIVE: $message');

    final lines = message.split('\n');
    for (final line in lines) {
      final cm = _monster.eatCookie(line.replaceAll('\r', ''));
      _streamController.add(cm);
      yield cm;
    }
  }

  void close() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      _streamController.close();
    }
  }
}
