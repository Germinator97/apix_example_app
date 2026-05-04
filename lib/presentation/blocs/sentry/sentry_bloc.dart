import 'package:apix/apix.dart';
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
    try {
      final result = await _testSentry.triggerTestError();
      await _emitFromResult(emit, result, type: 'ApiException');
    } catch (e, st) {
      await SentrySetup.captureException(e, stackTrace: st);
      emit(SentryTestFailed(e.toString()));
    }
  }

  Future<void> _onTriggerTimeout(
    TriggerTimeout event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('TimeoutException'));
    try {
      final result = await _testSentry.triggerTimeout();
      await _emitFromResult(emit, result, type: 'TimeoutException');
    } catch (e, st) {
      await SentrySetup.captureException(e, stackTrace: st);
      emit(SentryTestFailed(e.toString()));
    }
  }

  Future<void> _onTriggerNotFound(
    TriggerNotFound event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('NotFoundException (404)'));
    try {
      final result = await _testSentry.triggerNotFound();
      await _emitFromResult(emit, result, type: 'NotFoundException');
    } catch (e, st) {
      await SentrySetup.captureException(e, stackTrace: st);
      emit(SentryTestFailed(e.toString()));
    }
  }

  Future<void> _onTriggerUnauthorized(
    TriggerUnauthorized event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('UnauthorizedException (401)'));
    try {
      final result = await _testSentry.triggerUnauthorized();
      await _emitFromResult(emit, result, type: 'UnauthorizedException');
    } catch (e, st) {
      await SentrySetup.captureException(e, stackTrace: st);
      emit(SentryTestFailed(e.toString()));
    }
  }

  Future<void> _onTriggerRealApiError(
    TriggerRealApiError event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('Real API Error'));
    try {
      final result = await _testSentry.triggerRealApiError();
      if (result.isSuccess) {
        emit(
          const SentryErrorCaptured(
            errorType: 'No Error',
            message: 'API call succeeded (no error to capture)',
          ),
        );
        return;
      }
      final error = result.errorOrNull!;
      await SentrySetup.captureException(
        error,
        stackTrace: StackTrace.current,
        tags: {'apix.kind': error.runtimeType.toString()},
      );
      emit(
        SentryErrorCaptured(
          errorType: error.runtimeType.toString(),
          message: error.message,
        ),
      );
    } catch (e, st) {
      await SentrySetup.captureException(e, stackTrace: st);
      emit(SentryTestFailed(e.toString()));
    }
  }

  Future<void> _onCaptureManualException(
    CaptureManualException event,
    Emitter<SentryState> emit,
  ) async {
    emit(const SentryTesting('Manual Exception'));
    try {
      await Sentry.captureMessage(event.message, level: SentryLevel.error);
      emit(
        SentryErrorCaptured(
          errorType: 'Manual Message',
          message: event.message,
        ),
      );
    } catch (e, st) {
      await SentrySetup.captureException(e, stackTrace: st);
      emit(SentryTestFailed(e.toString()));
    }
  }

  /// Folds a `Result<void, ApiException>` from the test usecase into a state,
  /// forwarding the exception to Sentry with a typed tag.
  Future<void> _emitFromResult(
    Emitter<SentryState> emit,
    Result<void, ApiException> result, {
    required String type,
  }) async {
    if (result.isSuccess) {
      emit(const SentryTestFailed('Expected error not thrown'));
      return;
    }
    final error = result.errorOrNull!;
    await SentrySetup.captureException(
      error,
      stackTrace: StackTrace.current,
      tags: {'apix.kind': type},
    );
    emit(SentryErrorCaptured(errorType: type, message: error.message));
  }
}
