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
// topPad=14 is applied inside the bubble so the rotated frame never bleeds
// into the gap above; kImageCenterY accounts for that offset.
// Approximations for a ~360 dp wide screen.
const kImageCenterX = 180.0; // ≈ screenWidth / 2
const kImageCenterY = 134.0; // ≈ topPad(20) + (screenWidth-24)*0.68/2
