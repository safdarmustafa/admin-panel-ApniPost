import 'package:apnipost_admin/shared/widgets/placeholder_page.dart';
import 'package:flutter/material.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Overview',
      message:
          'Dashboard metrics will appear here once real Supabase data access '
          'is wired. No fake analytics are shown.',
      icon: Icons.dashboard_outlined,
    );
  }
}
