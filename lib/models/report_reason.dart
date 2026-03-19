enum ReportReason {
  spam('スパム・宣伝'),
  misinformation('誤情報・不正確な農業情報'),
  inappropriate('不適切なコンテンツ'),
  other('その他');

  final String label;
  const ReportReason(this.label);
}
