import 'package:flutter/material.dart';

class CategoryEntry {
  final String id;
  final Color color;
  final IconData icon;

  const CategoryEntry({required this.id, required this.color, required this.icon});

  // Icon codepoints only ever come from CategoryIconPresets (a fixed const
  // list also referenced literally in the icon picker UI), so Flutter's icon
  // tree-shaker keeps every glyph this can possibly reconstruct.
  factory CategoryEntry.fromJson(String id, Map<String, dynamic> j) => CategoryEntry(
    id: id,
    color: Color(j['color'] as int),
    icon: IconData(j['icon'] as int, fontFamily: 'MaterialIcons'),
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
