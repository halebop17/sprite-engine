#!/usr/bin/env python3
"""Inject missing source files needed for toaplan/konami linker deps."""
import re, sys

PBXPROJ = "SpriteEngine.xcodeproj/project.pbxproj"

with open(PBXPROJ, "r") as f:
    content = f.read()

# ── New PBXFileReference entries ──────────────────────────────────────────────
# Format: ID /* filename */ = {isa = PBXFileReference; ... path = filename; ...}
new_file_refs = """		LDEP_FMOPL_REF000 /* fmopl.c */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.c; path = fmopl.c; sourceTree = "<group>"; };
		LDEP_YMZ280B_REF0 /* ymz280b.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = ymz280b.cpp; sourceTree = "<group>"; };
		LDEP_NECINTF_REF0 /* nec_intf.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = nec_intf.cpp; sourceTree = "<group>"; };
		LDEP_NEC_CPP_REF0 /* nec.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = nec.cpp; sourceTree = "<group>"; };
		LDEP_V25_CPP_REF0 /* v25.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = v25.cpp; sourceTree = "<group>"; };
		LDEP_Z180INT_REF0 /* z180_intf.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = z180_intf.cpp; sourceTree = "<group>"; };
		LDEP_Z180_CPP_REF /* z180.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = z180.cpp; sourceTree = "<group>"; };
		LDEP_M6805INT_REF /* m6805_intf.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = m6805_intf.cpp; sourceTree = "<group>"; };
		LDEP_M6805_CPP_RE /* m6805.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = m6805.cpp; sourceTree = "<group>"; };
		LDEP_TAITO_M68705 /* taito_m68705.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = taito_m68705.cpp; sourceTree = "<group>"; };
		LDEP_NMK112_REF00 /* nmk112.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = nmk112.cpp; sourceTree = "<group>"; };
		LDEP_K051733_REF0 /* k051733.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; path = k051733.cpp; sourceTree = "<group>"; };
"""

# ── New PBXBuildFile entries ──────────────────────────────────────────────────
new_build_files = """		LDEP_FMOPL_BLD000 /* fmopl.c in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_FMOPL_REF000 /* fmopl.c */; };
		LDEP_YMZ280B_BLD0 /* ymz280b.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_YMZ280B_REF0 /* ymz280b.cpp */; };
		LDEP_NECINTF_BLD0 /* nec_intf.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_NECINTF_REF0 /* nec_intf.cpp */; };
		LDEP_NEC_CPP_BLD0 /* nec.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_NEC_CPP_REF0 /* nec.cpp */; };
		LDEP_V25_CPP_BLD0 /* v25.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_V25_CPP_REF0 /* v25.cpp */; };
		LDEP_Z180INT_BLD0 /* z180_intf.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_Z180INT_REF0 /* z180_intf.cpp */; };
		LDEP_Z180_CPP_BLD /* z180.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_Z180_CPP_REF /* z180.cpp */; };
		LDEP_M6805INT_BLD /* m6805_intf.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_M6805INT_REF /* m6805_intf.cpp */; };
		LDEP_M6805_CPP_BL /* m6805.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_M6805_CPP_RE /* m6805.cpp */; };
		LDEP_TAITO_M68_BL /* taito_m68705.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_TAITO_M68705 /* taito_m68705.cpp */; };
		LDEP_NMK112_BLD00 /* nmk112.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_NMK112_REF00 /* nmk112.cpp */; };
		LDEP_K051733_BLD0 /* k051733.cpp in Sources */ = {isa = PBXBuildFile; fileRef = LDEP_K051733_REF0 /* k051733.cpp */; };
"""

# ── New PBXGroup entries (nec, z180, m6805 cpu subdirs + taito drv subdir) ───
new_groups = """		LDEP_NEC_GRP00000 /* nec */ = {
			isa = PBXGroup;
			children = (
				LDEP_NEC_CPP_REF0 /* nec.cpp */,
				LDEP_V25_CPP_REF0 /* v25.cpp */,
			);
			path = nec;
			sourceTree = "<group>";
		};
		LDEP_Z180_GRP0000 /* z180 */ = {
			isa = PBXGroup;
			children = (
				LDEP_Z180_CPP_REF /* z180.cpp */,
			);
			path = z180;
			sourceTree = "<group>";
		};
		LDEP_M6805_GRP000 /* m6805 */ = {
			isa = PBXGroup;
			children = (
				LDEP_M6805_CPP_RE /* m6805.cpp */,
			);
			path = m6805;
			sourceTree = "<group>";
		};
		LDEP_TAITO_GRP000 /* taito */ = {
			isa = PBXGroup;
			children = (
				LDEP_TAITO_M68705 /* taito_m68705.cpp */,
			);
			path = taito;
			sourceTree = "<group>";
		};
"""

