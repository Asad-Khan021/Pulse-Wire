class SignalResponse {
  final String articleId;
  final int? hnPoints;
  final int? hnCommentCount;
  final String? hnDiscussionUrl;
  final String? redditThreadUrl;
  final int? redditCommentCount;
  final DateTime? fetchedAt;

  const SignalResponse({
    required this.articleId,
    this.hnPoints,
    this.hnCommentCount,
    this.hnDiscussionUrl,
    this.redditThreadUrl,
    this.redditCommentCount,
    this.fetchedAt,
  });

  factory SignalResponse.fromJson(Map<String, dynamic> json) {
    return SignalResponse(
      articleId: json['article_id'] as String,
      hnPoints: json['hn_points'] as int?,
      hnCommentCount: json['hn_comment_count'] as int?,
      hnDiscussionUrl: json['hn_discussion_url'] as String?,
      redditThreadUrl: json['reddit_thread_url'] as String?,
      redditCommentCount: json['reddit_comment_count'] as int?,
      fetchedAt: json['fetched_at'] != null
          ? DateTime.parse(json['fetched_at'] as String)
          : null,
    );
  }
}
