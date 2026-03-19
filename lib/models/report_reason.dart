enum ReportReason {
  spam('Spam / Advertisement'),
  misinformation('Misinformation / Inaccurate agricultural info'),
  inappropriate('Inappropriate content'),
  other('Other');

  final String label;
  const ReportReason(this.label);
}
