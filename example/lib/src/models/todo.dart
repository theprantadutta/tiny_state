/// A simple Todo model.
class Todo {
  Todo({required this.title, this.completed = false, required this.id});

  final String id;
  final String title;
  bool completed;
}
