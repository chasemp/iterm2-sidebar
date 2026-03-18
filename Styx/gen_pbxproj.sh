#!/bin/zsh
# Generates a complete project.pbxproj from the actual files on disk.
# Run from the Styx/ directory (parent of Styx.xcodeproj).
set -e

PROJ="Styx.xcodeproj/project.pbxproj"

# Collect source files
APP_SOURCES=($(find Styx -name "*.swift" -type f | sort))
TEST_SOURCES=($(find Tests -name "*.swift" -type f | sort))

# Generate stable IDs from filenames
file_id() {
    echo -n "$1" | md5 | head -c 6 | tr 'a-f' 'A-F'
}

# Collect unique subdirectories under Styx/
typeset -A SUBDIRS
for f in "${APP_SOURCES[@]}"; do
    dir="${f:h}"  # zsh dirname
    dir="${dir#Styx/}"
    if [[ "$dir" != "Styx" && -n "$dir" && "$dir" != "$f" ]]; then
        SUBDIRS[$dir]=1
    fi
done

{
# Header
cat <<'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
EOF

for f in "${APP_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "		A${id} /* ${name} in Sources */ = {isa = PBXBuildFile; fileRef = B${id}; };"
done
for f in "${TEST_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "		A${id} /* ${name} in Sources */ = {isa = PBXBuildFile; fileRef = B${id}; };"
done

cat <<'EOF'
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		C10001 = {
			isa = PBXContainerItemProxy;
			containerPortal = P00001;
			proxyType = 1;
			remoteGlobalIDString = T10001;
			remoteInfo = Styx;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
EOF

for f in "${APP_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "		B${id} /* ${name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${name}; sourceTree = \"<group>\"; };"
done
for f in "${TEST_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "		B${id} /* ${name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${name}; sourceTree = \"<group>\"; };"
done

cat <<'EOF'
		B90016 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		B90017 /* Styx.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Styx.entitlements; sourceTree = "<group>"; };
		E10001 /* Styx.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Styx.app; sourceTree = BUILT_PRODUCTS_DIR; };
		E10002 /* StyxTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = StyxTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		F10001 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		F10002 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		G00001 = {
			isa = PBXGroup;
			children = (
				G10000 /* Styx */,
				G10500 /* Tests */,
				G90000 /* Products */,
			);
			sourceTree = "<group>";
		};
		G10000 /* Styx */ = {
			isa = PBXGroup;
			children = (
EOF

# Files directly in Styx/
for f in "${APP_SOURCES[@]}"; do
    dir="${f:h}"
    if [[ "$dir" == "Styx" ]]; then
        name="${f:t}"
        id=$(file_id "$f")
        echo "				B${id} /* ${name} */,"
    fi
done
echo "				B90016 /* Info.plist */,"
echo "				B90017 /* Styx.entitlements */,"

# Subgroup references
for dir in ${(ok)SUBDIRS}; do
    dir_id=$(file_id "group_${dir}")
    dir_name="${dir:t}"
    echo "				G${dir_id} /* ${dir_name} */,"
done

cat <<'EOF'
			);
			path = Styx;
			sourceTree = "<group>";
		};
EOF

# Subgroups
for dir in ${(ok)SUBDIRS}; do
    dir_id=$(file_id "group_${dir}")
    dir_name="${dir:t}"
    echo "		G${dir_id} /* ${dir_name} */ = {"
    echo "			isa = PBXGroup;"
    echo "			children = ("
    for f in "${APP_SOURCES[@]}"; do
        fdir="${f:h}"
        fdir="${fdir#Styx/}"
        if [[ "$fdir" == "$dir" ]]; then
            name="${f:t}"
            id=$(file_id "$f")
            echo "				B${id} /* ${name} */,"
        fi
    done
    echo "			);"
    echo "			path = ${dir};"
    echo "			sourceTree = \"<group>\";"
    echo "		};"
done

# Tests group
echo "		G10500 /* Tests */ = {"
echo "			isa = PBXGroup;"
echo "			children = ("
for f in "${TEST_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "				B${id} /* ${name} */,"
done
echo "			);"
echo "			path = Tests;"
echo "			sourceTree = \"<group>\";"
echo "		};"

