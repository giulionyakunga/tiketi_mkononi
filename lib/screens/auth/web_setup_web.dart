import 'package:flutter/foundation.dart';
import 'dart:html' as html;

String getOS() {
  if (!kIsWeb) return "Not running on web";

  // Web-specific OS detection
  try {
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      
      if (userAgent.contains("windows")) return "Windows";
      if (userAgent.contains("mac os")) return "macOS";
      if (userAgent.contains("linux")) return "Linux";
      if (userAgent.contains("android")) return "Android";
      if (userAgent.contains("iphone") || userAgent.contains("ipad")) return "iOS";
    }
  } catch (e) {
    return "Unknown OS (Web)";
  }

  return "Unknown OS";
}
