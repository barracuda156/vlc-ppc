# qtshadertools
# required for Qt5Compat, and for qtdeclarative.

QTSHADERTOOLS_VERSION := $(QTBASE_VERSION_MAJOR).1
QTSHADERTOOLS_URL := $(QT)/$(QTSHADERTOOLS_VERSION)/submodules/qtshadertools-everywhere-src-$(QTSHADERTOOLS_VERSION).tar.xz

DEPS_qtshadertools-tools = qt-tools $(DEPS_qt-tools)

ifdef HAVE_WIN32
DEPS_qtshadertools-tools += fxc2 $(DEPS_fxc2)
endif

ifneq ($(findstring qt,$(PKGS)),)
PKGS_TOOLS += qtshadertools-tools
endif
PKGS_ALL += qtshadertools-tools

ifeq ($(call system_tool_majmin, qsb --version),$(QTBASE_VERSION_MAJOR))
PKGS_FOUND += qtshadertools-tools
endif

$(TARBALLS)/qtshadertools-everywhere-src-$(QTSHADERTOOLS_VERSION).tar.xz:
	$(call download,$(QTSHADERTOOLS_URL))

.sum-qtshadertools: qtshadertools-everywhere-src-$(QTSHADERTOOLS_VERSION).tar.xz

.sum-qtshadertools-tools: .sum-qtshadertools
	touch $@

QT_SHADETOOLS_CONFIG := -DCMAKE_TOOLCHAIN_FILE=$(PREFIX)/lib/cmake/Qt6/qt.toolchain.cmake $(QT_HOST_PATH)
ifdef ENABLE_PDB
QT_SHADETOOLS_CONFIG += -DCMAKE_BUILD_TYPE=RelWithDebInfo
else
QT_SHADETOOLS_CONFIG += -DCMAKE_BUILD_TYPE=Release
endif

QT_SHADETOOLS_NATIVE_CONFIG := -DCMAKE_TOOLCHAIN_FILE=$(QT_HOST_LIBS)/cmake/Qt6/qt.toolchain.cmake

qtshadertools: qtshadertools-everywhere-src-$(QTSHADERTOOLS_VERSION).tar.xz .sum-qtshadertools
	$(UNPACK)
	$(MOVE)

.qtshadertools-tools: BUILD_DIR=$</vlc_native
.qtshadertools-tools: qtshadertools
	$(CMAKECLEAN)
	$(BUILDVARS) $(CMAKE_NATIVE) $(QT_SHADETOOLS_NATIVE_CONFIG)
	+$(CMAKEBUILD)
	$(CMAKEINSTALL)
	touch $@
