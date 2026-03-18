import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../domain/usecases/test_sentry.dart';
import 'sentry_event.dart';
import 'sentry_state.dart';

class SentryBloc extends Bloc<SentryTestEvent, SentryState> {
  final TestSentry _testSentry;

  SentryBloc({required TestSentry testSentry})
    : _testSentry = testSentry,
      super(const SentryInitial()) {
    on<TriggerTestError>(_onTriggerTestError);
    on<TriggerTimeout>(_onTriggerTimeout);
    on<TriggerNotFound>(_onTriggerNotFound);
    on<TriggerUnauthorized>(_onTriggerUnauthorized);
    on<TriggerRealApiError>(_onTriggerRealApiError);
    on<CaptureManualException>(_onCaptureManualException);
  }

  Future<void> _onTriggerTestError(
    TriggerTestError event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('ApiException (500)'));

    final result = await _testSentry.triggerTestError();

    result.when(
      success: (_) => emit(const SentryTestFailed('Expected error not thrown')),
      failure: (error) {
        Sentry.captureException(error, stackTrace: StackTrace.current);
        emit(
          SentryErrorCaptured(
            errorType: 'ApiException',
            message: error.message,
          ),
        );
      },
    );
  }

  Future<void> _onTriggerTimeout(
    TriggerTimeout event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('TimeoutException'));

    final result = await _testSentry.triggerTimeout();

    result.when(
      success: (_) => emit(const SentryTestFailed('Expected error not thrown')),
      failure: (error) {
        Sentry.captureException(error, stackTrace: StackTrace.current);
        emit(
          SentryErrorCaptured(
            errorType: 'TimeoutException',
            message: error.message,
          ),
        );
      },
    );
  }

  Future<void> _onTriggerNotFound(
    TriggerNotFound event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('NotFoundException (404)'));

    final result = await _testSentry.triggerNotFound();

    result.when(
      success: (_) => emit(const SentryTestFailed('Expected error not thrown')),
      failure: (error) {
        Sentry.captureException(error, stackTrace: StackTrace.current);
        emit(
          SentryErrorCaptured(
            errorType: 'NotFoundException',
            message: error.message,
          ),
        );
      },
    );
  }

  Future<void> _onTriggerUnauthorized(
    TriggerUnauthorized event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('UnauthorizedException (401)'));

    final result = await _testSentry.triggerUnauthorized();

    result.when(
      success: (_) => emit(const SentryTestFailed('Expected error not thrown')),
      failure: (error) {
        Sentry.captureException(error, stackTrace: StackTrace.current);
        emit(
          SentryErrorCaptured(
            errorType: 'UnauthorizedException',
            message: error.message,
          ),
        );
      },
    );
  }

  Future<void> _onTriggerRealApiError(
    TriggerRealApiError event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('Real API Error'));

    final result = await _testSentry.triggerRealApiError();

    result.when(
      success: (_) => emit(
        const SentryErrorCaptured(
          errorType: 'No Error',
          message: 'API call succeeded (no error to capture)',
        ),
      ),
      failure: (error) {
        Sentry.captureException(error, stackTrace: StackTrace.current);
        emit(
          SentryErrorCaptured(
            errorType: error.runtimeType.toString(),
            message: error.message,
          ),
        );
      },
    );
  }

  Future<void> _onCaptureManualException(
    CaptureManualException event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('Manual Exception'));

    await Sentry.captureMessage(event.message, level: SentryLevel.error);

    emit(
      SentryErrorCaptured(errorType: 'Manual Message', message: event.message),
    );
  }
}
