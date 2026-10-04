class SourceInfo {
  final String id;
  final String name;
  final String? homepageUrl;

  const SourceInfo({
    required this.id,
    required this.name,
    this.homepageUrl,
  });

  factory SourceInfo.fromJson(Map<String, dynamic> json) {
    return SourceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      homepageUrl: json['homepage_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (homepageUrl != null) 'homepage_url': homepageUrl,
    };
  }
}

class ArticleListItem {
  final String id;
  final String sourceId;
  final String title;
  final String canonicalUrl;
  final String? imageUrl;
  final String? author;
  final List<String> tags;
  final bool isSummarizable;
  final DateTime publishedAt;
  final String sourceName;
  final int? hnPoints;
  final int? hnCommentCount;

  const ArticleListItem({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.canonicalUrl,
    this.imageUrl,
    this.author,
    required this.tags,
    required this.isSummarizable,
    required this.publishedAt,
    required this.sourceName,
    this.hnPoints,
    this.hnCommentCount,
  });

  factory ArticleListItem.fromJson(Map<String, dynamic> json) {
    return ArticleListItem(
      id: json['id'] as String,
      sourceId: json['source_id'] as String,
      title: json['title'] as String,
      canonicalUrl: json['canonical_url'] as String,
      imageUrl: json['image_url'] as String?,
      author: json['author'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isSummarizable: json['is_summarizable'] as bool? ?? true,
      publishedAt: DateTime.parse(json['published_at'] as String),
      sourceName: json['source_name'] as String? ?? 'Tech News',
      hnPoints: json['hn_points'] as int?,
      hnCommentCount: json['hn_comment_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'title': title,
      'canonical_url': canonicalUrl,
      'image_url': imageUrl,
      'author': author,
      'tags': tags,
      'is_summarizable': isSummarizable,
      'published_at': publishedAt.toIso8601String(),
      'source_name': sourceName,
      'hn_points': hnPoints,
      'hn_comment_count': hnCommentCount,
    };
  }
}

class ArticleDetail {
  final String id;
  final String sourceId;
  final String title;
  final String canonicalUrl;
  final String? cleanedContent;
  final String? imageUrl;
  final String? author;
  final List<String> tags;
  final bool isSummarizable;
  final DateTime publishedAt;
  final SourceInfo source;
  final int? hnPoints;
  final int? hnCommentCount;
  final String? hnDiscussionUrl;
  final String? redditThreadUrl;
  final int? redditCommentCount;

  const ArticleDetail({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.canonicalUrl,
    this.cleanedContent,
    this.imageUrl,
    this.author,
    required this.tags,
    required this.isSummarizable,
    required this.publishedAt,
    required this.source,
    this.hnPoints,
    this.hnCommentCount,
    this.hnDiscussionUrl,
    this.redditThreadUrl,
    this.redditCommentCount,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final sig = json['signals'] as Map<String, dynamic>?;
    return ArticleDetail(
      id: json['id'] as String,
      sourceId: json['source_id'] as String,
      title: json['title'] as String,
      canonicalUrl: json['canonical_url'] as String,
      cleanedContent: json['cleaned_content'] as String?,
      imageUrl: json['image_url'] as String?,
      author: json['author'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isSummarizable: json['is_summarizable'] as bool? ?? true,
      publishedAt: DateTime.parse(json['published_at'] as String),
      source: SourceInfo.fromJson(json['source'] as Map<String, dynamic>),
      hnPoints: sig?['hn_points'] as int?,
      hnCommentCount: sig?['hn_comment_count'] as int?,
      hnDiscussionUrl: sig?['hn_discussion_url'] as String?,
      redditThreadUrl: sig?['reddit_thread_url'] as String?,
      redditCommentCount: sig?['reddit_comment_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'title': title,
      'canonical_url': canonicalUrl,
      'cleaned_content': cleanedContent,
      'image_url': imageUrl,
      'author': author,
      'tags': tags,
      'is_summarizable': isSummarizable,
      'published_at': publishedAt.toIso8601String(),
      'source': source.toJson(),
      'signals': {
        'hn_points': hnPoints,
        'hn_comment_count': hnCommentCount,
        'hn_discussion_url': hnDiscussionUrl,
        'reddit_thread_url': redditThreadUrl,
        'reddit_comment_count': redditCommentCount,
      },
    };
  }
}

class FeedResponse {
  final List<ArticleListItem> items;
  final String? nextCursor;
  final int totalReturned;

  const FeedResponse({
    required this.items,
    this.nextCursor,
    required this.totalReturned,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>?)
            ?.map((e) => ArticleListItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return FeedResponse(
      items: list,
      nextCursor: json['next_cursor'] as String?,
      totalReturned: json['total_returned'] as int? ?? list.length,
    );
  }
}
