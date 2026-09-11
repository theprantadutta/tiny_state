/// A simple Todo model.
class Todo {
  const Todo({required this.id, required this.title, this.completed = false});

  /// Rebuilds a todo from the map [toJson] produced.
  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    completed: json['completed'] as bool,
  );

  final String id;
  final String title;
  final bool completed;

  /// Returns a copy with the given fields replaced.
  ///
  /// `tiny_state` compares with `==`, so state updates must produce a new
  /// value rather than mutating the existing one.
  Todo copyWith({bool? completed}) =>
      Todo(id: id, title: title, completed: completed ?? this.completed);

  /// Converts this todo into JSON-encodable data.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
  };

  @override
  bool operator ==(Object other) =>
      other is Todo &&
      other.id == id &&
      other.title == title &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(id, title, completed);
}
