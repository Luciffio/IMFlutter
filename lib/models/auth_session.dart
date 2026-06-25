enum AuthStage { signedOut, waitPhone, waitCode, waitPassword, ready }

class AuthSessionState {
  final AuthStage stage;
  final bool isLoading;
  final String? phoneNumber;
  final String? errorMessage;

  const AuthSessionState({
    required this.stage,
    this.isLoading = false,
    this.phoneNumber,
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
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthSessionState(
      stage: stage ?? this.stage,
      isLoading: isLoading ?? this.isLoading,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
