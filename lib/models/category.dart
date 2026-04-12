import 'package:flutter/material.dart';

class Category {
  final String name;
  final String value;
  final IconData icon;
  final Color color; // Add color parameter

  Category({required this.name, required this.value, required this.icon, required this.color});
}