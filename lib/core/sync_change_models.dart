part of 'sync_models.dart';

class RemoteSyncChanges {
  const RemoteSyncChanges({required this.cursor, required this.changes});

  final String cursor;
  final List<RemoteSyncEvent> changes;

  factory RemoteSyncChanges.fromJson(Map<String, Object?> json) {
    return RemoteSyncChanges(
      cursor: _string(json, 'cursor'),
      changes: _list(json, 'changes', RemoteSyncEvent.fromJson),
    );
  }
}

class RemoteSyncEvent {
  const RemoteSyncEvent({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.payload,
  });

  final String entityType;
  final String entityId;
  final String operation;
  final int revision;
  final Map<String, Object?>? payload;

  factory RemoteSyncEvent.fromJson(Map<String, Object?> json) {
    final payload = json['payload'];
    return RemoteSyncEvent(
      entityType: _string(json, 'entityType'),
      entityId: _string(json, 'entityId'),
      operation: _string(json, 'operation'),
      revision: _int(json, 'revision'),
      payload: payload is Map<String, Object?> ? payload : null,
    );
  }
}

class RemoteSyncMutation {
  const RemoteSyncMutation({
    required this.clientMutationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.baseRevision,
  });

  final String clientMutationId;
  final String entityType;
  final String entityId;
  final String operation;
  final int? baseRevision;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'clientMutationId': clientMutationId,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation,
    'baseRevision': baseRevision,
    'payload': payload,
  };
}

class RemoteSyncPushResponse {
  const RemoteSyncPushResponse({
    required this.applied,
    required this.conflicts,
  });

  final List<Map<String, Object?>> applied;
  final List<Map<String, Object?>> conflicts;

  factory RemoteSyncPushResponse.fromJson(Map<String, Object?> json) {
    return RemoteSyncPushResponse(
      applied: _mapList(json, 'applied'),
      conflicts: _mapList(json, 'conflicts'),
    );
  }
}

class RemoteEntitlementState {
  const RemoteEntitlementState({
    required this.premium,
    required this.lockedFeatures,
  });

  final bool premium;
  final List<String> lockedFeatures;

  factory RemoteEntitlementState.fromJson(Map<String, Object?> json) {
    return RemoteEntitlementState(
      premium: _bool(json, 'premium'),
      lockedFeatures: _stringList(json, 'lockedFeatures'),
    );
  }
}
