import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';

class StorageLoadingIndicator extends ConsumerWidget {
  const StorageLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = 1 != 1;
    return !isLoading
        ? const Icon(Icons.link)
        : const LoadingIndicator(indicatorType: Indicator.ballClipRotateMultiple);
  }
}
