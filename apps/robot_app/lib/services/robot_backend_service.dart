import 'dart:async';
import 'dart:typed_data';

enum RobotBackendMode { drive, auto, track }

enum RobotBackendComputeDevice { cpu, gpu, nnapi }

enum RobotBackendModelKind { autopilot, detector }

class RobotBackendModel {
  const RobotBackendModel({
    required this.id,
    required this.label,
    required this.kind,
    required this.source,
    required this.inputWidth,
    required this.inputHeight,
    this.assetPath,
    this.remoteUrl,
    this.labelAssetPath,
    this.assetAvailable = false,
  });

  final String id;
  final String label;
  final RobotBackendModelKind kind;
  final String source;
  final int inputWidth;
  final int inputHeight;
  final String? assetPath;
  final String? remoteUrl;
  final String? labelAssetPath;
  final bool assetAvailable;

  factory RobotBackendModel.fromMap(Map<String, dynamic> map) {
    return RobotBackendModel(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      kind: _modelKindFromName(map['kind']?.toString()),
      source: map['source']?.toString() ?? 'unknown',
      inputWidth: (map['inputWidth'] as num?)?.toInt() ?? 0,
      inputHeight: (map['inputHeight'] as num?)?.toInt() ?? 0,
      assetPath: map['assetPath']?.toString(),
      remoteUrl: map['remoteUrl']?.toString(),
      labelAssetPath: map['labelAssetPath']?.toString(),
      assetAvailable: map['assetAvailable'] == true,
    );
  }
}

class RobotBackendFramePlane {
  const RobotBackendFramePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
  final int? width;
  final int? height;

  Map<String, dynamic> toMap() {
    return {
      'bytes': bytes,
      'bytesPerRow': bytesPerRow,
      'bytesPerPixel': bytesPerPixel,
      'width': width,
      'height': height,
    };
  }
}

class RobotBackendSnapshot {
  const RobotBackendSnapshot({
    required this.initialized,
    required this.active,
    required this.mode,
    required this.device,
    required this.modelConfigured,
    required this.trackingTargetConfigured,
    required this.frameWidth,
    required this.frameHeight,
    required this.framesProcessed,
    required this.framesPerSecond,
    required this.lastFrameTimestampMs,
    required this.lastInferenceMs,
    required this.status,
    required this.suggestedLeft,
    required this.suggestedRight,
    required this.collecting,
    required this.sampleCount,
    this.activeModelId,
    this.detectionLabel,
    this.detectionScore,
    this.collectionSessionPath,
    this.previewFrameBase64,
  });

  final bool initialized;
  final bool active;
  final RobotBackendMode mode;
  final RobotBackendComputeDevice device;
  final bool modelConfigured;
  final bool trackingTargetConfigured;
  final int frameWidth;
  final int frameHeight;
  final int framesProcessed;
  final double framesPerSecond;
  final int lastFrameTimestampMs;
  final int lastInferenceMs;
  final String status;
  final double suggestedLeft;
  final double suggestedRight;
  final bool collecting;
  final int sampleCount;
  final String? activeModelId;
  final String? detectionLabel;
  final double? detectionScore;
  final String? collectionSessionPath;
  final String? previewFrameBase64;

  static const initial = RobotBackendSnapshot(
    initialized: false,
    active: false,
    mode: RobotBackendMode.drive,
    device: RobotBackendComputeDevice.cpu,
    modelConfigured: false,
    trackingTargetConfigured: false,
    frameWidth: 0,
    frameHeight: 0,
    framesProcessed: 0,
    framesPerSecond: 0,
    lastFrameTimestampMs: 0,
    lastInferenceMs: 0,
    status: 'Backend idle',
    suggestedLeft: 0,
    suggestedRight: 0,
    collecting: false,
    sampleCount: 0,
    activeModelId: null,
    detectionLabel: null,
    detectionScore: null,
    collectionSessionPath: null,
    previewFrameBase64: null,
  );

  factory RobotBackendSnapshot.fromMap(Map<String, dynamic> map) {
    return RobotBackendSnapshot(
      initialized: map['initialized'] == true,
      active: map['active'] == true,
      mode: _modeFromName(map['mode']?.toString()),
      device: _deviceFromName(map['device']?.toString()),
      modelConfigured: map['modelConfigured'] == true,
      trackingTargetConfigured: map['trackingTargetConfigured'] == true,
      frameWidth: (map['frameWidth'] as num?)?.toInt() ?? 0,
      frameHeight: (map['frameHeight'] as num?)?.toInt() ?? 0,
      framesProcessed: (map['framesProcessed'] as num?)?.toInt() ?? 0,
      framesPerSecond: (map['framesPerSecond'] as num?)?.toDouble() ?? 0,
      lastFrameTimestampMs: (map['lastFrameTimestampMs'] as num?)?.toInt() ?? 0,
      lastInferenceMs: (map['lastInferenceMs'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'Backend idle',
      suggestedLeft: (map['suggestedLeft'] as num?)?.toDouble() ?? 0,
      suggestedRight: (map['suggestedRight'] as num?)?.toDouble() ?? 0,
      collecting: map['collecting'] == true,
      sampleCount: (map['sampleCount'] as num?)?.toInt() ?? 0,
      activeModelId: map['activeModelId']?.toString(),
      detectionLabel: map['detectionLabel']?.toString(),
      detectionScore: (map['detectionScore'] as num?)?.toDouble(),
      collectionSessionPath: map['collectionSessionPath']?.toString(),
      previewFrameBase64: map['previewFrameBase64']?.toString(),
    );
  }
}

abstract class RobotBackendService {
  RobotBackendSnapshot get snapshot;
  Stream<RobotBackendSnapshot> get snapshotStream;

  Future<void> initialize();
  Future<List<RobotBackendModel>> listModels();
  Future<void> configure({
    required RobotBackendMode mode,
    required RobotBackendComputeDevice device,
    String? modelId,
    String? trackTargetLabel,
  });
  Future<void> startSession();
  Future<void> stopSession();
  Future<void> setCollecting(bool value);
  Future<void> setTrackingPoint({
    required double x,
    required double y,
    required double viewWidth,
    required double viewHeight,
  });
  Future<void> submitCameraFrame({
    required int width,
    required int height,
    required int sensorOrientation,
    required int timestampMs,
    required List<RobotBackendFramePlane> planes,
  });
  Future<void> dispose();
}

RobotBackendMode _modeFromName(String? value) {
  return switch (value) {
    'auto' => RobotBackendMode.auto,
    'track' => RobotBackendMode.track,
    _ => RobotBackendMode.drive,
  };
}

RobotBackendComputeDevice _deviceFromName(String? value) {
  return switch (value) {
    'gpu' => RobotBackendComputeDevice.gpu,
    'nnapi' => RobotBackendComputeDevice.nnapi,
    _ => RobotBackendComputeDevice.cpu,
  };
}

RobotBackendModelKind _modelKindFromName(String? value) {
  return switch (value) {
    'detector' => RobotBackendModelKind.detector,
    _ => RobotBackendModelKind.autopilot,
  };
}
