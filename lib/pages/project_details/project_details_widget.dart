import 'package:flutter/material.dart';
import '/pages/investments/investment_pages.dart';

/// Legacy route kept for deep links; now shows the V2 project detail
/// (no ROI, eligibility + risk disclosure before investing).
class ProjectDetailsWidget extends StatelessWidget {
  final String projectId;

  const ProjectDetailsWidget({
    super.key,
    required this.projectId,
  });

  static String routeName = 'ProjectDetails';
  static String routePath = '/projectDetails';

  @override
  Widget build(BuildContext context) => ProjectDetailPage(id: projectId);
}
