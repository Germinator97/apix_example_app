import 'package:apix/apix.dart';

/// Base sealed class for all application Failures.
/// Extends [ApiException] for compatibility with apix [Result] type.
sealed class Failure extends ApiException {
  const Failure({required super.message});
}

/// Service temporarily unavailable (timeout, 503, no connectivity).
class UnavailableFailure extends Failure {
  const UnavailableFailure()
    : super(message: 'Service temporairement indisponible. Réessayez.');
}

/// Session expired — user needs to re-authenticate.
/// Also covers `TokenProviderException` (corrupted keychain → re-login).
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure()
    : super(message: 'Session expirée. Veuillez vous reconnecter.');
}

/// User is authenticated but does not have access to the resource (403).
class ForbiddenFailure extends Failure {
  const ForbiddenFailure()
    : super(message: 'Accès refusé. Vous n\'avez pas les droits requis.');
}

/// Requested resource does not exist (404).
class NotFoundFailure extends Failure {
  const NotFoundFailure() : super(message: 'Ressource introuvable.');
}

/// Network connectivity issue.
class NetworkFailure extends Failure {
  const NetworkFailure()
    : super(message: 'Erreur réseau. Vérifiez votre connexion internet.');
}

/// Parsing of the server response failed (malformed JSON, shape mismatch).
/// Maps `ParsingException` from apix v2.1.0.
class ParsingFailure extends Failure {
  const ParsingFailure()
    : super(message: 'Réponse invalide du serveur. Réessayez plus tard.');
}

/// Captive portal detected (response Content-Type isn't JSON).
/// Maps `UnexpectedContentTypeException` from apix v2.1.0.
class CaptivePortalFailure extends Failure {
  const CaptivePortalFailure()
    : super(
        message:
            'Connexion détournée par un portail Wi-Fi. Vérifiez votre réseau.',
      );
}

/// Unknown / unexpected error with optional custom message.
class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Une erreur inattendue est survenue.'});
}
