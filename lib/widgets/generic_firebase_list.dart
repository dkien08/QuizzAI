// lib/widgets/generic_firebase_list.dart
import 'package:flutter/material.dart';

import '../models/base_model.dart';
import '../services/firebase_repository.dart';

class GenericFirebaseList<T extends BaseModel> extends StatelessWidget {
  final FirebaseRepository<T> repository;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  const GenericFirebaseList({
    Key? key,
    required this.repository,
    required this.itemBuilder,
    this.emptyMessage = 'Chưa có dữ liệu.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: repository.getRealtimeList(),
      builder: (context, snapshot) {
        // Trạng thái đang tải
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Trạng thái bị lỗi
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Lỗi tải dữ liệu: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];

        // Trạng thái dữ liệu trống
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                emptyMessage,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Trạng thái thành công: Render danh sách
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => itemBuilder(context, items[index]),
        );
      },
    );
  }
}
