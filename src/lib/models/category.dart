import 'package:flutter/material.dart';
import '../utils/category_helpers.dart';

class CategoryEntry {
  final String id;
  final Color color;
  final IconData icon;

  const CategoryEntry({required this.id, required this.color, required this.icon});

  // Icon codepoints only ever come from categoryIconPresets (a fixed const
  // list also referenced literally in the icon picker UI), so instead of
  // constructing a new IconData from the stored int (which the icon
  // tree-shaker can't verify as constant), look up the matching literal
  // constant from that list.
  factory CategoryEntry.fromJson(String id, Map<String, dynamic> j) => CategoryEntry(
    id: id,
    color: Color(j['color'] as int),
    icon: categoryIconPresets.firstWhere(
      (i) => i.codePoint == j['icon'] as int,
      orElse: () => categoryIconPresets.first,
    ),
  );

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'icon': icon.codePoint,
  };

  CategoryEntry copyWith({Color? color, IconData? icon}) => CategoryEntry(
    id: id,
    color: color ?? this.color,
    icon: icon ?? this.icon,
  );
}
