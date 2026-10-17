import 'package:flutter/material.dart';

// Generic Layout Widget dùng chung cho toàn bộ màn hình trong ứng dụng
abstract class BaseLayoutScreen<T> extends StatelessWidget {
  final String title;
  final bool isLoading;
  final String? errorMessage;
  final T? data;
  final VoidCallback? onRefresh;
  final List<Widget>? actions;

  const BaseLayoutScreen({
    super.key,
    required this.title,
    this.isLoading = false,
    this.errorMessage,
    this.data,
    this.onRefresh,
    this.actions,
  });

  // Method trừu tượng bắt buộc các màn hình con định nghĩa giao diện chính
  Widget buildBody(BuildContext context, T? data);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: actions,
      ),
      body: _buildContent(context),
    );
  }

  // Quản lý các trạng thái chung: Loading -> Error -> Empty -> Content
  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            if (onRefresh != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRefresh,
                child: const Text('Thử lại'),
              )
            ]
          ],
        ),
      );
    }

    Widget content = buildBody(context, data);

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: content,
      );
    }

    return content;
  }
}