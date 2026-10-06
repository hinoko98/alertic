import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Un destino de la barra inferior.
class NavItem {
  const NavItem({required this.label, required this.icon, this.badge = 0});

  final String label;
  final IconData icon;

  /// Cuántos avisos tiene pendientes. Con 0 no se dibuja nada.
  final int badge;
}

/// La barra inferior del diseño: icono con etiqueta y, en la pestaña activa, una
/// píldora rosada detrás del icono.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: _Tab(
                      item: items[i],
                      selected: i == index,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.brand : AppColors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0
          ? '${item.label}, ${item.badge} sin leer'
          : item.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.brandSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(item.icon, size: 22, color: color),
                ),
                if (item.badge > 0)
                  Positioned(
                    right: 4,
                    top: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                      child: Text(
                        item.badge > 9 ? '9+' : '${item.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onBrand,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
