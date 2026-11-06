abstract interface class UciTransport {
  /// Every line the engine prints.
  Stream<String> get lines;

  void send(String command);
  Future<void> dispose();
}
