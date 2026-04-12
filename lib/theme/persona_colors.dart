import 'package:flutter/material.dart';

const kPersonaRed = Color(0xFFC41001);
const kPersonaDarkRed = Color(0xFF6C0100);

// Transcript layout constants (mirrors TranscriptSizes in the reference)
const kAvatarWidth = 110.0;
const kAvatarHeight = 90.0;
const kEntrySpacing = 16.0;
const kRenMessageCenterX = 60.0;
const kRenMessageCenterY = 28.0;
const kMinLineWidth = 44.0;
const kMaxLineWidth = 60.0;

// Image bubble layout constants
// Frame fills ~screen width (screenWidth - 24), centered.
// The frame is rotated –4.5°: its top border at the connecting line's x-range
// (≈154..206 dp) sits at y ≈ 22..28 dp in the widget's coordinate space.
// kImageCenterY must be > 28 so the line terminus falls inside the frame with
// no visible gap.  35 dp gives a comfortable ~7 dp margin across screen sizes.
// The transparent topPad (0..20 dp) above the frame stays clear, so the
// connecting-line shadow (+10 dp offset) is visible there.
const kImageCenterX = 180.0; // ≈ screenWidth / 2
const kImageCenterY = 35.0;  // inside the frame top — eliminates the gap
