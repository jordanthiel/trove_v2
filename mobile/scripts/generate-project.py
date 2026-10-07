#!/usr/bin/env python3
"""Generate the dependency-free Xcode project deterministically."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
project=root/'Trove.xcodeproj'; project.mkdir(exist_ok=True)
objects=[]
def obj(name,value): objects.append(f'{uid(name)} = {{ {value} }};')
sources=sorted((root/'Trove').glob('*.swift'))
resources=['Configuration.plist','Assets.xcassets']
for p in sources:
 obj(p.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {p.name}; sourceTree = "<group>";')
 obj('build'+p.name, f'isa = PBXBuildFile; fileRef = {uid(p.name)};')
for p in resources:
 obj(p,f'isa = PBXFileReference; lastKnownFileType = {"folder.assetcatalog" if p.endswith("xcassets") else "text.plist.xml"}; path = {p}; sourceTree = "<group>";')
 obj('build'+p,f'isa = PBXBuildFile; fileRef = {uid(p)};')
obj('Info.plist','isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";')
obj('app','isa = PBXFileReference; explicitFileType = wrapper.application; path = Trove.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('root',f'isa = PBXGroup; children = ({uid("Trove")},{uid("products")}); sourceTree = "<group>";')
obj('Trove',f'isa = PBXGroup; children = ({",".join(uid(p.name) for p in sources)},{",".join(uid(p) for p in resources)},{uid("Info.plist")}); path = Trove; sourceTree = "<group>";')
obj('products',f'isa = PBXGroup; children = ({uid("app")}); name = Products; sourceTree = "<group>";')
obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(uid("build"+p.name) for p in sources)}); runOnlyForDeploymentPostprocessing = 0;')
obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(uid("build"+p) for p in resources)}); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for mode in ['Debug','Release']:
 obj('project'+mode,f'isa = XCBuildConfiguration; buildSettings = {{ SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; }}; name = {mode};')
 obj('target'+mode,f'''isa = XCBuildConfiguration; buildSettings = {{
 PRODUCT_BUNDLE_IDENTIFIER = com.jordanthiel.trove-rn; PRODUCT_NAME = "$(TARGET_NAME)";
 INFOPLIST_FILE = Trove/Info.plist; GENERATE_INFOPLIST_FILE = NO;
 TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic;
 MARKETING_VERSION = 1.1.1; CURRENT_PROJECT_VERSION = 2026100701;
 DEVELOPMENT_TEAM = GYURRL7F4B;
 ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
 SWIFT_VERSION = 5.0; SWIFT_STRICT_CONCURRENCY = targeted;
 SWIFT_OPTIMIZATION_LEVEL = { '"-Onone"' if mode=='Debug' else '"-O"' };
 SWIFT_ACTIVE_COMPILATION_CONDITIONS = { 'DEBUG' if mode=='Debug' else '""' };
 ENABLE_TESTABILITY = { 'YES' if mode=='Debug' else 'NO' };
 }}; name = {mode};''')
for name in ['project','target']:
 obj(name+'configs',f'isa = XCConfigurationList; buildConfigurations = ({uid(name+"Debug")},{uid(name+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = (); name = Trove; productName = Trove; productReference = {uid("app")}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2660; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {uid("root")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")});')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
(schemes/'Trove.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Trove.app" BlueprintName="Trove" ReferencedContainer="container:Trove.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Trove.app" BlueprintName="Trove" ReferencedContainer="container:Trove.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Trove.xcodeproj')
