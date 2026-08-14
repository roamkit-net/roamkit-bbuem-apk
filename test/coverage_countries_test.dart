import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage.dart';
import 'package:roamkit_bbuem_apk/status/coverage_countries.dart';

DeviceCoverageCountry row({
  String code = '',
  String? name,
  List<String> operators = const [],
}) {
  return DeviceCoverageCountry(
    countryCode: code,
    countryName: name,
    operators: operators,
  );
}

void main() {
  group('foldForSearch', () {
    test('Côte / Åland / Türkiye / Réunion fold to ASCII', () {
      expect(foldForSearch("Côte d'Ivoire").contains('cote'), isTrue);
      expect(foldForSearch('Åland Islands').contains('aland'), isTrue);
      expect(foldForSearch('Türkiye').contains('turkiye'), isTrue);
      expect(foldForSearch('Réunion').contains('reunion'), isTrue);
    });
  });

  group('normalizeOperators', () {
    test('trims, drops empty, dedupes case-insensitive, keeps first spelling', () {
      expect(
        normalizeOperators(['  A1  ', '', 'a1', 'Telemach', 'TELEMAC']),
        ['A1', 'Telemach', 'TELEMAC'],
      );
      expect(normalizeOperators(['a1', 'A1']), ['a1']);
    });
  });

  group('groupCoverageCountries', () {
    test('merges valid ISO rows and operators', () {
      final grouped = groupCoverageCountries([
        row(code: 'hr', operators: ['A1', ' a1 ', '']),
        row(code: 'HR', operators: ['Telemach']),
      ]);
      expect(grouped, hasLength(1));
      expect(grouped.single.displayName, 'Croatia');
      expect(grouped.single.countryCode, 'HR');
      expect(grouped.single.operators, ['A1', 'Telemach']);
    });

    test('SI with null API name uses ISO Slovenia', () {
      final grouped = groupCoverageCountries([row(code: 'SI')]);
      expect(grouped.single.displayName, 'Slovenia');
    });

    test('invalid codes with same name merge; empty unknowns stay separate', () {
      final grouped = groupCoverageCountries([
        row(code: 'XX', name: 'Narnia', operators: ['Op1']),
        row(code: '99', name: 'narnia', operators: ['Op2']),
        row(code: '', name: null, operators: ['Solo']),
        row(code: '??', operators: ['Other']),
      ]);
      final names = grouped.map((c) => c.displayName).toList();
      expect(names.where((n) => n == 'Narnia'), hasLength(1));
      expect(names.where((n) => n == unknownCountryLabel), hasLength(2));
      final narnia = grouped.firstWhere((c) => c.displayName == 'Narnia');
      expect(narnia.operators, ['Op1', 'Op2']);
    });

    test('sorts alphabetically by resolved name and stays deterministic', () {
      final rows = [
        row(code: 'DE'),
        row(code: 'AT'),
        row(code: 'HR'),
      ];
      final first = groupCoverageCountries(rows);
      final second = groupCoverageCountries(rows.reversed.toList());
      expect(
        first.map((c) => c.displayName),
        ['Austria', 'Croatia', 'Germany'],
      );
      expect(
        second.map((c) => c.displayName),
        first.map((c) => c.displayName),
      );
    });
  });

  group('filter and suggest', () {
    final grouped = groupCoverageCountries([
      row(code: 'CI'),
      row(code: 'AX'),
      row(code: 'TR'),
      row(code: 'RE'),
      row(code: 'HR', operators: ['A1']),
    ]);

    test('name-only match; operators do not match', () {
      expect(
        filterCoverageCountries(grouped, 'cote').single.displayName,
        "Côte d'Ivoire",
      );
      expect(filterCoverageCountries(grouped, 'A1'), isEmpty);
      expect(
        suggestCoverageCountries(grouped, 'cote'),
        ["Côte d'Ivoire"],
      );
    });

    test('Åland Türkiye Réunion queries', () {
      expect(
        filterCoverageCountries(grouped, 'aland').single.displayName,
        'Åland Islands',
      );
      expect(
        filterCoverageCountries(grouped, 'turkiye').single.displayName,
        'Türkiye',
      );
      expect(
        filterCoverageCountries(grouped, 'reunion').single.displayName,
        'Réunion',
      );
    });
  });
}
