class AppEnvironment {
  const AppEnvironment._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7027',
  );

  static const graphqlEndpoint = String.fromEnvironment(
    'GRAPHQL_ENDPOINT',
    defaultValue: '$apiBaseUrl/graphql',
  );
}