cat <<'EOF'
		G90000 /* Products */ = {
			isa = PBXGroup;
			children = (E10001, E10002);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		T10001 /* Styx */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = X20001;
			buildPhases = (S10001, F10001, R10001, CP0001 /* Copy Bridge Scripts */);
			buildRules = ();
			dependencies = ();
			name = Styx;
			productName = Styx;
			productReference = E10001;
			productType = "com.apple.product-type.application";
		};
		T10002 /* StyxTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = X20002;
			buildPhases = (S10002, F10002);
			buildRules = ();
			dependencies = (D10001);
			name = StyxTests;
			productName = StyxTests;
			productReference = E10002;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		P00001 = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1540;
				LastUpgradeCheck = 1540;
				TargetAttributes = {
					T10001 = { CreatedOnToolsVersion = 15.4; };
					T10002 = { CreatedOnToolsVersion = 15.4; TestTargetID = T10001; };
				};
			};
			buildConfigurationList = X10001;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (en, Base);
			mainGroup = G00001;
			productRefGroup = G90000;
			projectDirPath = "";
			projectRoot = "";
			targets = (T10001, T10002);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		R10001 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXResourcesBuildPhase section */

/* Begin PBXShellScriptBuildPhase section */
		CP0001 /* Copy Bridge Scripts */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			inputPaths = (
				"$(SRCROOT)/StyxBridge/bridge_daemon.py",
				"$(SRCROOT)/StyxBridge/commands.py",
				"$(SRCROOT)/StyxBridge/requirements.txt",
			);
			name = "Copy Bridge Scripts";
			outputPaths = (
				"$(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/Contents/Resources/StyxBridge/bridge_daemon.py",
				"$(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/Contents/Resources/StyxBridge/commands.py",
				"$(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/Contents/Resources/StyxBridge/requirements.txt",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "mkdir -p \"${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/StyxBridge\"\ncp -f \"${SRCROOT}/StyxBridge/bridge_daemon.py\" \"${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/StyxBridge/\"\ncp -f \"${SRCROOT}/StyxBridge/commands.py\" \"${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/StyxBridge/\"\ncp -f \"${SRCROOT}/StyxBridge/requirements.txt\" \"${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/StyxBridge/\"\n";
		};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		S10001 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
EOF

for f in "${APP_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "				A${id} /* ${name} in Sources */,"
done

cat <<'EOF'
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		S10002 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
EOF

for f in "${TEST_SOURCES[@]}"; do
    name="${f:t}"
    id=$(file_id "$f")
    echo "				A${id} /* ${name} in Sources */,"
done

cat <<'EOF'
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		D10001 = {isa = PBXTargetDependency; target = T10001; targetProxy = C10001; };
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		X11001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ANALYZER_NONNULL = YES; CLANG_CXX_LANGUAGE_STANDARD = "gnu++20"; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_STRICT_OBJC_MSGSEND = YES; ENABLE_TESTABILITY = YES; GCC_DYNAMIC_NO_PIC = NO; GCC_OPTIMIZATION_LEVEL = 0; GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)"); MACOSX_DEPLOYMENT_TARGET = 14.0; MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG"; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; }; name = Debug; };
		X11002 /* Release */ = { isa = XCBuildConfiguration; buildSettings = { ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ANALYZER_NONNULL = YES; CLANG_CXX_LANGUAGE_STANDARD = "gnu++20"; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; ENABLE_NS_ASSERTIONS = NO; ENABLE_STRICT_OBJC_MSGSEND = YES; MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_COMPILATION_MODE = wholemodule; }; name = Release; };
		X21001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { CODE_SIGN_ENTITLEMENTS = Styx/Styx.entitlements; CODE_SIGN_STYLE = Automatic; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = Styx/Info.plist; INFOPLIST_KEY_LSUIElement = YES; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks"); MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.styx.app; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 5.0; }; name = Debug; };
		X21002 /* Release */ = { isa = XCBuildConfiguration; buildSettings = { CODE_SIGN_ENTITLEMENTS = Styx/Styx.entitlements; CODE_SIGN_STYLE = Automatic; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = Styx/Info.plist; INFOPLIST_KEY_LSUIElement = YES; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks"); MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.styx.app; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_VERSION = 5.0; }; name = Release; };
		X22001 /* Debug */ = { isa = XCBuildConfiguration; buildSettings = { BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.styx.tests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = NO; SWIFT_VERSION = 5.0; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Styx.app/Contents/MacOS/Styx"; }; name = Debug; };
		X22002 /* Release */ = { isa = XCBuildConfiguration; buildSettings = { BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = YES; MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.styx.tests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_EMIT_LOC_STRINGS = NO; SWIFT_VERSION = 5.0; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Styx.app/Contents/MacOS/Styx"; }; name = Release; };
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		X10001 = { isa = XCConfigurationList; buildConfigurations = (X11001, X11002); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
		X20001 = { isa = XCConfigurationList; buildConfigurations = (X21001, X21002); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
		X20002 = { isa = XCConfigurationList; buildConfigurations = (X22001, X22002); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
/* End XCConfigurationList section */

	};
	rootObject = P00001;
}
EOF
} > "$PROJ"

echo "Generated $PROJ with ${#APP_SOURCES[@]} app sources and ${#TEST_SOURCES[@]} test sources"
