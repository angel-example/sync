import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:uuid/uuid.dart';
import '../../pub_sub.dart';

/// A [Client] implementation that communicates via JSON RPC 2.0.
class JsonRpc2Client extends Client {
  final Map<String, Completer<Map>> _requests = {};
  final List<_JsonRpc2ClientSubscription> _subscriptions = [];
  final Uuid _uuid = new Uuid();

  json_rpc_2.Peer _peer;

  /// The ID of the client we are authenticating as.
  final String clientId;

  JsonRpc2Client(this.clientId, StreamChannel<String> channel) {
    _peer = new json_rpc_2.Peer(channel);

    _peer.registerMethod('event', (json_rpc_2.Parameters params) {
      var eventName = params['event_name'].asString,
          event = params['value'].value;
      for (var s in _subscriptions.where((s) => s.eventName == eventName)) {
        if (!s._stream.isClosed) s._stream.add(event);
      }
    });

    _peer.registerFallback((json_rpc_2.Parameters params) {
      var c = _requests.remove(params.method);

      if (c == null)
        throw new json_rpc_2.RpcException.methodNotFound(params.method);
      else {
        var data = params.asMap;

        if (data['status'] is! bool) {
          c.completeError(
              new FormatException('The server sent an invalid response.'));
        } else if (!data['status']) {
          c.completeError(new PubSubException(data['error_message']
                  ?.toString() ??
              'The server sent a failure response, but did not provide an error message.'));
        }  else {
          c.complete(data);
        }
      }
    });

    _peer.listen();
  }

  @override
  Future publish(String eventName, value) {
    var c = new Completer<Map>();
    var requestId = _uuid.v4();
    _requests[requestId] = c;
    _peer.sendNotification('publish', {
      'request_id': requestId,
      'client_id': clientId,
      'event_name': eventName,
      'value': value
    });
    return c.future;
  }

  @override
  Future<ClientSubscription> subscribe(String eventName) {
    var c = new Completer<Map>();
    var requestId = _uuid.v4();
    _requests[requestId] = c;
    _peer.sendNotification('subscribe', {
      'request_id': requestId,
      'client_id': clientId,
      'event_name': eventName
    });
    return c.future.then<ClientSubscription>((result) {
      var s = new _JsonRpc2ClientSubscription(
          eventName, result['subscription_id'], this);
      _subscriptions.add(s);
      return s;
    });
  }

  @override
  Future close() {
    if (_peer?.isClosed != true) _peer.close();

    for (var c in _requests.values) {
      if (!c.isCompleted) {
        c.completeError(new StateError(
            'The client was closed before the server responded to this request.'));
      }
    }

    for (var s in _subscriptions) s._close();

    _requests.clear();
    return new Future.value();
  }
}

class _JsonRpc2ClientSubscription extends ClientSubscription {
  final StreamController _stream = new StreamController();
  final String eventName, id;
  final JsonRpc2Client client;

  _JsonRpc2ClientSubscription(this.eventName, this.id, this.client);

  void _close() {
    if (!_stream.isClosed) _stream.close();
  }

  @override
  StreamSubscription listen(void onData(event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return _stream.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future unsubscribe() {
    var c = new Completer<Map>();
    var requestId = client._uuid.v4();
    client._requests[requestId] = c;
    client._peer.sendNotification('unsubscribe', {
      'request_id': requestId,
      'client_id': client.clientId,
      'subscription_id': id
    });

    return c.future.then((_) {
      _close();
    });
  }
}
