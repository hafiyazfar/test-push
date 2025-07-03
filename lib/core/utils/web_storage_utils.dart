// Minimal web storage utils
library web_storage_utils;

class WebStorageUtils {
  static WebStorageUtils? _instance;
  WebStorageUtils._();
  static Future<WebStorageUtils> get instance async => _instance ??= WebStorageUtils._();
}