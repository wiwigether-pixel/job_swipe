import 'package:flutter/material.dart';
import '../../../shared/models/job_model.dart';
import '../../../shared/widgets/swipe_card_wrapper.dart';
import 'job_card.dart';

/// 職缺卡片疊層
/// 職責：把 JobModel 列表轉成 JobCard Widget 列表，傳給 SwipeCardWrapper
class SwipeCardStack extends StatelessWidget {
  const SwipeCardStack({
    super.key,
    required this.jobs,
    required this.onSwipe,
    required this.controller,
    this.onEmpty,
  });

  final List<JobModel> jobs;
  final void Function(JobModel job, bool isLike) onSwipe;
  final SwipeController controller;
  final VoidCallback? onEmpty;

  @override
  Widget build(BuildContext context) {
    return SwipeCardWrapper(
      controller: controller,
      cards: jobs.map((job) => JobCard(job: job)).toList(),
      onEmpty: onEmpty,
      onSwipe: (index, direction) {
        if (index >= jobs.length) return;
        final job = jobs[index];
        final isLike = direction == SwipeDirection.right;
        onSwipe(job, isLike);
      },
    );
  }
}