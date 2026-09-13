class RegisterModel {
  final String email;

  /// Пароль есть только в запросе на регистрацию: в ответе бэкенд его не
  /// возвращает, поэтому поле nullable — иначе разбор ответа падал бы на
  /// приведении null к String.
  final String? password;
  final String name;

  RegisterModel({
    required this.email,
    this.password,
    required this.name,
  });

  factory RegisterModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    return RegisterModel(
      email: data['email'] as String,
      password: data['password'] as String?,
      name: data['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      if (password != null) 'password': password,
      'name': name,
    };
  }
}

class LoginModel {
  final String email;
  final String password;

  LoginModel({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class LoginResponseModel {
  final String accessToken;
  final String tokenType;

  LoginResponseModel({
    required this.accessToken,
    required this.tokenType,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      accessToken: json['data']['access_token'] as String,
      tokenType: json['data']['token_type'] as String,
    );
  }
}

class LogoutResponseModel {
  final String status;
  final String message;

  LogoutResponseModel({
    required this.status,
    required this.message,
  });

  factory LogoutResponseModel.fromJson(Map<String, dynamic> json) {
    return LogoutResponseModel(
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

class AuthMeResponseModel {
  final String id;
  final String userEmail;
  final String userName;
  final DateTime? createdAt;

  AuthMeResponseModel(
      {required this.id,
      required this.userEmail,
      required this.userName,
      required this.createdAt});

  factory AuthMeResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    return AuthMeResponseModel(
      id: data['id'] as String,
      userEmail: data['email'] as String,
      userName: data['name'] as String,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
    );
  }
}
