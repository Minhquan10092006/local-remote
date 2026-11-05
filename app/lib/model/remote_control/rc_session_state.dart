enum RcHostStatus {
  idle,
  listening,
  awaitingApproval,
  activeSession,
  lockedOut,
}

enum RcClientStatus {
  disconnected,
  discovering,
  connecting,
  awaitingHostApproval,
  connected,
  error,
}

