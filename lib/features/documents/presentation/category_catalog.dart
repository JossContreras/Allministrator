import 'package:flutter/material.dart';

class CategoryVisual {
  const CategoryVisual(this.id, this.name, this.color);
  final String id, name;
  final Color color;
}

abstract final class CategoryCatalog {
  static const values = [
    CategoryVisual('personal', 'Personal', Color(0xFF5B8DEF)),
    CategoryVisual('trabajo', 'Trabajo', Color(0xFF8B6FC8)),
    CategoryVisual('estudio', 'Estudio', Color(0xFF2E9D88)),
    CategoryVisual('ideas', 'Ideas', Color(0xFFE19A3E)),
    CategoryVisual('proyectos', 'Proyectos', Color(0xFFD66B79)),
    CategoryVisual('none', 'Sin categoría', Color(0xFF78909C)),
  ];
  static CategoryVisual resolve(String? id) =>
      values.firstWhere((item) => item.id == id, orElse: () => values.last);
}
