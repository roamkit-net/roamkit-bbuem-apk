import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visible brand is RoamKit.net and applicationId stays net.roamkit.bbuem', () {
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    expect(strings, contains('<string name="app_name">RoamKit.net</string>'));

    final page = File('lib/ui/device_status_page.dart').readAsStringSync();
    expect(page, contains("title: const Text('RoamKit.net')"));

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "net.roamkit.bbuem"'));
    expect(gradle, contains('namespace = "net.roamkit.bbuem"'));
  });
}
