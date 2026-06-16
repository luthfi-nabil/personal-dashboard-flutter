import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

class AppMenuDrawer extends ConsumerWidget {
  final String currentPath;

  const AppMenuDrawer({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppTheme.colorsOf(context);
    final username = ref.watch(configProvider.select((cfg) => cfg.username));
    final title =
        username.trim().isEmpty ? 'Personal Dashboard' : username.trim();
    return Drawer(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        'PD',
                        style: TextStyle(
                          color: c.bg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.line2, height: 1),
            _MenuTile(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              label: 'Finance',
              route: '/',
              selected: !currentPath.startsWith('/insulin') &&
                  currentPath != '/settings',
              c: c,
            ),
            _MenuTile(
              icon: Icons.vaccines_outlined,
              selectedIcon: Icons.vaccines_rounded,
              label: 'Insulin',
              route: '/insulin',
              selected: currentPath.startsWith('/insulin'),
              c: c,
            ),
            _MenuTile(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings',
              route: '/settings',
              selected: currentPath == '/settings',
              c: c,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  final bool selected;
  final AppColors c;

  const _MenuTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    required this.selected,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? c.ink : c.muted;
    return ListTile(
      leading: Icon(selected ? selectedIcon : icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      onTap: () {
        Navigator.pop(context);
        if (!selected) context.go(route);
      },
    );
  }
}
