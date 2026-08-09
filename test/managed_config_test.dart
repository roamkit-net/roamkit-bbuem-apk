import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config_keys.dart';

void main() {
  test('fromChannelMap maps UEM keys', () {
    final config = ManagedConfig.fromChannelMap({
      ManagedConfigKeys.deviceExternalId: 'rk_dev_abc',
      ManagedConfigKeys.deviceCredential: 'secret-value',
    });

    expect(config.deviceExternalId, 'rk_dev_abc');
    expect(config.deviceCredential, 'secret-value');
    expect(config.isComplete, isTrue);
  });

  test('empty strings are treated as missing', () {
    final config = ManagedConfig.fromChannelMap({
      ManagedConfigKeys.deviceExternalId: '',
      ManagedConfigKeys.deviceCredential: '  ',
    });

    expect(config.hasDeviceExternalId, isFalse);
    expect(config.deviceCredential, isNull);
    expect(config.hasDeviceCredential, isFalse);
    expect(config.isComplete, isFalse);
  });

  test('missing keys stay null', () {
    final config = ManagedConfig.fromChannelMap(const {});
    expect(config.deviceExternalId, isNull);
    expect(config.deviceCredential, isNull);
    expect(config.isComplete, isFalse);
  });
}
