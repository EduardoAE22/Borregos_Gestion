import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
  const Loading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
