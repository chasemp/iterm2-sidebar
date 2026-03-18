#!/bin/bash
# Usage: ./add_source.sh <file_path> <build_ref_id> <file_ref_id> [target: app|test]
# Adds a Swift file to the Xcode project's source build phase.
# Example: ./add_source.sh Styx/Models/Workspace.swift A10004 B10004 app

PBXPROJ="Styx.xcodeproj/project.pbxproj"
FILE_PATH="$1"
BUILD_REF="$2"
FILE_REF="$3"
TARGET="${4:-app}"
FILE_NAME=$(basename "$FILE_PATH")

# Add PBXBuildFile entry
sed -i '' "s|/\* End PBXBuildFile section \*/|		${BUILD_REF} /* ${FILE_NAME} in Sources */ = {isa = PBXBuildFile; fileRef = ${FILE_REF}; };\n/* End PBXBuildFile section */|" "$PBXPROJ"

# Add PBXFileReference entry
sed -i '' "s|/\* End PBXFileReference section \*/|		${FILE_REF} /* ${FILE_NAME} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${FILE_NAME}; sourceTree = \"<group>\"; };\n/* End PBXFileReference section */|" "$PBXPROJ"

# Add to appropriate Sources build phase
if [ "$TARGET" = "test" ]; then
    # Add to StyxTests Sources (S10002)
    sed -i '' "/A10201.*StyxTests.swift/a\\
\\				${BUILD_REF} /* ${FILE_NAME} in Sources */,
" "$PBXPROJ"
else
    # Add to Styx Sources (S10001)
    sed -i '' "/A10001.*StyxApp.swift/a\\
\\				${BUILD_REF} /* ${FILE_NAME} in Sources */,
" "$PBXPROJ"
fi

echo "Added ${FILE_NAME} to ${TARGET} target"
