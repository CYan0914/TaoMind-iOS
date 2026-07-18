#!/usr/bin/env python3
"""
Generate a minimal but valid TaoMind.xcodeproj with Xcode 14 compatible format.
Run once to commit the .xcodeproj to git, removing the need for xcodegen in CI.
"""
import os, uuid, plistlib

# ── Configuration ──────────────────────────────────────────
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
APP_NAME = "TaoMind"
BUNDLE_ID = "com.cyan0914.taomind"
TEAM_ID = "H4VQ9X6KYK"
SWIFT_VERSION = "5.9"
DEPLOYMENT_TARGET = "16.0"
# ───────────────────────────────────────────────────────────

def uid():
    return uuid.uuid4().hex.upper()

# UUIDs (stable based on name so regeneration is idempotent)
def stable_uuid(seed):
    return uuid.uuid5(uuid.NAMESPACE_DNS, seed).hex.upper()[:24]

# Collect Swift files
swift_files = []
resource_files = []
for root, dirs, files in os.walk(PROJECT_DIR):
    # Skip hidden and build dirs
    dn = os.path.relpath(root, PROJECT_DIR)
    if any(p.startswith('.') or p == 'build' or p == 'DerivedData' for p in dn.split(os.sep)):
        continue
    for f in sorted(files):
        fp = os.path.relpath(os.path.join(root, f), PROJECT_DIR)
        if f.endswith('.swift'):
            swift_files.append(fp)
        elif f == 'Info.plist':
            resource_files.append(fp)

print(f"Found {len(swift_files)} Swift files, {len(resource_files)} resource files")

# Build stable references
PBX_BUILD_FILE = {}
PBX_FILE_REF = {}

for sf in swift_files:
    ref = stable_uuid(sf)
    PBX_FILE_REF[sf] = ref
    PBX_BUILD_FILE[sf] = stable_uuid(f"build_{sf}")

for rf in resource_files:
    ref = stable_uuid(rf)
    PBX_FILE_REF[rf] = ref

PRODUCT_REF = stable_uuid("Products/taomind.app")

# Target UUIDs
TARGET_UID = stable_uuid("target_TaoMind")
SOURCES_PHASE = stable_uuid("sources_build_phase")
FRAMEWORKS_PHASE = stable_uuid("frameworks_build_phase")
RESOURCES_PHASE = stable_uuid("resources_build_phase")
BUILD_CONFIG_LIST = stable_uuid("build_config_list_TaoMind")
DEBUG_CONFIG = stable_uuid("debug_config")
RELEASE_CONFIG = stable_uuid("release_config")
PROJECT_BUILD_CONFIG_LIST = stable_uuid("project_build_config_list")
PROJECT_DEBUG_CONFIG = stable_uuid("project_debug_config")
PROJECT_RELEASE_CONFIG = stable_uuid("project_release_config")
PROJECT_OBJ = stable_uuid("project_object")
ROOT_OBJ = PROJECT_OBJ
MAIN_GROUP = stable_uuid("main_group")
PRODUCTS_GROUP = stable_uuid("products_group")

objects = {}

# File references
for sf in swift_files:
    p = os.path.dirname(sf) or "."
    objects[PBX_FILE_REF[sf]] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.swift",
        "path": os.path.basename(sf),
        "sourceTree": "<group>",
    }

for rf in resource_files:
    objects[PBX_FILE_REF[rf]] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist.xml",
        "path": os.path.basename(rf),
        "sourceTree": "<group>",
    }

# Build files (Swift source files in compile phase)
for sf in swift_files:
    objects[PBX_BUILD_FILE[sf]] = {
        "isa": "PBXBuildFile",
        "fileRef": PBX_FILE_REF[sf],
    }

# Product reference
objects[PRODUCT_REF] = {
    "isa": "PBXFileReference",
    "explicitFileType": "wrapper.application",
    "includeInIndex": 0,
    "path": f"{APP_NAME}.app",
    "sourceTree": "BUILT_PRODUCTS_DIR",
}

# Groups
source_children = []
for sf in swift_files:
    source_children.append({"": PBX_FILE_REF[sf]})

resource_children = []
for rf in resource_files:
    resource_children.append({"": PBX_FILE_REF[rf]})

# Create groups by directory structure
# Simplified: just put all files in a flat "Sources" group
objects[MAIN_GROUP] = {
    "isa": "PBXGroup",
    "children": [{"": stable_uuid("sources_group")}, {"": PRODUCTS_GROUP}],
    "sourceTree": "<group>",
}

objects[stable_uuid("sources_group")] = {
    "isa": "PBXGroup",
    "children": [{"": PBX_FILE_REF[sf]} for sf in swift_files] + [{"": PBX_FILE_REF[rf]} for rf in resource_files],
    "name": "Sources",
    "sourceTree": "<group>",
}

