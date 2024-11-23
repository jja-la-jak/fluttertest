class LWWRegister<T> {
  final String id;
  List<dynamic> state;

  T get value => state[2];

  LWWRegister(this.id, this.state);

  void set(T value) {
    // Set peer ID to local ID, increment local timestamp, and set value
    state = [id, state[1] + 1, value];
  }

  void merge(List<dynamic> state) {
    var remotePeer = state[0];
    var remoteTimestamp = state[1];
    var localPeer = this.state[0];
    var localTimestamp = this.state[1];

    // Ignore incoming value if local timestamp is greater than remote timestamp
    if (localTimestamp > remoteTimestamp) return;
    // Ignore incoming value if timestamps are the same but local peer ID is greater than remote peer ID
    if (localTimestamp == remoteTimestamp && localPeer.compareTo(remotePeer) > 0) return;
    // Otherwise, overwrite local state with remote state
    this.state = state;
  }
}

