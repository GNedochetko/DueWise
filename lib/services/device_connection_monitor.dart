import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/activity_cloud_source.dart';

class DeviceConnectionMonitor implements ConnectionMonitor {
  DeviceConnectionMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;
  bool _available(List<ConnectivityResult> values) =>
      values.any((value) => value != ConnectivityResult.none);
  @override
  Future<bool> check() async =>
      _available(await _connectivity.checkConnectivity());
  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_available).distinct();
}
