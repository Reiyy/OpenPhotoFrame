abstract class ConfigProvider {
  Future<void> load();
  String get activeSourceType;
  Map<String, dynamic> getSourceConfig(String type);
}
