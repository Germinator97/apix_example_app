import 'package:apix/apix.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/epic11_demo_client.dart';
import 'epic11_event.dart';
import 'epic11_state.dart';

/// Exercises the four robustness features added in apix v2.1.0 plus the
/// `TokenProviderException` path. Each handler expects a specific typed
/// exception; when the call unexpectedly succeeds we surface that as
/// [Epic11Unexpected] so the demo can never silently lie.
class Epic11Bloc extends Bloc<Epic11Event, Epic11State> {
  final Epic11DemoClient _client;

  Epic11Bloc({required Epic11DemoClient client})
    : _client = client,
      super(const Epic11Initial()) {
    on<TriggerParsingException>(_onParsing);
    on<TriggerCaptivePortal>(_onCaptivePortal);
    on<TriggerBusinessError>(_onBusinessError);
    on<TriggerRetryAfter>(_onRetryAfter);
    on<TriggerTokenProviderFailure>(_onTokenProvider);
  }

  Future<void> _onParsing(
    TriggerParsingException event,
    Emitter<Epic11State> emit,
  ) async {
    const scenario = 'ParsingException';
    emit(const Epic11Running(scenario));
    try {
      await _client.triggerParsingFailure();
      emit(
        const Epic11Unexpected(
          scenario: scenario,
          reason: 'Expected ParsingException but the call succeeded',
        ),
      );
    } on ParsingException catch (e) {
      emit(
        Epic11Captured(
          scenario: scenario,
          exceptionType: 'ParsingException',
          message: e.message,
        ),
      );
    } on ApiException catch (e) {
      emit(
        Epic11Unexpected(
          scenario: scenario,
          reason: 'Got ${e.runtimeType}: ${e.message}',
        ),
      );
    }
  }

  Future<void> _onCaptivePortal(
    TriggerCaptivePortal event,
    Emitter<Epic11State> emit,
  ) async {
    const scenario = 'UnexpectedContentTypeException';
    emit(const Epic11Running(scenario));
    try {
      await _client.triggerCaptivePortal();
      emit(
        const Epic11Unexpected(
          scenario: scenario,
          reason: 'Expected UnexpectedContentTypeException but call succeeded',
        ),
      );
    } on UnexpectedContentTypeException catch (e) {
      emit(
        Epic11Captured(
          scenario: scenario,
          exceptionType: 'UnexpectedContentTypeException',
          message:
              'expected ${e.expectedContentType}, got ${e.actualContentType ?? "(none)"}',
        ),
      );
    } on ApiException catch (e) {
      emit(
        Epic11Unexpected(
          scenario: scenario,
          reason: 'Got ${e.runtimeType}: ${e.message}',
        ),
      );
    }
  }

  Future<void> _onBusinessError(
    TriggerBusinessError event,
    Emitter<Epic11State> emit,
  ) async {
    const scenario = 'responseValidator → BusinessException';
    emit(const Epic11Running(scenario));
    try {
      await _client.triggerBusinessError();
      emit(
        const Epic11Unexpected(
          scenario: scenario,
          reason: 'Expected BusinessException but call succeeded',
        ),
      );
    } on BusinessException catch (e) {
      emit(
        Epic11Captured(
          scenario: scenario,
          exceptionType: 'BusinessException',
          message: '[${e.code}] ${e.message}',
        ),
      );
    } on ApiException catch (e) {
      emit(
        Epic11Unexpected(
          scenario: scenario,
          reason: 'Got ${e.runtimeType}: ${e.message}',
        ),
      );
    }
  }

  Future<void> _onRetryAfter(
    TriggerRetryAfter event,
    Emitter<Epic11State> emit,
  ) async {
    const scenario = 'Retry-After';
    emit(const Epic11Running(scenario));
    try {
      final elapsed = await _client.triggerRetryAfter();
      emit(Epic11RetryAfterSucceeded(elapsed));
    } on ApiException catch (e) {
      emit(
        Epic11Unexpected(
          scenario: scenario,
          reason: 'Retry-After demo failed: ${e.message}',
        ),
      );
    }
  }

  Future<void> _onTokenProvider(
    TriggerTokenProviderFailure event,
    Emitter<Epic11State> emit,
  ) async {
    const scenario = 'TokenProviderException';
    emit(const Epic11Running(scenario));
    try {
      await _client.triggerTokenProviderFailure();
      emit(
        const Epic11Unexpected(
          scenario: scenario,
          reason: 'Expected TokenProviderException but call succeeded',
        ),
      );
    } on TokenProviderException catch (e) {
      emit(
        Epic11Captured(
          scenario: scenario,
          exceptionType: 'TokenProviderException',
          message: '${e.operation.name} → ${e.message}',
        ),
      );
    } on ApiException catch (e) {
      emit(
        Epic11Unexpected(
          scenario: scenario,
          reason: 'Got ${e.runtimeType}: ${e.message}',
        ),
      );
    }
  }
}
