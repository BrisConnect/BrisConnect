import 'package:flutter/material.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class Task {
  String title;
  bool isDone;
  Task({required this.title, this.isDone = false});
}

class ProjectDetailScreen extends StatefulWidget {
  final String projectName;

  const ProjectDetailScreen({super.key, required this.projectName});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final List<Task> tasks = [];
  String status = 'In Progress';
  String description = 'No description yet. Tap the edit button to add one.';

  final List<String> statusOptions = ['Not Started', 'In Progress', 'Completed'];

  void _addTaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => tasks.add(Task(title: controller.text)));
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editDescriptionDialog() {
    final controller = TextEditingController(text: description);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Description'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Project description'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => description = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTask(int index) {
    setState(() => tasks.removeAt(index));
  }

  int get completedCount => tasks.where((t) => t.isDone).length;

  @override
  Widget build(BuildContext context) {
    final progress = tasks.isEmpty ? 0.0 : completedCount / tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: LogoAppBarTitle(widget.projectName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Description',
            onPressed: _editDescriptionDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: status,
                  underline: const SizedBox(),
                  items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => status = val!),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
            const SizedBox(height: 16),

            // Progress bar
            Row(
              children: [
                const Text('Progress: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$completedCount / ${tasks.length} tasks'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),

            // Tasks header
            const Text(
              'Tasks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Task list
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      child: Text(
                        'No tasks yet.\nTap + to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Card(
                          child: ListTile(
                            leading: Checkbox(
                              value: task.isDone,
                              onChanged: (val) => setState(() => task.isDone = val!),
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.isDone ? TextDecoration.lineThrough : null,
                                color: task.isDone ? Colors.grey : Colors.black87,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteTask(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTaskDialog,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
