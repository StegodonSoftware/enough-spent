import 'package:hive/hive.dart';
import 'settings_repository.dart';

class HiveSettingsRepository implements SettingsRepository {
  // Key kept as 'defaultCurrency' for backwards compatibility with existing data
  static const _currencyKey = 'defaultCurrency';
  static const _firstDayOfWeekKey = 'firstDayOfWeek';
  static const _onboardedKey = 'onboarded';
  static const _lockedCurrencyKey = 'lockedCurrencyCode';
  static const _conversionInProgressKey = 'conversionInProgress';
  static const _reviewLastMilestoneKey = 'reviewLastMilestone';
  final Box _box;

  HiveSettingsRepository(this._box);

  @override
  String getPrimaryCurrency() {
    return _box.get(_currencyKey, defaultValue: 'USD');
  }

  @override
  void setPrimaryCurrency(String currencyCode) {
    _box.put(_currencyKey, currencyCode);
  }

  @override
  List<String> getRecentCurrencies() {
    return List<String>.from(_box.get('recentCurrencies', defaultValue: []));
  }

  @override
  void saveRecentCurrencies(List<String> codes) {
    _box.put('recentCurrencies', codes);
  }

  @override
  int getFirstDayOfWeek() {
    // Default to Monday (1)
    return _box.get(_firstDayOfWeekKey, defaultValue: DateTime.monday);
  }

  @override
  void setFirstDayOfWeek(int weekday) {
    _box.put(_firstDayOfWeekKey, weekday);
  }

  @override
  bool isOnboarded() {
    return _box.get(_onboardedKey, defaultValue: false);
  }

  @override
  void setOnboarded(bool value) {
    _box.put(_onboardedKey, value);
  }

  @override
  String? getLockedCurrencyCode() {
    return _box.get(_lockedCurrencyKey) as String?;
  }

  @override
  void setLockedCurrencyCode(String? currencyCode) {
    if (currencyCode == null) {
      _box.delete(_lockedCurrencyKey);
    } else {
      _box.put(_lockedCurrencyKey, currencyCode);
    }
  }

  @override
  bool getConversionInProgress() {
    return _box.get(_conversionInProgressKey, defaultValue: false);
  }

  @override
  void setConversionInProgress(bool value) {
    _box.put(_conversionInProgressKey, value);
  }

  @override
  int getLastReviewedMilestone() {
    return _box.get(_reviewLastMilestoneKey, defaultValue: 0);
  }

  @override
  void setLastReviewedMilestone(int milestone) {
    _box.put(_reviewLastMilestoneKey, milestone);
  }
}
