import '../core/constants.dart';
import 'api_client.dart';

/// Talks to the Public (central) Server instead of the school's
/// auto-discovered local server. Only ever used by the parent role -- see
/// AppConstants.publicServerBaseUrl for why. A distinct subtype (not just a
/// second ApiClient instance) so `provider` can inject it independently from
/// the local ApiClient in the same widget tree.
class PublicApiClient extends ApiClient {
  PublicApiClient({super.httpClient, super.tokenStorage})
    : super(baseUrlResolver: () => AppConstants.publicServerBaseUrl);
}
