import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GenericCard<T> extends StatelessWidget {
  final T data;
  final String Function(T) getTag;
  final String Function(T) getTitle;
  final String Function(T) getSubtitle;
  final String Function(T)? getCode;
  final bool Function(T)? getIsPublic;
  final VoidCallback onTap;
  final String actionLabel;
  final Color? tagBgColor;
  final Color? tagTextColor;

  const GenericCard({
    Key? key,
    required this.data,
    required this.getTag,
    required this.getTitle,
    required this.getSubtitle,
    this.getCode,
    this.getIsPublic,
    required this.onTap,
    this.actionLabel = 'Xem chi tiết',
    this.tagBgColor,
    this.tagTextColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (getIsPublic != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: getIsPublic!(data)
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            getIsPublic!(data) ? 'PUBLIC' : 'PRIVATE',
                            style: TextStyle(
                              color: getIsPublic!(data)
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      getTitle(data),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getSubtitle(data),
                      // Đã sửa lỗi slateGrey thành Colors.blueGrey chuẩn của Flutter
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                    if (getCode != null && getCode!(data).isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mã: ${getCode!(data)}',
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sao chép mã đề',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy_outlined, size: 17),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: getCode!(data)),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép mã đề.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Nút hành động (Bắt đầu thi / Xem kết quả)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
