sealed class Result<T> {
  const Result();

  /// Fold into a single value depending on success or failure.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final error) => failure(error),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

enum ErrorKind {
  network,
  server,
  parsing,
  auth,
  unknown,
}

class AppError {
  final ErrorKind kind;

  /// User-safe message, fine to render directly in the UI.
  final String message;

  /// Technical detail for logging / crash reporting. Never shown to users.
  final String? debugDetail;

  /// The original caught exception, for logging frameworks that want it.
  final Object? originalError;

  const AppError({
    required this.kind,
    required this.message,
    this.debugDetail,
    this.originalError,
  });

  @override
  String toString() =>
      'AppError($kind): $message${debugDetail != null ? ' [$debugDetail]' : ''}';
}
