import 'package:apix/apix.dart';
import 'package:equatable/equatable.dart';

/// Cache information for displaying cache status.
class CacheInfo extends Equatable {
  final int cachedEntries;
  final CacheStrategy currentStrategy;
  final Duration? lastRequestDuration;
  final bool wasFromCache;

  const CacheInfo({
    required this.cachedEntries,
    required this.currentStrategy,
    this.lastRequestDuration,
    this.wasFromCache = false,
  });

  CacheInfo copyWith({
    int? cachedEntries,
    CacheStrategy? currentStrategy,
    Duration? lastRequestDuration,
    bool? wasFromCache,
  }) {
    return CacheInfo(
      cachedEntries: cachedEntries ?? this.cachedEntries,
      currentStrategy: currentStrategy ?? this.currentStrategy,
      lastRequestDuration: lastRequestDuration ?? this.lastRequestDuration,
      wasFromCache: wasFromCache ?? this.wasFromCache,
    );
  }

  @override
  List<Object?> get props => [
    cachedEntries,
    currentStrategy,
    lastRequestDuration,
    wasFromCache,
  ];
}
