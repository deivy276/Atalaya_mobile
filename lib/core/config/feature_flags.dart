class FeatureFlags {
  const FeatureFlags._();

  static const bool mobileDashboardV2 = bool.fromEnvironment(
    'MOBILE_DASHBOARD_V2',
    defaultValue: true,
  );
}
