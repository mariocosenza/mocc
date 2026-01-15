import 'package:graphql_flutter/graphql_flutter.dart';

class CommonService {
  final GraphQLClient client;

  CommonService(this.client);

  Future<String> generateUploadSasToken(String filename) async {
    const String mutation = r'''
      mutation GenerateUploadSasToken($filename: String!) {
        generateUploadSasToken(filename: $filename)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {
        'filename': filename,
      },
      fetchPolicy: FetchPolicy.noCache,
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final token = result.data?['generateUploadSasToken'] as String?;
    if (token == null) {
      throw Exception('Failed to generate SAS token');
    }
    return token;
  }
}
