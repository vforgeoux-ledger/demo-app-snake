#*******************************************************************************
#   Ledger Blue
#   (c) 2016 Ledger
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#*******************************************************************************

# NOTICE: This Makefile has been modified to better suit the build process of
# this application. The original version was found here:
# https://github.com/LedgerHQ/blue-sample-apps/blob/master/blue-app-helloworld/Makefile

# START USER CONFIGURATION
#BOLOS_ENV :=
#BOLOS_SDK :=
# END USER CONFIGURATION

ifndef BOLOS_ENV
$(error BOLOS_ENV is undefined)
endif
ifndef BOLOS_SDK
$(error BOLOS_SDK is undefined)
endif

$(info BOLOS_ENV=$(BOLOS_ENV))
$(info BOLOS_SDK=$(BOLOS_SDK))

# Extract TARGET_ID from the SDK
TARGET_ID := $(shell cat $(BOLOS_SDK)/include/bolos_target.h | grep 0x | cut -f3 -d' ')

$(info TARGET_ID=$(TARGET_ID))

# Verify TARGET_ID
ifneq ($(TARGET_ID),0x31100002)
$(error TARGET_ID must be 0x31100002)
endif

APPNAME = "Snake"
APP_LOAD_PARAMS := --appFlags 0x00 --icon "$(shell python $(BOLOS_SDK)/icon.py 16 16 glyphs/app-icon.gif hexbitmaponly)"

################
# Default rule #
################

all: default

# Consider every intermediate target as final to avoid deleting intermediate files
.SECONDARY:

# Disable builtin rules that overload the build process (and the debug log !!)
.SUFFIXES:
MAKEFLAGS += -r

SHELL = /bin/bash
#.ONESHELL:

############
# Platform #
############
PROG := token

CONFIG_PRODUCTIONS := bin/$(PROG)

SOURCE_PATH := src bui/src $(BOLOS_SDK)/src $(dir $(shell find $(BOLOS_SDK)/lib_stusb* | grep "\.c$$"))
SOURCE_FILES := $(foreach path, $(SOURCE_PATH),$(shell find $(path) | grep "\.c$$") )
INCLUDES_PATH := include bui/include $(BOLOS_SDK)/include $(BOLOS_SDK)/include/arm $(dir $(shell find $(BOLOS_SDK)/lib_stusb* | grep "\.h$$"))

# Platform definitions
DEFINES := ST31 gcc __IO=volatile

DEFINES += OS_IO_SEPROXYHAL IO_SEPROXYHAL_BUFFER_SIZE_B=300
DEFINES += HAVE_BAGL HAVE_PRINTF
DEFINES += HAVE_IO_USB HAVE_L4_USBLIB IO_USB_MAX_ENDPOINTS=6 IO_HID_EP_LENGTH=64 HAVE_USB_APDU
#DEFINES += PRINTF=screen_printf
DEFINES += PRINTF\(...\)=
DEFINES += UNUSED\(x\)=\(void\)x

############
# Compiler #
############
GCCPATH := $(BOLOS_ENV)/gcc-arm-none-eabi-5_3-2016q1/bin/
CLANGPATH := $(BOLOS_ENV)/clang-arm-fropi/bin
CC := $(CLANGPATH)/clang

CFLAGS_SHARED :=
CFLAGS_SHARED += -gdwarf-2 -gstrict-dwarf
CFLAGS_SHARED += -mcpu=cortex-m0 -mthumb
CFLAGS_SHARED += -fno-common -mtune=cortex-m0 -mlittle-endian
CFLAGS_SHARED += -std=gnu99 -Werror=int-to-pointer-cast -Wall -Wextra #-save-temps
CFLAGS_SHARED += -fdata-sections -ffunction-sections -funsigned-char -fshort-enums
CFLAGS_SHARED += -mno-unaligned-access
CFLAGS_SHARED += -Wno-unused-parameter -Wno-duplicate-decl-specifier

CFLAGS_SHARED += -fropi --target=armv6m-none-eabi

#CFLAGS_SHARED += -finline-limit-0 -funsigned-bitfields

CFLAGS += -O3 -Os $(CFLAGS_SHARED)

AS := $(GCCPATH)/arm-none-eabi-gcc
AFLAGS += -ggdb2 -O3 -Os -mcpu=cortex-m0 -fno-common -mtune=cortex-m0

