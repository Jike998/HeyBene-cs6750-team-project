import 'dart:async';

import 'package:flutter/services.dart';

import 'robot_backend_service.dart';

class AndroidRobotBackendService implements RobotBackendService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.openbothci.robot_app/backend/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.openbothci.robot_app/backend/events',
  );

  final StreamController<RobotBackendSnapshot> _snapshotController =
      StreamController<RobotBackendSnapshot>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  RobotBackendSnapshot _snapshot = RobotBackendSnapshot.initial;
  bool _initialized = false;

  @override
  RobotBackendSnapshot get snapshot => _snapshot;

  @override
  Stream<RobotBackendSnapshot> get snapshotStream => _snapshotController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'initialize',
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
    _initialized = true;
  }

  @override
  Future<List<RobotBackendModel>> listModels() async {
    final response = await _methodChannel.invokeMethod<List<dynamic>>('listModels');
    if (response == null) return const [];
    return response
        .whereType<Map>()
        .map((entry) => RobotBackendModel.fromMap(_stringMap(entry)))
        .toList(growable: false);
  }

  @override
  Future<void> configure({
    required RobotBackendMode mode,
    required RobotBackendComputeDevice device,
    String? modelId,
    String? trackTargetLabel,
  }) async {
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'configure',
      {
        'mode': mode.name,
        'device': device.name,
        'modelId': modelId,
        'trackTargetLabel': trackTargetLabel,
      },
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  @override
  Future<void> startSession() async {
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'startSession',
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  @override
  Future<void> stopSession() async {
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'stopSession',
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  @override
  Future<void> setCollecting(bool value) async {
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setCollecting',
      {'value': value},
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  @override
  Future<void> setTrackingPoint({
    required double x,
    required double y,
    required double viewWidth,
    required double viewHeight,
  }) async {
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setTrackingPoint',
      {
        'x': x,
        'y': y,
        'viewWidth': viewWidth,
        'viewHeight': viewHeight,
      },
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  @override
  Future<void> submitCameraFrame({
    required int width,
    required int height,
    required int sensorOrientation,
    required int timestampMs,
    required List<RobotBackendFramePlane> planes,
  }) async {
    final response = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'submitFrame',
      {
        'width': width,
        'height': height,
        'sensorOrientation': sensorOrientation,
        'timestampMs': timestampMs,
        'planes': planes.map((plane) => plane.toMap()).toList(growable: false),
      },
    );
    final mapped = _stringMap(response);
    if (mapped.isNotEmpty) {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  @override
  Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _initialized = false;
    _snapshot = RobotBackendSnapshot.initial;
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final mapped = _stringMap(event);
    final eventType = mapped['event']?.toString();
    if (eventType == 'snapshot') {
      _updateSnapshot(RobotBackendSnapshot.fromMap(mapped));
    }
  }

  void _updateSnapshot(RobotBackendSnapshot next) {
    _snapshot = next;
    _snapshotController.add(next);
  }

  Map<String, dynamic> _stringMap(Map<dynamic, dynamic>? source) {
    if (source == null) return const {};
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}
