import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConcentrationState {
  final bool isRunning;
  final Duration elapsed;
  final Duration totalToday;

  const ConcentrationState({
    this.isRunning = false,
    this.elapsed = Duration.zero,
    this.totalToday = Duration.zero,
  });

  ConcentrationState copyWith({
    bool? isRunning,
    Duration? elapsed,
    Duration? totalToday,
  }) {
    return ConcentrationState(
      isRunning: isRunning ?? this.isRunning,
      elapsed: elapsed ?? this.elapsed,
      totalToday: totalToday ?? this.totalToday,
    );
  }
}

class ConcentrationNotifier extends StateNotifier<ConcentrationState> {
  Timer? _timer;

  ConcentrationNotifier() : super(const ConcentrationState());

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      elapsed: Duration.zero,
      totalToday: state.totalToday + state.elapsed,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final concentrationProvider =
    StateNotifierProvider<ConcentrationNotifier, ConcentrationState>(
  (ref) => ConcentrationNotifier(),
);
