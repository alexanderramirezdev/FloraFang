#!/bin/bash
#
# rename-to-florafang.sh
#
# Swaps every Quadrat reference in the source to FloraFang.
#
# WHAT THIS DOES NOT DO (Xcode has to do these itself, see below):
#   - rename the .xcodeproj, the target, or the scheme
#   - change the bundle identifier
#   - rename the enclosing folder
#
# RUN IT FROM the project source folder, the one containing the .swift files.
# Make sure everything is committed first so you can diff or revert.
#
# Usage:  bash rename-to-florafang.sh
#

set -e

if ! ls *.swift >/dev/null 2>&1; then
  echo "No .swift files here. cd into the folder with your source first."
  exit 1
fi

echo "Backing up to ../florafang-rename-backup/"
mkdir -p ../florafang-rename-backup
cp *.swift ../florafang-rename-backup/ 2>/dev/null || true
cp *.md ../florafang-rename-backup/ 2>/dev/null || true

echo "Renaming identifiers and strings..."

# Order matters: do the all-caps and app-identity forms before the generic
# lowercase pass, or the earlier ones get half-replaced.
for f in *.swift *.md; do
  [ -e "$f" ] || continue

  # App identity
  sed -i '' 's/QUADRAT/FLORAFANG/g'                        "$f"
  sed -i '' 's/QuadratApp/FloraFangApp/g'                  "$f"
  sed -i '' 's/\[Quadrat\]/[FloraFang]/g'                  "$f"
  sed -i '' 's/Quadrat/FloraFang/g'                        "$f"

  # The quadrat metaphor in code identifiers. The sampling-square reference
  # no longer connects to anything now that the name changed, so these become
  # plainly descriptive instead.
  sed -i '' 's/croppedToQuadrat/croppedToFrame/g'          "$f"
  sed -i '' 's/quadratFrame/captureFrame/g'                "$f"
  sed -i '' 's/quadrat square/capture square/g'            "$f"
  sed -i '' 's/quadrat-training/florafang-training/g'      "$f"
  sed -i '' 's/quadrat/capture frame/g'                    "$f"
done

echo "Renaming files..."
[ -f QuadratApp.swift ] && mv QuadratApp.swift FloraFangApp.swift

echo
echo "Done. Now check these by hand:"
echo
echo "  1. The tagline in CameraScreen.swift still says 'a closer look at"
echo "     what's around you'. That was written for the old name. Decide"
echo "     whether it still fits."
echo
echo "  2. Any comment that reads oddly after 'quadrat' became 'capture"
echo "     frame'. Run: grep -rn 'capture frame' *.swift"
echo
echo "  3. README.md has a Naming section explaining the quadrat metaphor."
echo "     That whole section needs rewriting, not find-and-replace."
echo
echo "  4. Info.plist camera usage string, set in Xcode not here."
echo
echo "Then diff against ../florafang-rename-backup/ before committing."