objects[PRODUCTS_GROUP] = {
    "isa": "PBXGroup",
    "children": [{"": PRODUCT_REF}],
    "name": "Products",
    "sourceTree": "<group>",
}

# Build phases
objects[SOURCES_PHASE] = {
    "isa": "PBXSourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": [{"": PBX_BUILD_FILE[sf]} for sf in swift_files],
    "runOnlyForDeploymentPostprocessing": 0,
}

objects[FRAMEWORKS_PHASE] = {
    "isa": "PBXFrameworksBuildPhase",
    "buildActionMask": 2147483647,
    "files": [],
    "runOnlyForDeploymentPostprocessing": 0,
}

objects[RESOURCES_PHASE] = {
    "isa": "PBXResourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": [],
    "runOnlyForDeploymentPostprocessing": 0,
}

# Build configurations
objects[DEBUG_CONFIG] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": TEAM_ID,
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Resources/Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": APP_NAME,
        "SDKROOT": "iphoneos",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": "1,2",
    },
    "name": "Debug",
}

objects[RELEASE_CONFIG] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": TEAM_ID,
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Resources/Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": APP_NAME,
        "SDKROOT": "iphoneos",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": "1,2",
    },
    "name": "Release",
}

objects[BUILD_CONFIG_LIST] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [{"": DEBUG_CONFIG}, {"": RELEASE_CONFIG}],
    "defaultConfigurationIsVisible": 0,
    "defaultConfigurationName": "Release",
}

# Project-level build configs
objects[PROJECT_DEBUG_CONFIG] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": SWIFT_VERSION,
    },
    "name": "Debug",
}

objects[PROJECT_RELEASE_CONFIG] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": SWIFT_VERSION,
    },
    "name": "Release",
}

objects[PROJECT_BUILD_CONFIG_LIST] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [{"": PROJECT_DEBUG_CONFIG}, {"": PROJECT_RELEASE_CONFIG}],
    "defaultConfigurationIsVisible": 0,
    "defaultConfigurationName": "Release",
}

# Native target
objects[TARGET_UID] = {
    "isa": "PBXNativeTarget",
    "buildConfigurationList": BUILD_CONFIG_LIST,
    "buildPhases": [{"": SOURCES_PHASE}, {"": FRAMEWORKS_PHASE}, {"": RESOURCES_PHASE}],
    "buildRules": [],
    "dependencies": [],
    "name": APP_NAME,
    "productName": APP_NAME,
    "productReference": PRODUCT_REF,
    "productType": "com.apple.product-type.application",
}

# Project object
objects[PROJECT_OBJ] = {
    "isa": "PBXProject",
    "attributes": {
        "BuildIndependentTargetsInParallel": 1,
        "LastSwiftUpdateCheck": 1500,
        "LastUpgradeCheck": 1500,
        "ORGANIZATIONNAME": "",
    },
    "buildConfigurationList": PROJECT_BUILD_CONFIG_LIST,
    "compatibilityVersion": "Xcode 14.0",
    "developmentRegion": "en",
    "hasScannedForEncodings": 0,
    "knownRegions": ["en", "Base", "zh-Hans"],
    "mainGroup": MAIN_GROUP,
    "productRefGroup": PRODUCTS_GROUP,
    "projectDirPath": "",
    "projectRoot": "",
    "targets": [{"": TARGET_UID}],
}

# Write pbxproj
PBXPROJ_PATH = os.path.join(PROJECT_DIR, "TaoMind.xcodeproj", "project.pbxproj")
os.makedirs(os.path.dirname(PBXPROJ_PATH), exist_ok=True)

# Serialize to plist then wrap in old-style pbxproj format
plist_data = {
    "archiveVersion": 1,
    "classes": {},
    "objectVersion": 18,
    "objects": objects,
    "rootObject": ROOT_OBJ,
}

# Use plistlib to generate XML, then convert to old ASCII plist format
xml = plistlib.dumps(plist_data, fmt=plistlib.FMT_XML).decode('utf-8')

# Convert XML plist to old-style pbxproj ASCII format
# This is a simplified conversion - we wrap the XML in the old text format
# Actually, Xcode CAN read XML plist .pbxproj files too!
# But the traditional format is the old-style NeXTSTEP format.
# Let's use the XML format which Xcode also supports.

# Write as XML plist (Xcode can read this)
with open(PBXPROJ_PATH, 'w', encoding='utf-8') as f:
    f.write(xml)

print(f"Generated: {PBXPROJ_PATH}")
print(f"objectVersion: 18 (Xcode 14 format)")
print(f"Swift files: {len(swift_files)}, Resources: {len(resource_files)}")
print("\nRemember to run: git add TaoMind.xcodeproj/")
