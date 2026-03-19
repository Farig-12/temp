class Post {
  final String id;
  final String userId;
  final String username;
  final String content;
  final String status;
  final DateTime createdAt;
  final List<Like> likes;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.likes,
    required this.comments,
  });

  //------------------------
  Post copyWith({
    String? id,
    String? userId,
    String? username,
    String? content,
    String? status,
    DateTime? createdAt,
    List<Like>? likes,
    List<Comment>? comments,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
    );
  }
  //------------------------

  factory Post.fromJson(Map<String, dynamic> json) {
    // Handle date parsing - can be string or already DateTime
    DateTime parseDate(dynamic dateValue) {
      if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else {
        throw FormatException('Invalid date format: $dateValue');
      }
    }

    // Validate and extract post ID
    final postId = json['id'] as String?;
    if (postId == null || postId.isEmpty) {
      throw FormatException('Post ID is missing or empty in JSON: $json');
    }

    return Post(
      id: postId,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      content: json['content'] as String,
      status: (json['status'] ?? 'pending') as String,
      createdAt: parseDate(json['created_at']),
      likes: (json['likes'] as List<dynamic>?)
              ?.map((like) => Like.fromJson(like as Map<String, dynamic>))
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((comment) =>
                  Comment.fromJson(comment as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'content': content,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'likes': likes.map((like) => like.toJson()).toList(),
      'comments': comments.map((comment) => comment.toJson()).toList(),
    };
  }
}

class Like {
  final String userId;
  final DateTime likedAt;

  Like({
    required this.userId,
    required this.likedAt,
  });

  factory Like.fromJson(Map<String, dynamic> json) {
    // Handle date parsing - can be string or already DateTime
    dynamic dateValue = json['liked_at'];
    DateTime likedAt;
    if (dateValue is DateTime) {
      likedAt = dateValue;
    } else if (dateValue is String) {
      likedAt = DateTime.parse(dateValue);
    } else {
      throw FormatException('Invalid date format: $dateValue');
    }

    return Like(
      userId: json['user_id'] as String,
      likedAt: likedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'liked_at': likedAt.toIso8601String(),
    };
  }
}

class Comment {
  final String userId;
  final String username;
  final String comment;
  final String status;
  final DateTime commentedAt;

  Comment({
    required this.userId,
    required this.username,
    required this.comment,
    required this.status,
    required this.commentedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Handle date parsing - can be string or already DateTime
    dynamic dateValue = json['commented_at'];
    DateTime commentedAt;
    if (dateValue is DateTime) {
      commentedAt = dateValue;
    } else if (dateValue is String) {
      commentedAt = DateTime.parse(dateValue);
    } else {
      throw FormatException('Invalid date format: $dateValue');
    }

    return Comment(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      comment: json['comment'] as String,
      status: (json['status'] ?? 'pending') as String,
      commentedAt: commentedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'comment': comment,
      'status': status,
      'commented_at': commentedAt.toIso8601String(),
    };
  }
}