# ── Sources build phase entries ───────────────────────────────────────────────
new_sources = """				LDEP_FMOPL_BLD000 /* fmopl.c in Sources */,
				LDEP_YMZ280B_BLD0 /* ymz280b.cpp in Sources */,
				LDEP_NECINTF_BLD0 /* nec_intf.cpp in Sources */,
				LDEP_NEC_CPP_BLD0 /* nec.cpp in Sources */,
				LDEP_V25_CPP_BLD0 /* v25.cpp in Sources */,
				LDEP_Z180INT_BLD0 /* z180_intf.cpp in Sources */,
				LDEP_Z180_CPP_BLD /* z180.cpp in Sources */,
				LDEP_M6805INT_BLD /* m6805_intf.cpp in Sources */,
				LDEP_M6805_CPP_BL /* m6805.cpp in Sources */,
				LDEP_TAITO_M68_BL /* taito_m68705.cpp in Sources */,
				LDEP_NMK112_BLD00 /* nmk112.cpp in Sources */,
				LDEP_K051733_BLD0 /* k051733.cpp in Sources */,
"""

# Step 1: Insert FileRefs after "End PBXFileReference section"
assert "/* End PBXFileReference section */" in content
content = content.replace(
    "/* End PBXFileReference section */",
    new_file_refs + "/* End PBXFileReference section */"
)

# Step 2: Insert BuildFiles after "End PBXBuildFile section"
assert "/* End PBXBuildFile section */" in content
content = content.replace(
    "/* End PBXBuildFile section */",
    new_build_files + "/* End PBXBuildFile section */"
)

# Step 3: Insert new groups before "/* End PBXGroup section */"
assert "/* End PBXGroup section */" in content
content = content.replace(
    "/* End PBXGroup section */",
    new_groups + "/* End PBXGroup section */"
)

# Step 4: Add children to cpu group: nec, z180, m6805 subgroups + intf files
cpu_group_children_anchor = "\t\t\t\tTMS32010_GROUP000000000 /* tms32010 */,\n\t\t\t);\n\t\t\tpath = cpu;"
assert cpu_group_children_anchor in content, f"Anchor not found!"
content = content.replace(
    cpu_group_children_anchor,
    "\t\t\t\tTMS32010_GROUP000000000 /* tms32010 */,\n"
    "\t\t\t\tLDEP_NEC_GRP00000 /* nec */,\n"
    "\t\t\t\tLDEP_Z180_GRP0000 /* z180 */,\n"
    "\t\t\t\tLDEP_M6805_GRP000 /* m6805 */,\n"
    "\t\t\t\tLDEP_NECINTF_REF0 /* nec_intf.cpp */,\n"
    "\t\t\t\tLDEP_Z180INT_REF0 /* z180_intf.cpp */,\n"
    "\t\t\t\tLDEP_M6805INT_REF /* m6805_intf.cpp */,\n"
    "\t\t\t);\n\t\t\tpath = cpu;"
)

# Step 5: Add fmopl.c and ymz280b.cpp to snd group
snd_last_child = "\t\t\t\tKGXSND001A /* k054539.cpp */,\n\t\t\t);\n\t\t\tpath = snd;"
assert snd_last_child in content
content = content.replace(
    snd_last_child,
    "\t\t\t\tKGXSND001A /* k054539.cpp */,\n"
    "\t\t\t\tLDEP_FMOPL_REF000 /* fmopl.c */,\n"
    "\t\t\t\tLDEP_YMZ280B_REF0 /* ymz280b.cpp */,\n"
    "\t\t\t);\n\t\t\tpath = snd;"
)

# Step 6: Add nmk112.cpp to devices group
devices_last_child = "\t\t\t\tSE160024A000000000000000 /* resnet.cpp */,\n\t\t\t);\n\t\t\tpath = devices;"
assert devices_last_child in content
content = content.replace(
    devices_last_child,
    "\t\t\t\tSE160024A000000000000000 /* resnet.cpp */,\n"
    "\t\t\t\tLDEP_NMK112_REF00 /* nmk112.cpp */,\n"
    "\t\t\t);\n\t\t\tpath = devices;"
)

# Step 7: Add k051733.cpp to konami group
konami_last_child = "\t\t\t\tKGXSUP014A /* k054000.cpp */,\n\t\t\t);\n\t\t\tpath = konami;"
assert konami_last_child in content
content = content.replace(
    konami_last_child,
    "\t\t\t\tKGXSUP014A /* k054000.cpp */,\n"
    "\t\t\t\tLDEP_K051733_REF0 /* k051733.cpp */,\n"
    "\t\t\t);\n\t\t\tpath = konami;"
)

# Step 8: Add taito group to drv group
drv_children_anchor = "\t\t\t\tSE16SEGAGRP000000000000 /* sega */,\n\t\t\t);\n\t\t\tpath = drv;"
assert drv_children_anchor in content
content = content.replace(
    drv_children_anchor,
    "\t\t\t\tSE16SEGAGRP000000000000 /* sega */,\n"
    "\t\t\t\tLDEP_TAITO_GRP000 /* taito */,\n"
    "\t\t\t);\n\t\t\tpath = drv;"
)

# Step 9: Add source build entries — insert after last known toaplan source entry
sources_anchor = "\t\t\t\tKGXDEV001B /* dtimer.cpp in Sources */,\n"
assert sources_anchor in content
content = content.replace(
    sources_anchor,
    "\t\t\t\tKGXDEV001B /* dtimer.cpp in Sources */,\n" + new_sources
)

with open(PBXPROJ, "w") as f:
    f.write(content)
print("Done — all 12 files injected into project.")
