import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../api/device_coverage.dart';
import 'iso_country_names.dart';

const unknownCountryLabel = 'Unknown country';

final _combiningMarks = RegExp(r'\p{Mn}', unicode: true);

/// NFKD + strip combining marks + lowercase + trim.
String foldForSearch(String raw) {
  final nfkd = unorm.nfkd(raw);
  return nfkd.replaceAll(_combiningMarks, '').toLowerCase().trim();
}

class GroupedCoverageCountry {
  const GroupedCoverageCountry({
    required this.displayName,
    required this.operators,
    required this.isUnknown,
    this.countryCode,
    this.sequence = 0,
  });

  final String displayName;
  final String? countryCode;
  final List<String> operators;
  final bool isUnknown;
  final int sequence;

  String get networksLine => operators.join(' · ');

  String get semanticsLabel {
    if (operators.isEmpty) {
      return displayName;
    }
    if (operators.length == 1) {
      return '$displayName, networks ${operators[0]}';
    }
    if (operators.length == 2) {
      return '$displayName, networks ${operators[0]} and ${operators[1]}';
    }
    final head = operators.sublist(0, operators.length - 1).join(', ');
    return '$displayName, networks $head and ${operators.last}';
  }
}

List<String> normalizeOperators(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in raw) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      out.add(trimmed);
    }
  }
  return out;
}

/// Group, normalize operators, sort alphabetically by resolved name.
List<GroupedCoverageCountry> groupCoverageCountries(
  List<DeviceCoverageCountry> rows,
) {
  final builders = <String, _GroupBuilder>{};
  final unknowns = <_GroupBuilder>[];
  var unknownSeq = 0;

  for (final row in rows) {
    final code = row.countryCode.trim().toUpperCase();
    final isoName = isoCountryNames[code];
    if (isoName != null) {
      final builder = builders.putIfAbsent(
        'iso:$code',
        () => _GroupBuilder(
          displayName: isoName,
          countryCode: code,
          isUnknown: false,
        ),
      );
      builder.addOperators(row.operators);
      continue;
    }

    final name = row.countryName?.trim() ?? '';
    if (name.isNotEmpty) {
      final key = 'name:${foldForSearch(name)}';
      final builder = builders.putIfAbsent(
        key,
        () => _GroupBuilder(
          displayName: name,
          countryCode: null,
          isUnknown: false,
        ),
      );
      builder.addOperators(row.operators);
      continue;
    }

    unknowns.add(
      _GroupBuilder(
        displayName: unknownCountryLabel,
        countryCode: null,
        isUnknown: true,
        order: unknownSeq++,
      )..addOperators(row.operators),
    );
  }

  final grouped = [
    ...builders.values.map((b) => b.build()),
    ...unknowns.map((b) => b.build()),
  ];
  grouped.sort(_byResolvedName);
  return grouped;
}

int _byResolvedName(GroupedCoverageCountry a, GroupedCoverageCountry b) {
  final byFold = foldForSearch(a.displayName).compareTo(
    foldForSearch(b.displayName),
  );
  if (byFold != 0) {
    return byFold;
  }
  final byName = a.displayName.compareTo(b.displayName);
  if (byName != 0) {
    return byName;
  }
  final byCode = (a.countryCode ?? '').compareTo(b.countryCode ?? '');
  if (byCode != 0) {
    return byCode;
  }
  return a.sequence.compareTo(b.sequence);
}

List<GroupedCoverageCountry> filterCoverageCountries(
  List<GroupedCoverageCountry> grouped,
  String query,
) {
  final folded = foldForSearch(query);
  if (folded.isEmpty) {
    return grouped;
  }
  return [
    for (final country in grouped)
      if (foldForSearch(country.displayName).contains(folded)) country,
  ];
}

/// Full display names that match [query], in grouped order.
List<String> suggestCoverageCountries(
  List<GroupedCoverageCountry> grouped,
  String query,
) {
  final folded = foldForSearch(query);
  if (folded.isEmpty) {
    return const [];
  }
  final names = <String>[];
  final seen = <String>{};
  for (final country in grouped) {
    if (!foldForSearch(country.displayName).contains(folded)) {
      continue;
    }
    if (seen.add(foldForSearch(country.displayName))) {
      names.add(country.displayName);
    }
  }
  return names;
}

class _GroupBuilder {
  _GroupBuilder({
    required this.displayName,
    required this.countryCode,
    required this.isUnknown,
    this.order = 0,
  });

  final String displayName;
  final String? countryCode;
  final bool isUnknown;
  final int order;
  final List<String> _operators = [];

  void addOperators(Iterable<String> raw) {
    _operators.addAll(raw);
  }

  GroupedCoverageCountry build() {
    return GroupedCoverageCountry(
      displayName: displayName,
      countryCode: countryCode,
      operators: normalizeOperators(_operators),
      isUnknown: isUnknown,
      sequence: order,
    );
  }
}
