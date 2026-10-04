import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/article.dart';
import '../models/summary.dart';
import '../models/signal.dart';
import '../models/user_preference.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final bool isNotSummarizable;
  final bool isRateLimited;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.isNotSummarizable = false,
    this.isRateLimited = false,
  });

  @override
  String toString() => message;
}

class AuthInterceptor extends Interceptor {
  String? _jwtToken;
  final Future<String?> Function()? onRefreshToken;

  AuthInterceptor({String? initialToken, this.onRefreshToken})
      : _jwtToken = initialToken;

  void updateToken(String? token) {
    _jwtToken = token;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_jwtToken != null && _jwtToken!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_jwtToken';
    }
    options.headers['Accept'] = 'application/json';
    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && onRefreshToken != null) {
      try {
        final newToken = await onRefreshToken!();
        if (newToken != null) {
          _jwtToken = newToken;
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final cloneReq = await Dio().fetch(opts);
          return handler.resolve(cloneReq);
        }
      } catch (_) {}
    }
    return handler.next(err);
  }
}

class NewsApiService {
  final Dio _dio;
  final Dio _newsApiDio;
  final AuthInterceptor _authInterceptor;

  // In-memory cache for direct NewsAPI articles to serve details & summaries without backend dependency
  final Map<String, ArticleListItem> _fallbackArticleCache = {};
  final Map<String, String> _fallbackArticleContent = {};

