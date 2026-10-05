part of 'insights_cubit.dart';

@immutable
abstract class InsightsState {}

class InsightsInitial extends InsightsState {}

class InsightsLoading extends InsightsState {}

class InsightsLoaded extends InsightsState {
  final List<String> insights;
  final DateTime? generatedAt;

  InsightsLoaded({required this.insights, this.generatedAt});
}

class InsightsError extends InsightsState {
  final String message;

  InsightsError(this.message);
}

class InsightsNetworkError extends InsightsState {}

class InsightsUnauthenticated extends InsightsState {
  final String hint;

  InsightsUnauthenticated(this.hint);
}
