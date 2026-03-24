abstract class SettingsRepository {
  /// Primary currency is used for:
  /// - Default currency when creating new expenses
  /// - Display currency for converted amounts in lists and insights
  String getPrimaryCurrency();
  void setPrimaryCurrency(String currencyCode);

  List<String> getRecentCurrencies();
  void saveRecentCurrencies(List<String> codes);

  /// Returns the first day of the week (DateTime.monday = 1, DateTime.sunday = 7).
  int getFirstDayOfWeek();
  void setFirstDayOfWeek(int weekday);

  /// Returns whether the user has completed initial onboarding.
  bool isOnboarded();
  void setOnboarded(bool value);

  /// Currency lock for travel mode - null means no lock
  String? getLockedCurrencyCode();
  void setLockedCurrencyCode(String? currencyCode);

  /// Tracks whether a bulk currency conversion is in progress.
  /// Used to detect and recover from interrupted conversions on next startup.
  bool getConversionInProgress();
  void setConversionInProgress(bool value);
}
