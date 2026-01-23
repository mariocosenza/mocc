import 'package:graphql_flutter/graphql_flutter.dart';

class CommonService {
  final GraphQLClient client;

  CommonService(this.client);

  Future<String> generateUploadSasToken(
    String filename, {
    String purpose = 'SOCIAL_POST',
  }) async {
    const String mutation = r'''
      mutation GenerateUploadSasToken($filename: String!, $purpose: UploadPurpose!) {
        generateUploadSasToken(filename: $filename, purpose: $purpose)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'filename': filename, 'purpose': purpose},
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
