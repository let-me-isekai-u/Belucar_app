///Tạm chưa dùng đến 2 api này
class DepositContentData {
  final String content;
  final int? depositId;

  DepositContentData({required this.content, this.depositId});

  factory DepositContentData.fromJson(Map<String, dynamic> json) {
    return DepositContentData(
      content: json['content'] ?? "",
      depositId: json['depositId'] is int
          ? json['depositId'] as int
          : int.tryParse('${json['depositId'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {'content': content, 'depositId': depositId};
}

/// Model tổng thể response tạo nạp tiền
class DepositContentResponse {
  final bool success;
  final DepositContentData? data;
  final String? message;

  DepositContentResponse({required this.success, this.data, this.message});

  factory DepositContentResponse.fromJson(Map<String, dynamic> json) {
    return DepositContentResponse(
      success: json['success'] == true,
      data: json['data'] != null
          ? DepositContentData.fromJson(json['data'])
          : null,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'data': data?.toJson(),
    'message': message,
  };
}

/// Model response cho huỷ giao dịch nạp tiền
class CancelDepositResponse {
  final bool success;
  final String? message;

  CancelDepositResponse({required this.success, this.message});

  factory CancelDepositResponse.fromJson(Map<String, dynamic> json) {
    return CancelDepositResponse(
      success: json['success'] == true,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() => {'success': success, 'message': message};
}
