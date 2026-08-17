class ProviderResult<T> {
  const ProviderResult.success([this.data])
    : isSuccess = true,
      message = null,
      statusCode = null;

  const ProviderResult.failure(this.message, {this.statusCode})
    : isSuccess = false,
      data = null;

  final bool isSuccess;
  final T? data;
  final String? message;
  final int? statusCode;
}
