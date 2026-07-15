import 'package:flutter/material.dart';

class CategoryVisual {
  const CategoryVisual(this.id, this.name, this.color, this.icon);

  final String id;
  final String name;
  final Color color;
  final IconData icon;
}

abstract final class CategoryCatalog {
  static const values = [
    CategoryVisual(
      'personal',
      'Personal',
      Color(0xFF4F7FD7),
      Icons.self_improvement_outlined,
    ),
    CategoryVisual(
      'trabajo',
      'Trabajo',
      Color(0xFF8065B7),
      Icons.work_outline_rounded,
    ),
    CategoryVisual(
      'estudio',
      'Estudio',
      Color(0xFF278A75),
      Icons.school_outlined,
    ),
    CategoryVisual(
      'ideas',
      'Ideas',
      Color(0xFFD4892F),
      Icons.lightbulb_outline_rounded,
    ),
    CategoryVisual(
      'proyectos',
      'Proyectos',
      Color(0xFFC85D6A),
      Icons.rocket_launch_outlined,
    ),
    CategoryVisual(
      'archivos',
      'Archivos',
      Color(0xFF397D9B),
      Icons.folder_copy_outlined,
    ),
    CategoryVisual(
      'none',
      'Sin categoría',
      Color(0xFF6F7F87),
      Icons.inbox_outlined,
    ),
  ];

  static CategoryVisual resolve(String? id) =>
      values.firstWhere((item) => item.id == id, orElse: () => values.last);
}
