import 'dart:async';
import 'package:pub_sub/pub_sub.dart';
import 'package:pub_sub/isolate.dart';
import 'package:test/test.dart';

main() {
  Server server;
  Client client1, client2, client3;
  IsolateAdapter adapter;

  setUp(() async {
    adapter = new IsolateAdapter();
    client1 = new IsolateClient(
        'isolate_test::secret', adapter.receivePort.sendPort);
    client2 = new IsolateClient(
        'isolate_test::secret2', adapter.receivePort.sendPort);
    client3 = new IsolateClient(
        'isolate_test::secret3', adapter.receivePort.sendPort);

    server = new Server([adapter])
      ..registerClient(const ClientInfo('isolate_test::secret'))
      ..registerClient(const ClientInfo('isolate_test::secret2'))
      ..registerClient(const ClientInfo('isolate_test::secret3'))
      ..registerClient(
          const ClientInfo('isolate_test::no_publish', canPublish: false))
      ..registerClient(
          const ClientInfo('isolate_test::no_subscribe', canSubscribe: false))
      ..start();

    var sub = await client3.subscribe('foo');
    sub.listen((data) {
      print('Client3 caught foo: $data');
    });
  });

  tearDown(() {
    Future.wait(
        [server.close(), client1.close(), client2.close(), client3.close()]);
  });

  test('subscribers receive published events', () async {
    var sub = await client2.subscribe('foo');
    await client1.publish('foo', 'bar');
    expect(await sub.first, 'bar');
  });

  test('subscribers are not sent their own events', () async {
    var sub = await client1.subscribe('foo');
    await client1.publish('foo', '<this should never be sent to client1, because client1 sent it.>');
    await sub.unsubscribe();
    expect(await sub.isEmpty, isTrue);
  });

  test('can unsubscribe', () async {
    var sub = await client2.subscribe('foo');
    await client1.publish('foo', 'bar');
    await sub.unsubscribe();
    await client1.publish('foo', '<client2 will not catch this!>');
    expect(await sub.length, 1);
  });

  group('isolate_server', () {
    test('reject unknown client id', () async {
      try {
        var client = new IsolateClient(
            'isolate_test::invalid', adapter.receivePort.sendPort);
        await client.publish('foo', 'bar');
        throw 'Invalid client ID\'s should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test('reject unprivileged publish', () async {
      try {
        var client = new IsolateClient(
            'isolate_test::no_publish', adapter.receivePort.sendPort);
        await client.publish('foo', 'bar');
        throw 'Unprivileged publishes should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test('reject unprivileged subscribe', () async {
      try {
        var client = new IsolateClient(
            'isolate_test::no_subscribe', adapter.receivePort.sendPort);
        await client.subscribe('foo');
        throw 'Unprivileged subscribes should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });
  });
}
