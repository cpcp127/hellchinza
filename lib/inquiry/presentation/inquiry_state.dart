class InquiryState {
  final bool isSubmitting;

  const InquiryState({this.isSubmitting = false});

  InquiryState copyWith({bool? isSubmitting}) {
    return InquiryState(isSubmitting: isSubmitting ?? this.isSubmitting);
  }
}
