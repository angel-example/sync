/// Represents a request to publish information to other clients.
abstract class PublishRequest {
  /// The ID of the client sending this request.
  String get clientId;

  /// The name of the event to be sent.
  String get eventName;

  /// The value to be published as an event.
  dynamic get value;

  /// Accept the request, with a response.
  void accept(PublishResponse response);

  /// Deny the request with an error message.
  void reject(String errorMessage);
}

/// A response to a publish request. Informs the caller of how much clients received the event.
class PublishResponse {
  /// The number of unique listeners to whom this event was propogated.
  final int listeners;

  const PublishResponse(this.listeners);
}