import 'dart:async';
import 'publish.dart';
import 'subscription.dart';

/// Adapts an abstract medium to serve the `pub_sub` RPC protocol.
abstract class Adapter {
  /// Fires an event whenever a client tries to publish data.
  Stream<PublishRequest> get onPublish;

  /// Fires whenever a client tries to subscribe to an event.
  Stream<SubscriptionRequest> get onSubscribe;

  /// Fires whenever a client cancels a subscription.
  Stream<UnsubscriptionRequest> get onUnsubscribe;

  /// Disposes of this adapter.
  Future close();

  /// Start listening for incoming clients.
  void start();
}