class RelayEndpointPolicy {
  const RelayEndpointPolicy._();

  static Uri parse(String raw, {bool allowInsecure = false}) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Укажите базовый адрес relay без пути.');
    }
    if (uri.scheme != 'https' && !(allowInsecure && uri.scheme == 'http')) {
      throw const FormatException('Для relay требуется HTTPS.');
    }
    return uri.replace(path: '');
  }
}
