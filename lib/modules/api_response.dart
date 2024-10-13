class ApiResponse<T> {
  final bool isSuccess;
  final String code;
  final String message;
  final T result;

  ApiResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    required this.result,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    return ApiResponse<T>(
      isSuccess: json['isSuccess'],
      code: json['code'],
      message: json['message'],
      result: fromJsonT(json['result']),
    );
  }
}