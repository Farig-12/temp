import 'post.dart';

class Guide {
  final String id;
  final String userId;
  final String username;
  final String title;
  final String description;
  final String steps;
  final String solution;
  final String? partsTools;
  final String? cost;
  final String? mechanicRecommendation;
  final List<String> imageUrls;
  final DateTime createdAt;
  final List<Like> likes;
  final List<Comment> comments;

  Guide({
    required this.id,
    required this.userId,
    required this.username,
    required this.title,
    required this.description,
    required this.steps,
    required this.solution,
    this.partsTools,
    this.cost,
    this.mechanicRecommendation,
    required this.imageUrls,
    required this.createdAt,
    required this.likes,
    required this.comments,
  });

  Guide copyWith({
    String? id,
    String? userId,
    String? username,
    String? title,
    String? description,
    String? steps,
    String? solution,
    String? partsTools,
    String? cost,
    String? mechanicRecommendation,
    List<String>? imageUrls,
    DateTime? createdAt,
    List<Like>? likes,
    List<Comment>? comments,
  }) {
    return Guide(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      title: title ?? this.title,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      solution: solution ?? this.solution,
      partsTools: partsTools ?? this.partsTools,
      cost: cost ?? this.cost,
      mechanicRecommendation: mechanicRecommendation ?? this.mechanicRecommendation,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
    );
  }

  factory Guide.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else {
        throw FormatException('Invalid date format: $dateValue');
      }
    }

    final guideId = json['id'] as String?;
    if (guideId == null || guideId.isEmpty) {
      throw FormatException('Guide ID is missing or empty in JSON: $json');
    }

    return Guide(
      id: guideId,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      steps: json['steps'] as String? ?? '',
      solution: json['solution'] as String? ?? '',
      partsTools: json['parts_tools'] as String?,
      cost: json['cost'] as String?,
      mechanicRecommendation: json['mechanic_recommendation'] as String?,
      imageUrls: (json['image_urls'] as List<dynamic>?)
              ?.map((url) => url as String)
              .toList() ??
          [],
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
      'title': title,
      'description': description,
      'steps': steps,
      'solution': solution,
      'parts_tools': partsTools,
      'cost': cost,
      'mechanic_recommendation': mechanicRecommendation,
      'image_urls': imageUrls,
      'created_at': createdAt.toIso8601String(),
      'likes': likes.map((like) => like.toJson()).toList(),
      'comments': comments.map((comment) => comment.toJson()).toList(),
    };
  }
}

