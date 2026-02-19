class GitData {
  final String? lastCommitMessage;
  final String? lastCommitHash; // 7-char short SHA
  final DateTime? lastCommitDate;
  final String? githubUrl; // https://github.com/owner/repo

  const GitData({
    this.lastCommitMessage,
    this.lastCommitHash,
    this.lastCommitDate,
    this.githubUrl,
  });

  static const empty = GitData();

  bool get isEmpty =>
      lastCommitMessage == null &&
      lastCommitHash == null &&
      lastCommitDate == null &&
      githubUrl == null;
}
