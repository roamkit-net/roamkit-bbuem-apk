import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/api/device_status.dart';
import 'package:roamkit_device/api/device_status_errors.dart';
import 'package:roamkit_device/status/menu_formatters.dart';
import 'package:roamkit_device/status/operational_status_view.dart';
import 'package:roamkit_device/status/remaining_parser.dart';
import 'package:roamkit_device/managed_config/managed_config.dart';

DeviceStatus _status({
  String esimStatus = 'in_use',
  String? dataRemaining = '12 MB',
  DateTime? expiresAt,
  bool expiryMalformed = false,
  String bindingStatus = 'active',
  bool autoTopup = true,
  DateTime? checkedAt,
}) {
  return DeviceStatus(
    deviceExternalId: 'dev-1',
    bindingStatus: bindingStatus,
    esim: DeviceStatusEsim(id: 1, iccid: '8900424101001825931', status: esimStatus),
    usage: DeviceStatusUsage(
      dataRemaining: dataRemaining,
      dataUsed: '1 MB',
      expiresAt: expiresAt,
      expiryMalformed: expiryMalformed,
    ),
    autoTopup: DeviceStatusAutoTopup(enabled: autoTopup),
    checkedAt: checkedAt ?? DateTime.utc(2026, 8, 9, 14, 21),
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 9, 12, 0);

  group('parseDataRemaining', () {
    test('locked remaining cases', () {
      expect(parseDataRemaining('unlimited').isUsable, isTrue);
      expect(parseDataRemaining('Unlimited').display, 'Unlimited');
      expect(parseDataRemaining(' UNLIMITED ').isUsable, isTrue);
      expect(parseDataRemaining('512 MB').isUsable, isTrue);
      expect(parseDataRemaining('1.2 GB').isUsable, isTrue);
      expect(parseDataRemaining('0 MB').isUsable, isFalse);
      expect(parseDataRemaining('0 GB').isUsable, isFalse);
      expect(parseDataRemaining(null).isUsable, isFalse);
      expect(parseDataRemaining('').isUsable, isFalse);
      expect(parseDataRemaining('unknown').isUsable, isFalse);
      expect(parseDataRemaining('512').isUsable, isFalse);
      expect(parseDataRemaining('-1 GB').isUsable, isFalse);
    });
  });

  group('evaluateOperationalView', () {
    test('green for in_use with remaining and future expiry', () {
      final view = evaluateOperationalView(
        _status(expiresAt: DateTime.utc(2026, 9, 1)),
        now: now,
      );
      expect(view.surface, StatusSurface.green);
      expect(view.heroLabel, 'ACTIVE');
      expect(view.isSuccessSnapshot, isTrue);
    });

    test('green for activated unlimited with null expiry', () {
      final view = evaluateOperationalView(
        _status(
          esimStatus: 'activated',
          dataRemaining: 'unlimited',
          expiresAt: null,
        ),
        now: now,
      );
      expect(view.surface, StatusSurface.green);
      expect(view.heroLabel, 'ACTIVE');
      expect(view.expiresDisplay, '—');
    });

    test('green for remaining with null expiry', () {
      final view = evaluateOperationalView(
        _status(dataRemaining: '512 MB', expiresAt: null),
        now: now,
      );
      expect(view.surface, StatusSurface.green);
      expect(view.heroLabel, 'ACTIVE');
    });

    test('expiresAt equal now is EXPIRED', () {
      final view = evaluateOperationalView(
        _status(
          dataRemaining: 'unlimited',
          expiresAt: now,
        ),
        now: now,
      );
      expect(view.surface, StatusSurface.red);
      expect(view.heroLabel, 'EXPIRED');
    });

    test('past expiresAt is EXPIRED even when unlimited', () {
      final view = evaluateOperationalView(
        _status(
          dataRemaining: 'unlimited',
          expiresAt: DateTime.utc(2026, 8, 1),
        ),
        now: now,
      );
      expect(view.surface, StatusSurface.red);
      expect(view.heroLabel, 'EXPIRED');
    });

    test('null remaining is success RED NO DATA', () {
      final view = evaluateOperationalView(
        _status(dataRemaining: null, expiresAt: DateTime.utc(2026, 9, 1)),
        now: now,
      );
      expect(view.surface, StatusSurface.red);
      expect(view.heroLabel, 'NO DATA');
      expect(view.isSuccessSnapshot, isTrue);
    });

    test('zero MB is success RED NO DATA', () {
      final view = evaluateOperationalView(
        _status(dataRemaining: '0 MB', expiresAt: DateTime.utc(2026, 9, 1)),
        now: now,
      );
      expect(view.surface, StatusSurface.red);
      expect(view.heroLabel, 'NO DATA');
      expect(view.isSuccessSnapshot, isTrue);
    });

    test('exhausted maps to EXHAUSTED', () {
      final view = evaluateOperationalView(
        _status(
          esimStatus: 'exhausted',
          dataRemaining: '12 MB',
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        now: now,
      );
      expect(view.surface, StatusSurface.red);
      expect(view.heroLabel, 'EXHAUSTED');
    });

    test('purchased maps to INACTIVE not NOT READY', () {
      final view = evaluateOperationalView(
        _status(
          esimStatus: 'purchased',
          dataRemaining: '12 MB',
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        now: now,
      );
      expect(view.surface, StatusSurface.red);
      expect(view.heroLabel, 'INACTIVE');
    });

    test('malformed expiry is slate ERROR', () {
      final view = evaluateOperationalView(
        _status(
          dataRemaining: '12 MB',
          expiryMalformed: true,
        ),
        now: now,
      );
      expect(view.surface, StatusSurface.slateError);
      expect(view.heroLabel, 'ERROR');
      expect(view.isSuccessSnapshot, isFalse);
    });

    test('EXPIRED takes priority over NO DATA', () {
      final view = evaluateOperationalView(
        _status(
          dataRemaining: null,
          expiresAt: DateTime.utc(2026, 8, 1),
        ),
        now: now,
      );
      expect(view.heroLabel, 'EXPIRED');
    });
  });

  group('fromException', () {
    test('ICCID miss is slate NO DATA and not success', () {
      final view = OperationalStatusView.fromException(
        const DeviceStatusIccidNotFoundException(),
      );
      expect(view.surface, StatusSurface.slateError);
      expect(view.heroLabel, 'NO DATA');
      expect(view.isSuccessSnapshot, isFalse);
    });

    test('missing config is UNAVAILABLE not NOT CONFIGURED', () {
      final view = OperationalStatusView.fromException(
        const MissingManagedConfigException(),
      );
      expect(view.heroLabel, 'UNAVAILABLE');
      expect(view.surface, StatusSurface.slateError);
    });

    test('rate limit is TRY LATER', () {
      final view = OperationalStatusView.fromException(
        const DeviceStatusRateLimitedException(),
      );
      expect(view.heroLabel, 'TRY LATER');
    });

    test('network is OFFLINE', () {
      final view = OperationalStatusView.fromException(
        DeviceStatusNetworkException('DNS lookup failed'),
      );
      expect(view.heroLabel, 'OFFLINE');
    });

    test('not found is UNAVAILABLE', () {
      final view = OperationalStatusView.fromException(
        const DeviceStatusNotFoundException(),
      );
      expect(view.heroLabel, 'UNAVAILABLE');
    });

    test('UEM 503 is UNAVAILABLE', () {
      final view = OperationalStatusView.fromException(
        const DeviceStatusUemInventoryUnavailableException(),
      );
      expect(view.heroLabel, 'UNAVAILABLE');
    });

    test('unexpected is ERROR', () {
      final view = OperationalStatusView.fromException(
        const DeviceStatusUnexpectedException('boom'),
      );
      expect(view.heroLabel, 'ERROR');
    });

    test('success NO DATA != ICCID error NO DATA', () {
      final success = evaluateOperationalView(
        _status(dataRemaining: '0 MB', expiresAt: DateTime.utc(2026, 9, 1)),
        now: now,
      );
      final error = OperationalStatusView.fromException(
        const DeviceStatusIccidNotFoundException(),
      );
      expect(success.heroLabel, 'NO DATA');
      expect(error.heroLabel, 'NO DATA');
      expect(success.surface, StatusSurface.red);
      expect(error.surface, StatusSurface.slateError);
      expect(success.isSuccessSnapshot, isTrue);
      expect(error.isSuccessSnapshot, isFalse);
    });
  });

  group('menu formatters do not affect color', () {
    test('binding credential autotopup changes leave surface green', () {
      final base = evaluateOperationalView(
        _status(
          bindingStatus: 'active',
          autoTopup: true,
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        now: now,
      );
      final other = evaluateOperationalView(
        _status(
          bindingStatus: 'revoked',
          autoTopup: false,
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        now: now,
      );
      expect(base.surface, StatusSurface.green);
      expect(other.surface, StatusSurface.green);
      expect(MenuFormatters.binding('active'), 'Active');
      expect(MenuFormatters.binding('revoked'), 'Revoked');
      expect(MenuFormatters.autoTopup(enabled: true), 'Enabled');
      expect(MenuFormatters.autoTopup(enabled: false), 'Disabled');
      expect(
        MenuFormatters.credential(
          const ManagedConfig(
            deviceExternalId: 'x',
            deviceCredential: 'secret',
          ),
        ),
        'Present',
      );
      expect(
        MenuFormatters.credential(
          const ManagedConfig(deviceExternalId: 'x', deviceCredential: null),
        ),
        'Missing',
      );
    });
  });

  group('formatUpdatedCaption', () {
    test('formats local time from UTC checkedAt', () {
      final checkedAt = DateTime.utc(2026, 8, 9, 14, 21);
      final caption = formatUpdatedCaption(checkedAt);
      expect(caption.startsWith('Updated '), isTrue);
      expect(caption, isNot('Updated —'));
      // Local HH:mm must match conversion of the same instant.
      final local = checkedAt.toLocal();
      final expected =
          'Updated ${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      expect(caption, expected);
    });

    test('null checkedAt is Updated —', () {
      expect(formatUpdatedCaption(null), 'Updated —');
    });
  });

  group('parseApiDateTime', () {
    test('never throws on malformed', () {
      expect(parseApiDateTime(null), isNull);
      expect(parseApiDateTime('not-a-date'), isNull);
      expect(parseApiDateTime(123), isNull);
      expect(parseApiDateTime('2026-09-01T00:00:00Z'), isNotNull);
    });

    test('usage marks malformed non-null expiry', () {
      final usage = DeviceStatusUsage.fromJson({
        'data_remaining': '12 MB',
        'data_used': '1 MB',
        'expires_at': 'bogus',
      });
      expect(usage.expiryMalformed, isTrue);
      expect(usage.expiresAt, isNull);
    });
  });
}
