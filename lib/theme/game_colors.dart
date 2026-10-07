import 'package:flutter/material.dart';

/// Every colour used by Last Move lives here so the whole game can be
/// re-skinned from a single file.
class GameColors {
  const GameColors._();

  // Backgrounds.
  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF141B2E);
  static const Color surfaceHigh = Color(0xFF1E2942);
  static const Color surfaceBorder = Color(0xFF2A3A5E);

  // Arena.
  static const Color board = Color(0xFF111A2E);
  static const Color boardBorder = Color(0xFF2A3A5E);
  static const Color gridLine = Color(0xFF1E2A45);

  // Entities.
  static const Color player = Color(0xFF22D3EE);
  static const Color playerGlow = Color(0xFF0EA5B7);
  static const Color playerHighlight = Color(0xFFCFFAFE);
  static const Color playerTrail = Color(0xFF123349);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBright = Color(0xFFFDE68A);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBright = Color(0xFFFF8A8A);

  static const Color block = Color(0xFF475569);
  static const Color blockEdge = Color(0xFF64748B);

  static const Color movingBlock = Color(0xFF7C8CA6);
  static const Color movingBlockMarker = Color(0xFFE2E8F0);

  static const Color shrinkDanger = Color(0xFF6B1420);
  static const Color shrinkWarning = Color(0xFF8A4B12);

  // Exit - the level's goal. Deliberately a green nobody else uses, so "that is
  // where I have to go" reads instantly even on a busy board.
  static const Color exit = Color(0xFF10B981);
  static const Color exitBright = Color(0xFF6EE7B7);
  static const Color exitCore = Color(0xFF052E23);

  // Text + accents.
  static const Color textPrimary = Color(0xFFE7ECF5);
  static const Color textSecondary = Color(0xFF8FA0BE);
  static const Color accent = Color(0xFF22D3EE);
  static const Color success = Color(0xFF34D399);
  static const Color dangerText = Color(0xFFFCA5A5);
}
