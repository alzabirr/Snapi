# Snapi

Snapi  V-1 
---------------
• Background Screenshot Detection — Automatically detects screenshots in the background.

• OCR / Text Extraction — Extracts text from screenshots using OCR.

• Smart AI Organization — Uses AI to auto-organize screenshots into categories.

• Voice Notes — Add voice reminders or notes to screenshots.

• Advanced Search — Search screenshots by text or category instantly.

• Category Management — Create custom folders and categories.

• Recycle Bin — Restore accidentally deleted screenshots.

• Push Notifications — Get alerts when a new screenshot is detected.

• Visual Explorer — Beautiful and organized screenshot gallery view.

===================================================================================

Snapi  V-2 
--------------


1. Export to PDF (Share as PDF)
Long-press any screenshot on the Home screen to enter multi-selection mode.
Selected items now display an Apple-style blue checkmark.
A Share icon appears in the top-right corner. Tapping it generates a PDF containing the selected screenshots along with their extracted text, then opens the system share dialog.
New file:
export_service.dart
New dependency:
pdf: ^3.10.7
2. About Snapi (Full Page)
The "Snapi Assistant" option in Settings has been renamed to "About Snapi".
Tapping it now opens a full-screen page instead of a bottom sheet.
All content has been converted to English, and the previous Bengali text has been removed.
Added detailed information about Snapi, including how it works, its purpose, and its motivation.
New file:
about_snapi_screen.dart
3. My Captures Header
Replaced CupertinoSliverNavigationBar with CupertinoNavigationBar, moving the My Captures header to the top of the screen.
4. Recent (Gallery Import) Header
Updated the Recent page header to match the My Captures design by replacing the sliver navigation bar with a standard navigation bar.
5. Folder Page Title
Updated the title displayed when opening a folder in My Folders to match the My Captures header style.
6. Selection Mode UI
Removed the floating bottom action bar that previously appeared during selection mode.
Moved the Share action to the top-right corner for a cleaner, more consistent interface.