# NOT SUPPORTED BY STM3L152 CFLAGS += -fpack-struct
#-pg --coverage
LD := $(GCCPATH)/arm-none-eabi-gcc
LDFLAGS :=
LDFLAGS += -gdwarf-2  -gstrict-dwarf
#LDFLAGS += -O0 -g3
LDFLAGS += -O3 -Os
#LDFLAGS += -O0
LDFLAGS += -Wall
LDFLAGS += -mcpu=cortex-m0 -mthumb
LDFLAGS += -fno-common -ffunction-sections -fdata-sections -fwhole-program -nostartfiles
LDFLAGS += -mno-unaligned-access
#LDFLAGS += -nodefaultlibs
#LDFLAGS += -nostdlib -nostdinc
LDFLAGS += -T$(BOLOS_SDK)/script.ld  -Wl,--gc-sections -Wl,-Map,debug/$(PROG).map,--cref
LDLIBS += -Wl,--library-path -Wl,$(GCCPATH)/../lib/armv6-m/
#LDLIBS += -Wl,--start-group
LDLIBS += -lm -lgcc -lc
#LDLIBS += -Wl,--end-group
#-mno-unaligned-access
#-pg --coverage

# Computed variables
VPATH := $(dir $(SOURCE_FILES))
OBJECT_FILES := $(sort $(addprefix obj/, $(addsuffix .o, $(basename $(notdir $(SOURCE_FILES))))))
DEPEND_FILES := $(sort $(addprefix dep/, $(addsuffix .d, $(basename $(notdir $(SOURCE_FILES))))))

ifeq ($(filter clean,$(MAKECMDGOALS)),)
-include $(DEPEND_FILES)
endif

clean:
	rm -fr obj bin debug dep

prepare:
	@mkdir -p bin obj debug dep

.SECONDEXPANSION:

# Default is not to display make commands
log = $(if $(strip $(VERBOSE)),$1,@$1)

default: prepare bin/$(PROG)

load: default
	python -m ledgerblue.loadApp --targetId $(TARGET_ID) --fileName bin/$(PROG).hex --appName $(APPNAME) $(APP_LOAD_PARAMS)

delete:
	python -m ledgerblue.deleteApp --targetId $(TARGET_ID) --appName $(APPNAME)

bin/$(PROG): $(OBJECT_FILES) $(BOLOS_SDK)/script.ld
	@echo "[LINK] 	$@"
	$(call log,$(call link_cmdline,$(OBJECT_FILES) $(LDLIBS),$@))
	$(call log,$(GCCPATH)/arm-none-eabi-objcopy -O ihex -S bin/$(PROG) bin/$(PROG).hex)
	$(call log,mv bin/$(PROG) bin/$(PROG).elf)
	$(call log,cp bin/$(PROG).elf obj)
	$(call log,$(GCCPATH)/arm-none-eabi-objdump -S -d bin/$(PROG).elf > debug/$(PROG).asm)

dep/%.d: %.c Makefile
	@echo "[DEP]    $@"
	@mkdir -p dep
	$(call log,$(call dep_cmdline,$(INCLUDES_PATH), $(DEFINES),$<,$@))

obj/%.o: %.c dep/%.d
	@echo "[CC]	$@"
	$(call log,$(call cc_cmdline,$(INCLUDES_PATH), $(DEFINES),$<,$@))

obj/%.o: %.s
	@echo "[CC]	$@"
	$(call log,$(call as_cmdline,$(INCLUDES_PATH), $(DEFINES),$<,$@))

### BEGIN GCC COMPILER RULES

# link_cmdline(objects,dest)		Macro that is used to format arguments for the linker
link_cmdline = $(LD) $(LDFLAGS) -o $(2) $(1)

# dep_cmdline(include,defines,src($<),dest($@))	Macro that is used to format arguments for the dependency creator
dep_cmdline = $(CC) -M $(CFLAGS) $(addprefix -D,$(2)) $(addprefix -I,$(1)) $(3) | sed 's/\($*\)\.o[ :]*/obj\/\1.o: /g' | sed -e 's/[:\t ][^ ]\+\.c//g' > dep/$(basename $(notdir $(4))).d 2>/dev/null

# cc_cmdline(include,defines,src,dest)	Macro that is used to format arguments for the compiler
cc_cmdline = $(CC) -c $(CFLAGS) $(addprefix -D,$(2)) $(addprefix -I,$(1)) -o $(4) $(3)

as_cmdline = $(AS) -c $(AFLAGS) $(addprefix -D,$(2)) $(addprefix -I,$(1)) -o $(4) $(3)

### END GCC COMPILER RULES
