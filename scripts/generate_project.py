#!/usr/bin/env python3
import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

def create_project(base_dir):
    proj_dir = os.path.join(base_dir, "YouTubeWidget.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    pbx_path = os.path.join(proj_dir, "project.pbxproj")

    # IDs for project and targets
    proj_id = "000100000000000000000001"
    main_group_id = "000100000000000000000002"
    products_group_id = "000100000000000000000003"
    sources_group_id = "000100000000000000000004"
    app_group_id = "000100000000000000000005"
    ext_group_id = "000100000000000000000006"
    shared_group_id = "000100000000000000000007"

    # Products
    app_product_id = "000100000000000000000010"
    ext_product_id = "000100000000000000000011"

    # Targets
    app_target_id = "000100000000000000000020"
    ext_target_id = "000100000000000000000021"

    # Configurations
    proj_cfg_list_id = "000100000000000000000030"
    proj_cfg_debug_id = "000100000000000000000031"
    proj_cfg_release_id = "000100000000000000000032"

    app_cfg_list_id = "000100000000000000000040"
    app_cfg_debug_id = "000100000000000000000041"
    app_cfg_release_id = "000100000000000000000042"

    ext_cfg_list_id = "000100000000000000000050"
    ext_cfg_debug_id = "000100000000000000000051"
    ext_cfg_release_id = "000100000000000000000052"

    # Build Phases
    app_sources_phase_id = "000100000000000000000060"
    app_frameworks_phase_id = "000100000000000000000061"
    app_resources_phase_id = "000100000000000000000062"
    app_embed_ext_phase_id = "000100000000000000000063"

    ext_sources_phase_id = "000100000000000000000070"
    ext_frameworks_phase_id = "000100000000000000000071"
    ext_resources_phase_id = "000100000000000000000072"

    # Target Dependency & Proxy
    target_dep_id = "000100000000000000000080"
    container_proxy_id = "000100000000000000000081"
    ext_in_embed_build_file_id = "000100000000000000000082"

    # Source files definitions
    # Relative to project root
    app_only_files = [
        "Sources/YouTubeWidget/YouTubeWidget.swift",
        "Sources/YouTubeWidget/ViewModels/WidgetViewModel.swift",
        "Sources/YouTubeWidget/Windows/DesktopWindowManager.swift",
        "Sources/YouTubeWidget/Views/SettingsView.swift",
        "Sources/YouTubeWidget/Services/SharedDataManager.swift",
    ]

    shared_files = [
        "Sources/YouTubeWidget/Models/YouTubeStats.swift",
        "Sources/YouTubeWidget/Models/SocialStats.swift",
        "Sources/YouTubeWidget/Services/YouTubeService.swift",
        "Sources/YouTubeWidget/Services/SocialService.swift",
    ]

    ext_only_files = [
        "Sources/YouTubeWidgetExtension/YouTubeWidgetExtension.swift",
    ]

    # Assign IDs
    file_refs = {}
    build_files = {}

    for f in app_only_files + shared_files + ext_only_files:
        f_ref = gen_id()
        file_refs[f] = f_ref

    # App build files (app_only + shared)
    app_build_files = []
    for f in app_only_files + shared_files:
        bf_id = gen_id()
        build_files[bf_id] = (file_refs[f], f)
        app_build_files.append(bf_id)

    # Ext build files (ext_only + shared)
    ext_build_files = []
    for f in ext_only_files + shared_files:
        bf_id = gen_id()
        build_files[bf_id] = (file_refs[f], f)
        ext_build_files.append(bf_id)

    # Write pbxproj
    with open(pbx_path, "w") as out:
        out.write("""// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
""")
        out.write(f"\t\t{ext_in_embed_build_file_id} /* YouTubeWidgetExtension.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {ext_product_id} /* YouTubeWidgetExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n")
        for bf_id, (f_ref, f_path) in build_files.items():
            base_name = os.path.basename(f_path)
            out.write(f"\t\t{bf_id} /* {base_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_ref} /* {base_name} */; }};\n")
        out.write("""/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
""")
        out.write(f"""\t\t{container_proxy_id} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {proj_id} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ext_target_id};
\t\t\tremoteInfo = YouTubeWidgetExtension;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
\t\t{app_embed_ext_phase_id} /* Embed App Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{ext_in_embed_build_file_id} /* YouTubeWidgetExtension.appex in Embed App Extensions */,
\t\t\t);
\t\t\tname = "Embed App Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t{app_product_id} /* YouTubeWidget.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = YouTubeWidget.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{ext_product_id} /* YouTubeWidgetExtension.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = YouTubeWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
""")
        for f_path, f_ref in file_refs.items():
            base_name = os.path.basename(f_path)
            out.write(f"\t\t{f_ref} /* {base_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{f_path}\"; sourceTree = \"<group>\"; }};\n")
        out.write("""/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
""")
        out.write(f"""\t\t{app_frameworks_phase_id} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ext_frameworks_phase_id} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{main_group_id} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{sources_group_id} /* Sources */,
\t\t\t\t{products_group_id} /* Products */,
\t\t\t);
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{products_group_id} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_product_id} /* YouTubeWidget.app */,
\t\t\t\t{ext_product_id} /* YouTubeWidgetExtension.appex */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{sources_group_id} /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
""")
        for f_path, f_ref in file_refs.items():
            base_name = os.path.basename(f_path)
            out.write(f"\t\t\t\t{f_ref} /* {base_name} */,\n")
        out.write(f"""\t\t\t);
\t\t\tname = Sources;
\t\t\tsourceTree = \"<group>\";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{app_target_id} /* YouTubeWidget */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {app_cfg_list_id} /* Build configuration list for PBXNativeTarget "YouTubeWidget" */;
\t\t\tbuildPhases = (
\t\t\t\t{app_sources_phase_id} /* Sources */,
\t\t\t\t{app_frameworks_phase_id} /* Frameworks */,
\t\t\t\t{app_resources_phase_id} /* Resources */,
\t\t\t\t{app_embed_ext_phase_id} /* Embed App Extensions */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{target_dep_id} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = YouTubeWidget;
\t\t\tproductName = YouTubeWidget;
\t\t\tproductReference = {app_product_id} /* YouTubeWidget.app */;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t}};
\t\t{ext_target_id} /* YouTubeWidgetExtension */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ext_cfg_list_id} /* Build configuration list for PBXNativeTarget "YouTubeWidgetExtension" */;
\t\t\tbuildPhases = (
\t\t\t\t{ext_sources_phase_id} /* Sources */,
\t\t\t\t{ext_frameworks_phase_id} /* Frameworks */,
\t\t\t\t{ext_resources_phase_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = YouTubeWidgetExtension;
\t\t\tproductName = YouTubeWidgetExtension;
\t\t\tproductReference = {ext_product_id} /* YouTubeWidgetExtension.appex */;
\t\t\tproductType = \"com.apple.product-type.app-extension\";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{proj_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{app_target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t\t{ext_target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_cfg_list_id} /* Build configuration list for PBXProject "YouTubeWidget" */;
\t\t\tcompatibilityVersion = \"Xcode 14.0\";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {products_group_id} /* Products */;
\t\t\tprojectDirPath = \"\";
\t\t\tprojectRoot = \"\";
\t\t\ttargets = (
\t\t\t\t{app_target_id} /* YouTubeWidget */,
\t\t\t\t{ext_target_id} /* YouTubeWidgetExtension */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{app_resources_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ext_resources_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{app_sources_phase_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
""")
        for bf_id in app_build_files:
            f_ref, f_path = build_files[bf_id]
            base_name = os.path.basename(f_path)
            out.write(f"\t\t\t\t{bf_id} /* {base_name} in Sources */,\n")
        out.write(f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ext_sources_phase_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
""")
        for bf_id in ext_build_files:
            f_ref, f_path = build_files[bf_id]
            base_name = os.path.basename(f_path)
            out.write(f"\t\t\t\t{bf_id} /* {base_name} in Sources */,\n")
        out.write(f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{target_dep_id} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ext_target_id} /* YouTubeWidgetExtension */;
\t\t\ttargetProxy = {container_proxy_id} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
\t\t{proj_cfg_debug_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{proj_cfg_release_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{app_cfg_debug_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = \"-\";
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = \"YouTubeWidget.app/Contents/Info.plist\";
\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"scripts/app.entitlements\";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/../Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.0.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.ufukcelen.youtubewidget;
\t\t\t\tPRODUCT_NAME = YouTubeWidget;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{app_cfg_release_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = \"-\";
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = \"YouTubeWidget.app/Contents/Info.plist\";
\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"scripts/app.entitlements\";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/../Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.0.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.ufukcelen.youtubewidget;
\t\t\t\tPRODUCT_NAME = YouTubeWidget;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{ext_cfg_debug_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = \"-\";
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = \"scripts/extension-Info.plist\";
\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"scripts/extension.entitlements\";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/../Frameworks\",
\t\t\t\t\t\"@executable_path/../../../../Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.0.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.ufukcelen.youtubewidget.extension;
\t\t\t\tPRODUCT_NAME = YouTubeWidgetExtension;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ext_cfg_release_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = \"-\";
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = \"scripts/extension-Info.plist\";
\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"scripts/extension.entitlements\";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/../Frameworks\",
\t\t\t\t\t\"@executable_path/../../../../Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.0.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.ufukcelen.youtubewidget.extension;
\t\t\t\tPRODUCT_NAME = YouTubeWidgetExtension;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{proj_cfg_list_id} /* Build configuration list for PBXProject "YouTubeWidget" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_cfg_debug_id} /* Debug */,
\t\t\t\t{proj_cfg_release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{app_cfg_list_id} /* Build configuration list for PBXNativeTarget "YouTubeWidget" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{app_cfg_debug_id} /* Debug */,
\t\t\t\t{app_cfg_release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ext_cfg_list_id} /* Build configuration list for PBXNativeTarget "YouTubeWidgetExtension" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ext_cfg_debug_id} /* Debug */,
\t\t\t\t{ext_cfg_release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {proj_id} /* Project object */;
}}
""")
    print("Created project.pbxproj successfully at", pbx_path)

if __name__ == "__main__":
    create_project("/Users/ufukcelen/Desktop/Dev/Widged App")