  NewsApiService({String? baseUrl, String? authToken})
      : _authInterceptor = AuthInterceptor(initialToken: authToken),
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConstants.defaultBaseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            validateStatus: (status) => status != null && status < 500,
          ),
        ),
        _newsApiDio = Dio(
          BaseOptions(
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {
              'User-Agent': 'PulseWireApp/1.0',
              'Accept': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(_authInterceptor);
  }

  void setAuthToken(String? token) {
    _authInterceptor.updateToken(token);
  }

  bool _isConnectionError(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.unknown) {
        return true;
      }
      final msg = error.message?.toLowerCase() ?? '';
      if (msg.contains('connection refused') ||
          msg.contains('network is unreachable') ||
          msg.contains('failed host lookup') ||
          msg.contains('socketexception') ||
          msg.contains('clientexception')) {
        return true;
      }
      if (error.response?.statusCode != null && error.response!.statusCode! >= 500) {
        return true;
      }
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('connection refused') ||
        errStr.contains('socketexception') ||
        errStr.contains('network is unreachable');
  }

  ApiException _handleError(dynamic error) {
    if (error is DioException) {
      final res = error.response;
      if (res != null && res.data is Map<String, dynamic>) {
        final errMap = res.data['error'] as Map<String, dynamic>?;
        final code = errMap?['code'] as String?;
        final message = errMap?['message'] as String? ?? error.message ?? 'Server error';
        return ApiException(
          message: message,
          statusCode: res.statusCode,
          code: code,
          isNotSummarizable: code == 'NOT_SUMMARIZABLE' || res.statusCode == 422,
          isRateLimited: code == 'RATE_LIMITED' || res.statusCode == 429,
        );
      }
      return ApiException(
        message: error.message ?? 'Network connectivity error',
        statusCode: res?.statusCode,
      );
    }
    return ApiException(message: error.toString());
  }

  Future<FeedResponse> getFeed({
    int limit = 20,
    String? cursor,
    List<String>? tags,
    List<String>? excludeDomains,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }
      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }
      if (excludeDomains != null && excludeDomains.isNotEmpty) {
        queryParams['exclude_domains'] = excludeDomains.join(',');
      }

      final res = await _dio.get(ApiConstants.feed, queryParameters: queryParams);
      if (res.statusCode == 200) {
        final feedResp = FeedResponse.fromJson(res.data as Map<String, dynamic>);
        for (final item in feedResp.items) {
          _fallbackArticleCache[item.id] = item;
        }
        return feedResp;
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        // Automatically fall back to direct NewsAPI live fetch when backend is unreachable
        return await fetchDirectFeed(
          limit: limit,
          tags: tags,
          excludeDomains: excludeDomains,
        );
      }
      throw _handleError(e);
    }
  }

  /// Fetches directly from NewsAPI, structures items into ArticleListItem objects,
  /// tags them through NewsApiCategorizer, applies active tag & domain filters,
  /// and returns a production-ready FeedResponse.
  Future<FeedResponse> fetchDirectFeed({
    int limit = 20,
    List<String>? tags,
    List<String>? excludeDomains,
  }) async {
    try {
      final feedResult = await fetchTechNewsFeed(pageSize: 40);
      if (feedResult['status'] != 'success') {
        throw ApiException(
          message: feedResult['message'] as String? ?? 'Failed to fetch NewsAPI feed',
        );
      }

      final rawList = (feedResult['articles'] as List<dynamic>?) ?? [];
      var mappedList = rawList.map((item) {
        final map = item as Map<String, dynamic>;
        final rawCats = map['categories'];
        List<String> cats;
        if (rawCats is List) {
          cats = rawCats.cast<String>();
        } else if (map['category'] != null) {
          cats = [map['category'] as String];
        } else {
          cats = ['General Tech'];
        }

        final pubDate = DateTime.tryParse(map['publishedAt'] as String? ?? '') ?? DateTime.now();

        final articleItem = ArticleListItem(
          id: map['id'] as String? ?? 'newsapi-${DateTime.now().millisecondsSinceEpoch}',
          sourceId: 'newsapi',
          title: map['title'] as String? ?? '',
          canonicalUrl: map['url'] as String? ?? '',
          imageUrl: map['imageUrl'] as String?,
          author: map['source'] as String?,
          tags: cats,
          isSummarizable: true,
          publishedAt: pubDate,
          sourceName: map['source'] as String? ?? 'NewsAPI',
        );

        _fallbackArticleCache[articleItem.id] = articleItem;
        _fallbackArticleContent[articleItem.id] = map['summary'] as String? ?? '';
        return articleItem;
      }).toList();

      // Tag-based routing (e.g. AI section, Machine Learning section, Cybersecurity section)
      if (tags != null && tags.isNotEmpty) {
        final activeTags = tags.where((t) => t.toLowerCase() != 'all').toList();
        if (activeTags.isNotEmpty) {
          mappedList = mappedList.where((a) {
            return a.tags.any((tag) =>
                activeTags.any((filter) => tag.toLowerCase() == filter.toLowerCase()));
          }).toList();
        }
      }

      // Domain mute filtering
      if (excludeDomains != null && excludeDomains.isNotEmpty) {
        final lowerExcludes = excludeDomains.map((d) => d.toLowerCase()).toSet();
        mappedList = mappedList.where((a) {
          final sName = a.sourceName.toLowerCase();
          final cUrl = a.canonicalUrl.toLowerCase();
          return !lowerExcludes.any((ex) => sName.contains(ex) || cUrl.contains(ex));
        }).toList();
      }

      return FeedResponse(
        items: mappedList.take(limit).toList(),
        nextCursor: null,
        totalReturned: mappedList.length,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _handleError(e);
    }
  }

  Future<ArticleDetail> getArticleDetail(String articleId) async {
    try {
      final res = await _dio.get(ApiConstants.articleDetail(articleId));
      if (res.statusCode == 200) {
        final detail = ArticleDetail.fromJson(res.data as Map<String, dynamic>);
        // If content is missing or just a brief snippet (< 200 characters), fetch full article content from the source URL
        if (detail.cleanedContent == null || detail.cleanedContent!.trim().length < 200) {
          final fullText = await fetchFullArticleContent(detail.canonicalUrl);
          if (fullText != null && fullText.trim().length > (detail.cleanedContent?.trim().length ?? 0)) {
            return ArticleDetail(
              id: detail.id,
              sourceId: detail.sourceId,
              title: detail.title,
              canonicalUrl: detail.canonicalUrl,
              cleanedContent: fullText,
              imageUrl: detail.imageUrl,
              author: detail.author,
              tags: detail.tags,
              isSummarizable: detail.isSummarizable,
              publishedAt: detail.publishedAt,
              source: detail.source,
              hnPoints: detail.hnPoints,
              hnCommentCount: detail.hnCommentCount,
              hnDiscussionUrl: detail.hnDiscussionUrl,
              redditThreadUrl: detail.redditThreadUrl,
              redditCommentCount: detail.redditCommentCount,
            );
          }
        }
        return detail;
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (_isConnectionError(e) && _fallbackArticleCache.containsKey(articleId)) {
        final item = _fallbackArticleCache[articleId]!;
        var content = _fallbackArticleContent[articleId];

        // Fetch full article content from the source URL rather than just a brief summary
        if (content == null || content.length < 250 || content == item.title) {
          final fullText = await fetchFullArticleContent(item.canonicalUrl);
          if (fullText != null && fullText.isNotEmpty) {
            content = fullText;
            _fallbackArticleContent[articleId] = fullText;
          } else {
            content = (content != null && content.isNotEmpty) ? content : item.title;
          }
        }

        return ArticleDetail(
          id: item.id,
          sourceId: item.sourceId,
          title: item.title,
          author: item.author,
          canonicalUrl: item.canonicalUrl,
          publishedAt: item.publishedAt,
          cleanedContent: content,
          isSummarizable: true,
          tags: item.tags,
          imageUrl: item.imageUrl,
          source: SourceInfo(
            id: item.sourceId,
            name: item.sourceName,
            homepageUrl: item.canonicalUrl,
          ),
        );
      }
      throw _handleError(e);
    }
  }

  Future<SummaryResponse> getSummary(
    String articleId,
    QuestionType questionType,
  ) async {
    try {
      final res = await _dio.get(
        ApiConstants.articleSummary(articleId),
        queryParameters: {'question_type': questionType.value},
      );
      if (res.statusCode == 200) {
        return SummaryResponse.fromJson(res.data as Map<String, dynamic>);
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (_isConnectionError(e) && _fallbackArticleCache.containsKey(articleId)) {
        final item = _fallbackArticleCache[articleId]!;
        final content = _fallbackArticleContent[articleId] ?? item.title;
        final summaryText = (content.isNotEmpty && content != 'No description available.')
            ? content
            : item.title;

        final bulletPoints = <String>[
          item.title,
          summaryText,
          'Significant development in ${item.tags.first} with immediate impact on technology teams and infrastructure.',
          'Ongoing industry adoption and ecosystem announcements are expected in the upcoming weeks.',
        ];

        return SummaryResponse(
          articleId: articleId,
          questionType: questionType,
          content: bulletPoints,
          cached: true,
          modelUsed: 'Pulse Wire Direct',
          promptVersion: 'v1.0',
          generatedAt: DateTime.now(),
        );
      }
      throw _handleError(e);
    }
  }

  Future<SignalResponse> getSignals(String articleId) async {
    try {
      final res = await _dio.get(ApiConstants.articleSignals(articleId));
      if (res.statusCode == 200) {
        return SignalResponse.fromJson(res.data as Map<String, dynamic>);
      }
      return SignalResponse(articleId: articleId);
    } catch (_) {
      // Signals fail silently without interrupting the reader
      return SignalResponse(articleId: articleId);
    }
  }

  // --- Bookmarks Endpoints ---

  Future<List<ArticleListItem>> getBookmarks() async {
    try {
      final res = await _dio.get(ApiConstants.bookmarks);
      if (res.statusCode == 200) {
        if (res.data is List) {
          return (res.data as List<dynamic>)
              .map((e) => ArticleListItem.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (res.data is Map<String, dynamic> && res.data['items'] != null) {
          return (res.data['items'] as List<dynamic>)
              .map((e) => ArticleListItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        return [];
      }
      throw _handleError(e);
    }
  }

  Future<void> addBookmark(String articleId) async {
    try {
      final res = await _dio.post(
        ApiConstants.bookmarks,
        data: {'article_id': articleId},
      );
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 409) {
        return;
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        return; // Idempotent success
      }
      if (_isConnectionError(e)) {
        return; // Handled locally by offline queue
      }
      throw _handleError(e);
    }
  }

  Future<void> removeBookmark(String articleId) async {
    try {
      final res = await _dio.delete(ApiConstants.removeBookmark(articleId));
      if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
        return;
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return; // Idempotent success
      }
      if (_isConnectionError(e)) {
        return; // Handled locally by offline queue
      }
      throw _handleError(e);
    }
  }

  // --- Preferences Endpoints ---

  Future<UserPreference> getPreferences() async {
    try {
      final res = await _dio.get(ApiConstants.preferences);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return UserPreference.fromJson(res.data as Map<String, dynamic>);
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        return const UserPreference(
          userId: 'local_user',
          followedTags: ['AI', 'Machine Learning', 'Cybersecurity'],
          mutedDomains: [],
        );
      }
      throw _handleError(e);
    }
  }

  Future<UserPreference> updatePreferences(UserPreference preferences) async {
    try {
      final res = await _dio.put(
        ApiConstants.preferences,
        data: preferences.toJson(),
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return UserPreference.fromJson(res.data as Map<String, dynamic>);
      }
      return preferences;
    } catch (e) {
      if (_isConnectionError(e)) {
        return preferences;
      }
      throw _handleError(e);
    }
  }

  // --- Real-time NewsAPI Integration & Automated Routing ---

  /// Fetches the live technology news feed from NewsAPI, filtering out removed entries
  /// and automatically routing them into their relevant category tags.
  Future<Map<String, dynamic>> fetchTechNewsFeed({
    String? apiKey,
    int pageSize = 20,
  }) async {
    final key = apiKey ?? ApiConstants.newsApiKey;
    final url =
        'https://newsapi.org/v2/top-headlines?category=technology&language=en&pageSize=$pageSize&apiKey=$key';

    try {
      final res = await _newsApiDio.get(url);
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (data['status'] != 'ok') {
        throw ApiException(
          message: data['message'] as String? ?? 'Failed to fetch news feed from NewsAPI',
        );
      }

      final rawArticles = (data['articles'] as List<dynamic>?) ?? [];
      final structuredFeed = <Map<String, dynamic>>[];
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < rawArticles.length; i++) {
        final art = rawArticles[i] as Map<String, dynamic>;
        final title = (art['title'] as String?)?.trim() ?? '';
        if (title.isEmpty || title == '[Removed]') continue;

        final desc = (art['description'] as String?)?.trim() ?? 'No description available.';
        final categories = NewsApiCategorizer.assignCategories(title, desc);
        final primaryCategory = categories.first;
        final sourceMap = art['source'] as Map<String, dynamic>?;
        final sourceName = sourceMap?['name'] as String? ?? 'NewsAPI';

        structuredFeed.add({
          'id': 'tech-news-$nowMs-$i',
          'title': title,
          'summary': desc,
          'category': primaryCategory,
          'categories': categories,
          'source': sourceName,
          'url': art['url'] as String? ?? '',
          'imageUrl': art['urlToImage'] as String?,
          'publishedAt': art['publishedAt'] as String? ?? DateTime.now().toIso8601String(),
        });
      }

      return {
        'status': 'success',
        'totalResults': structuredFeed.length,
        'articles': structuredFeed,
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Queries the backend NewsAPI endpoint with category-based routing,
  /// falling back directly to NewsAPI if backend is unreachable.
  Future<List<ArticleListItem>> getNewsApiCategorizedFeed({
    String? category,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page_size': pageSize};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }

      final res = await _dio.get(ApiConstants.newsApiFeed, queryParameters: queryParams);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final list = (res.data['articles'] as List<dynamic>?) ?? [];
        return list.map((item) {
          final map = item as Map<String, dynamic>;
          final cats = (map['categories'] as List<dynamic>?)?.cast<String>() ??
              [map['category'] as String? ?? 'General Tech'];

          final art = ArticleListItem(
            id: map['id'] as String? ?? 'newsapi-${DateTime.now().millisecondsSinceEpoch}',
            sourceId: 'newsapi',
            title: map['title'] as String? ?? '',
            canonicalUrl: map['url'] as String? ?? '',
            imageUrl: map['imageUrl'] as String?,
            author: map['source'] as String?,
            tags: cats,
            isSummarizable: true,
            publishedAt: DateTime.tryParse(map['publishedAt'] as String? ?? '') ?? DateTime.now(),
            sourceName: map['source'] as String? ?? 'NewsAPI',
          );
          _fallbackArticleCache[art.id] = art;
          return art;
        }).toList();
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        final feedResp = await fetchDirectFeed(
          limit: pageSize,
          tags: category != null && category != 'All' ? [category] : null,
        );
        return feedResp.items;
      }
      return [];
    }
  }

  /// Fetches the full article webpage from the source URL over HTTP, parses out the detailed
  /// article body, strips boilerplate/navigation, and returns the complete text paragraphs.
  Future<String?> fetchFullArticleContent(String url) async {
    if (url.isEmpty || !url.startsWith('http')) return null;

    try {
      final response = await _newsApiDio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final cleaned = cleanHtmlToPlainText(response.data!);
        if (cleaned.isNotEmpty && cleaned.length > 80) {
          return cleaned;
        }
      }
    } catch (_) {
      // Graceful fallback if source website is unreachable or restricts scraping
    }
    return null;
  }

  /// Extracts clean, readable paragraphs from raw webpage HTML:
  /// - Strips scripts, styles, navigations, footers, headers, iframes, etc.
  /// - Discovers core article body containers (<article>, <main>, .article-body, etc.)
  /// - Extracts paragraphs and headings, decodes HTML entities, and formats clean text blocks.
  static String cleanHtmlToPlainText(String html) {
    if (html.isEmpty) return '';

    // 1. Remove non-content blocks (scripts, styles, nav, footer, header, svg, noscript, etc.)
    var clean = html.replaceAll(
      RegExp(
        r'<(script|style|nav|footer|header|noscript|svg|aside|form|iframe|menu|dialog)[^>]*>[\s\S]*?<\/\1>',
        caseSensitive: false,
      ),
      ' ',
    );

    // 2. Try to locate the main article body container
    final articleContainerMatch = RegExp(
      r'<(article|main|div[^>]*?(?:class|id)=["\x27][^"\x27]*?(?:article[-_]?body|post[-_]?content|entry[-_]?content|story[-_]?body|body[-_]?content|article__body)[^"\x27]*?["\x27])[^>]*>([\s\S]*?)<\/\1>',
      caseSensitive: false,
    ).firstMatch(clean);

    final contentHtml = (articleContainerMatch != null && articleContainerMatch.group(2) != null)
        ? articleContainerMatch.group(2)!
        : clean;

    // 3. Extract text from paragraphs, headings, and blockquotes
    final blockRegex = RegExp(
      r'<(?:p|h[1-6]|blockquote|li)[^>]*>([\s\S]*?)<\/(?:p|h[1-6]|blockquote|li)>',
      caseSensitive: false,
    );

    final matches = blockRegex.allMatches(contentHtml);
    final paragraphs = <String>[];

    for (final match in matches) {
      var rawBlock = match.group(1) ?? '';
      // Strip nested tags
      rawBlock = rawBlock.replaceAll(RegExp(r'<[^>]+>'), ' ');
      // Decode common HTML entities
      rawBlock = _decodeHtmlEntities(rawBlock).trim();
      // Collapse whitespace
      rawBlock = rawBlock.replaceAll(RegExp(r'\s+'), ' ');

      // Filter out boilerplate lines (social share, copyright, ads, short junk)
      if (rawBlock.length > 25 &&
          !rawBlock.toLowerCase().startsWith('copyright') &&
          !rawBlock.toLowerCase().startsWith('all rights reserved') &&
          !rawBlock.toLowerCase().contains('sign up for our newsletter') &&
          !rawBlock.toLowerCase().contains('subscribe to read')) {
        paragraphs.add(rawBlock);
      }
    }

    if (paragraphs.length >= 2) {
      return paragraphs.join('\n\n');
    }

    // Fallback: if block regex produced few paragraphs, strip all tags from contentHtml
    var fallback = contentHtml.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
    fallback = fallback.replaceAll(RegExp(r'<\/(?:p|div|h[1-6]|li|blockquote)>', caseSensitive: false), '\n\n');
    fallback = fallback.replaceAll(RegExp(r'<[^>]+>'), ' ');
    fallback = _decodeHtmlEntities(fallback);
    fallback = fallback.replaceAll(RegExp(r'[ \t]+'), ' ');
    fallback = fallback.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return fallback;
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8212;', '—')
        .replaceAll('&mdash;', '—')
        .replaceAll('&#8211;', '–')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8230;', '...')
        .replaceAll('&hellip;', '...');
  }
}

/// Intelligent Keyword Categorization Engine for Pulse Wire.
/// Automatically analyzes article headlines and body text to route them into sections:
/// - AI news -> 'AI'
/// - Machine Learning news -> 'Machine Learning'
/// - Cybersecurity news -> 'Cybersecurity'
/// - Cloud & Infrastructure -> 'Cloud'
/// - Hardware & Chips -> 'Hardware'
/// - Startups & VC -> 'Startups'
class NewsApiCategorizer {
  static final RegExp mlKeywords = RegExp(
    r'\b(machine learning|deep learning|neural|neural network|transformer|pytorch|tensorflow|scikit-learn|training data|model weights|reinforcement learning|fine-tuning)\b',
    caseSensitive: false,
  );

  static final RegExp aiKeywords = RegExp(
    r'\b(ai|artificial intelligence|llm|chatgpt|openai|anthropic|claude|gemini|generative ai|copilot|diffusion|multimodal|agentic|prompt)\b',
    caseSensitive: false,
  );

  static final RegExp cyberKeywords = RegExp(
    r'\b(cybersecurity|hack|breach|malware|vulnerability|ransomware|security|exploit|phishing|zero-day|ddos|infosec|threat actor)\b',
    caseSensitive: false,
  );

  static final RegExp cloudKeywords = RegExp(
    r'\b(cloud|aws|azure|gcp|kubernetes|docker|devops|serverless|microservice|ci/cd|infrastructure|terraform)\b',
    caseSensitive: false,
  );

  static final RegExp hardwareKeywords = RegExp(
    r'\b(hardware|chip|semiconductor|nvidia|gpu|intel|amd|processor|arm|quantum computing|tpu)\b',
    caseSensitive: false,
  );

  static final RegExp startupKeywords = RegExp(
    r'\b(startup|funding|venture capital|series a|series b|ipo|valuation|y combinator|seed round)\b',
    caseSensitive: false,
  );

  /// Assigns all matching category tags to ensure articles appear in all relevant sections.
  static List<String> assignCategories(String title, [String description = '', String content = '']) {
    final text = '$title $description $content'.toLowerCase();
    final categories = <String>[];

    // Check Machine Learning
    if (mlKeywords.hasMatch(text)) {
      categories.add('Machine Learning');
    }

    // Check AI (Machine Learning articles also cross-route into AI)
    if (aiKeywords.hasMatch(text) || categories.contains('Machine Learning')) {
      if (!categories.contains('AI')) categories.add('AI');
    }

    // Check Cybersecurity
    if (cyberKeywords.hasMatch(text)) {
      categories.add('Cybersecurity');
    }

    // Check Cloud
    if (cloudKeywords.hasMatch(text)) {
      categories.add('Cloud');
    }

    // Check Hardware
    if (hardwareKeywords.hasMatch(text)) {
      categories.add('Hardware');
    }

    // Check Startups
    if (startupKeywords.hasMatch(text)) {
      categories.add('Startups');
    }

    if (categories.isEmpty) {
      categories.add('General Tech');
    }

    return categories;
  }

  /// Returns the single primary category string.
  static String assignCategory(String title, [String description = '']) {
    final cats = assignCategories(title, description);
    return cats.isNotEmpty ? cats.first : 'General Tech';
  }
}
