import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/auth/auth_controller.dart';

final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final authController = ref.watch(authControllerProvider);

  final httpLink = HttpLink(
    const String.fromEnvironment('MOCC_API_URL'),
  );

  final authLink = AuthLink(
    getToken: () async {
      final token = await authController.token();
      return token != null ? 'Bearer $token' : null;
    },
  );

  final link = authLink.concat(httpLink);

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );
});

class GraphQLConfig {
  static HttpLink httpLink = HttpLink(const String.fromEnvironment('MOCC_API_URL'));
  GraphQLClient clientToQuery() => GraphQLClient(link: httpLink, cache: GraphQLCache());
}