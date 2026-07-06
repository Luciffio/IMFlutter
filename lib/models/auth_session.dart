enum AuthStage {
  signedOut,
  waitPhone,
  waitEmailAddress,
  waitEmailCode,
  waitCode,
  waitOtherDevice,
  waitRegistration,
  waitPassword,
  ready,
}

class AuthSessionState {
  final AuthStage stage;
  final bool isLoading;
  final String? phoneNumber;
  final String? codeDeliveryMessage;
  final String? emailAddressPattern;
  final String? otherDeviceLink;
  final String? registrationTerms;
  final bool canResendCode;
  final int resendTimeoutSeconds;
  final bool codeIsNumeric;
  final String? errorMessage;

  const AuthSessionState({
    required this.stage,
    this.isLoading = false,
    this.phoneNumber,
    this.codeDeliveryMessage,
    this.emailAddressPattern,
    this.otherDeviceLink,
    this.registrationTerms,
    this.canResendCode = false,
    this.resendTimeoutSeconds = 0,
    this.codeIsNumeric = true,
    this.errorMessage,
  });

  const AuthSessionState.signedOut() : this(stage: AuthStage.signedOut);
  const AuthSessionState.waitPhone() : this(stage: AuthStage.waitPhone);
  const AuthSessionState.ready() : this(stage: AuthStage.ready);

  bool get isReady => stage == AuthStage.ready;

  AuthSessionState copyWith({
    AuthStage? stage,
    bool? isLoading,
    String? phoneNumber,
    String? codeDeliveryMessage,
    String? emailAddressPattern,
    String? otherDeviceLink,
    String? registrationTerms,
    bool? canResendCode,
    int? resendTimeoutSeconds,
    bool? codeIsNumeric,
    String? errorMessage,
    bool clearError = false,
    bool clearCodeDelivery = false,
  }) {
    return AuthSessionState(
      stage: stage ?? this.stage,
      isLoading: isLoading ?? this.isLoading,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      codeDeliveryMessage: clearCodeDelivery
          ? null
          : codeDeliveryMessage ?? this.codeDeliveryMessage,
      emailAddressPattern: emailAddressPattern ?? this.emailAddressPattern,
      otherDeviceLink: otherDeviceLink ?? this.otherDeviceLink,
      registrationTerms: registrationTerms ?? this.registrationTerms,
      canResendCode: canResendCode ?? this.canResendCode,
      resendTimeoutSeconds: resendTimeoutSeconds ?? this.resendTimeoutSeconds,
      codeIsNumeric: codeIsNumeric ?? this.codeIsNumeric,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
