################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 32
COMPILE_S_KERNEL  ?= 64

# Normal/secure world console UARTs: 3 or 0 [default 3]
CFG_NW_CONSOLE_UART ?= 3
CFG_SW_CONSOLE_UART ?= 3

# eMMC flash size: 8 or 4 GB [default 8]
CFG_FLASH_SIZE ?= 8

################################################################################
# Includes
################################################################################
-include common.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################
ifeq ($(COMPILE_NS_USER),64)
MULTIARCH			:= aarch64-linux-gnu
else
MULTIARCH			:= arm-linux-gnueabihf
endif

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH			?= $(ROOT)/arm-trusted-firmware
ifeq ($(DEBUG),1)
ARM_TF_BUILD			?= debug
else
ARM_TF_BUILD			?= release
endif

ATF_FB_PATH			?=$(ROOT)/atf-fastboot
ifeq ($(DEBUG),1)
ATF_FB_BUILD			?= debug
else
ATF_FB_BUILD			?= release
endif

EDK2_PATH 			?= $(ROOT)/edk2
ifeq ($(DEBUG),1)
EDK2_BUILD			?= DEBUG
else
EDK2_BUILD			?= RELEASE
endif
EDK2_BIN 			?= $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/FV/BL33_AP_UEFI.fd
OPENPLATPKG_PATH		?= $(ROOT)/OpenPlatformPkg

OUT_PATH			?=$(ROOT)/out
MCUIMAGE_BIN			?= $(OPENPLATPKG_PATH)/Platforms/Hisilicon/HiKey/Binary/mcuimage.bin
BOOT_IMG			?=$(ROOT)/out/boot-fat.uefi.img
NVME_IMG			?=$(ROOT)/out/nvme.img
GRUB_PATH			?=$(ROOT)/grub
LLOADER_PATH			?=$(ROOT)/l-loader
PATCHES_PATH			?=$(ROOT)/patches_hikey
STRACE_PATH			?=$(ROOT)/strace

################################################################################
# Targets
################################################################################
all: arm-tf boot-img lloader nvme strace

clean: arm-tf-clean busybox-clean edk2-clean linux-clean optee-os-clean optee-client-clean xtest-clean helloworld-clean strace-clean update_rootfs-clean boot-img-clean lloader-clean grub-clean atf-fb-clean

cleaner: clean prepare-cleaner busybox-cleaner linux-cleaner strace-cleaner nvme-cleaner grub-cleaner

-include toolchain.mk

prepare:
	mkdir -p $(OUT_PATH)

.PHONY: prepare-cleaner
prepare-cleaner:
	rm -rf $(ROOT)/out

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_PATH)/out/arm/core/tee-pager.bin \
	BL33=$(EDK2_BIN) \
	SCP_BL2=$(MCUIMAGE_BIN) \
	DEBUG=$(DEBUG) \
	LOG_LEVEL=50 \
	PLAT=hikey \
	SPD=opteed

ARM_TF_CONSOLE_UART ?= $(CFG_SW_CONSOLE_UART)
ifeq ($(ARM_TF_CONSOLE_UART),0)
	ARM_TF_FLAGS += CONSOLE_BASE=PL011_UART0_BASE \
			CRASH_CONSOLE_BASE=PL011_UART0_BASE
endif

arm-tf: optee-os edk2
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

.PHONY: arm-tf-clean
arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = hikey nocpio
BUSYBOX_CLEAN_COMMON_TARGET = hikey clean

busybox: busybox-common

.PHONY: busybox-clean
busybox-clean: busybox-clean-common

.PHONY: busybox-cleaner
busybox-cleaner: busybox-clean-common busybox-cleaner-common

################################################################################
# EDK2 / Tianocore
################################################################################
EDK2_ARCH ?= AARCH64
EDK2_DSC ?= OpenPlatformPkg/Platforms/Hisilicon/HiKey/HiKey.dsc
EDK2_TOOLCHAIN ?= GCC5
EDK2_BUILDFLAGS ?= -n `getconf _NPROCESSORS_ONLN`

EDK2_CONSOLE_UART ?= $(CFG_NW_CONSOLE_UART)
ifeq ($(EDK2_CONSOLE_UART),0)
	EDK2_BUILDFLAGS += -DSERIAL_BASE=0xF8015000
endif

define edk2-call
	GCC5_AARCH64_PREFIX=$(AARCH64_CROSS_COMPILE) \
	build -a $(EDK2_ARCH) -t $(EDK2_TOOLCHAIN) -p $(EDK2_DSC) \
		-b $(EDK2_BUILD) $(EDK2_BUILDFLAGS)
endef

.PHONY: edk2
edk2:
	cd $(EDK2_PATH) && rm -rf OpenPlatformPkg && \
		ln -s $(OPENPLATPKG_PATH)
	set -e && cd $(EDK2_PATH) && source edksetup.sh && \
		$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools && \
		$(call edk2-call)

.PHONY: edk2-clean
edk2-clean:
	set -e && cd $(EDK2_PATH) && source edksetup.sh && \
		$(call edk2-call) cleanall && \
		$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean
	rm -rf $(EDK2_PATH)/Build
	rm -rf $(EDK2_PATH)/Conf/.cache
	rm -f $(EDK2_PATH)/Conf/build_rule.txt
	rm -f $(EDK2_PATH)/Conf/target.txt
	rm -f $(EDK2_PATH)/Conf/tools_def.txt

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH ?= arm64
LINUX_DEFCONFIG_COMMON_FILES ?= $(LINUX_PATH)/arch/arm64/configs/defconfig \
				$(CURDIR)/kconfigs/hikey.conf \
				$(PATCHES_PATH)/kernel_config/usb_net_dm9601.conf \
				$(PATCHES_PATH)/kernel_config/ftrace.conf

linux-defconfig: $(LINUX_PATH)/.config

linux-gen_init_cpio: linux-defconfig
	$(MAKE) -C $(LINUX_PATH)/usr \
		CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
		ARCH=arm64 \
		LOCALVERSION= \
		gen_init_cpio

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-clean
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=hikey CFG_TEE_TA_LOG_LEVEL=3 CFG_CONSOLE_UART=$(CFG_SW_CONSOLE_UART)
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_DEBUG=y CFG_TEE_CORE_MALLOC_DEBUG=y CFG_TEE_TA_MALLOC_DEBUG=y CFG_PM_DEBUG=1 CFG_VERBOSE_INFO=y
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_EMBED_INTERNAL_TESTS=y CFG_WITH_STATS=y CFG_TEE_FS_KEY_MANAGER_TEST=y
#Test call force
#OPTEE_OS_COMMON_FLAGS += CFG_GPIO=n CFG_PL061=y CFG_SPI=n CFG_PL022=y
#Test auto set CFG_GPIO=y by call force
#OPTEE_OS_COMMON_FLAGS += CFG_PL061=y CFG_PL022=y NOWERROR=1
#PL061 and PL022 and SPI enabled by default
#OPTEE_OS_COMMON_FLAGS += CFG_SPI=y
OPTEE_OS_COMMON_FLAGS += CFG_SPI_TEST=y
#OPTEE_OS_COMMON_FLAGS += NOWERROR=1
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=hikey

optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################

xtest: xtest-common

# FIXME:
# "make clean" in xtest: fails if optee_os has been cleaned previously
.PHONY: xtest-clean
xtest-clean: xtest-clean-common
	rm -rf $(OPTEE_TEST_OUT_PATH)

.PHONY: xtest-patch
xtest-patch: xtest-patch-common

################################################################################
# hello_world
################################################################################
helloworld: helloworld-common

helloworld-clean: helloworld-clean-common

################################################################################
# strace
################################################################################
strace:
	cd $(STRACE_PATH); \
	./bootstrap; \
	set -e; \
	./configure --host=$(MULTIARCH) CC="$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)gcc" LD=$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)ld; \
	CC="$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)gcc" LD=$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)ld $(MAKE) -C $(STRACE_PATH)

.PHONY: strace-clean
strace-clean:
	if [ -e $(STRACE_PATH)/Makefile ]; then $(MAKE) -C $(STRACE_PATH) clean; fi

.PHONY: strace-cleaner
strace-cleaner: strace-clean
	rm -f $(STRACE_PATH)/Makefile $(STRACE_PATH)/configure

################################################################################
# Root FS
################################################################################
# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

.PHONY: filelist-tee
filelist-tee: filelist-tee-common
	env TOP=$(ROOT) $(expand-env-var) <$(PATCHES_PATH)/rootfs/initramfs-add-files.txt >> $(GEN_ROOTFS_FILELIST)

.PHONY: update_rootfs
update_rootfs: update_rootfs-common

.PHONY: update_rootfs-clean
update_rootfs-clean: update_rootfs-clean-common

################################################################################
# grub
################################################################################
grub-flags := CC="$(CCACHE)gcc" \
	TARGET_CC="$(AARCH64_CROSS_COMPILE)gcc" \
	TARGET_OBJCOPY="$(AARCH64_CROSS_COMPILE)objcopy" \
	TARGET_NM="$(AARCH64_CROSS_COMPILE)nm" \
	TARGET_RANLIB="$(AARCH64_CROSS_COMPILE)ranlib" \
	TARGET_STRIP="$(AARCH64_CROSS_COMPILE)strip"

GRUB_MODULES += boot chain configfile echo efinet eval ext2 fat font gettext \
                gfxterm gzio help linux loadenv lsefi normal part_gpt \
                part_msdos read regexp search search_fs_file search_fs_uuid \
                search_label terminal terminfo test tftp time

$(GRUB_PATH)/configure: $(GRUB_PATH)/configure.ac
	cd $(GRUB_PATH) && ./autogen.sh

$(GRUB_PATH)/Makefile: $(GRUB_PATH)/configure
	cd $(GRUB_PATH) && ./configure --target=aarch64 --enable-boot-time $(grub-flags)

.PHONY: grub
grub: prepare $(GRUB_PATH)/Makefile
	$(MAKE) -C $(GRUB_PATH); \
	cd $(GRUB_PATH) && ./grub-mkimage \
		--verbose \
		--output=$(OUT_PATH)/grubaa64.efi \
		--config=$(PATCHES_PATH)/grub/grub.configfile \
		--format=arm64-efi \
		--directory=grub-core \
		--prefix=/boot/grub \
		$(GRUB_MODULES)

.PHONY: grub-clean
grub-clean:
	if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) clean; fi
	rm -f $(OUT_PATH)/grubaa64.efi

.PHONY: grub-cleaner
grub-cleaner: grub-clean
	if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) distclean; fi
	rm -f $(GRUB_PATH)/configure

################################################################################
# Boot Image
################################################################################
ifeq ($(CFG_NW_CONSOLE_UART),3)
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart3.cfg
else
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart0.cfg
endif

boot-img: linux update_rootfs edk2 grub
	rm -f $(BOOT_IMG)
	mformat -i $(BOOT_IMG) -n 64 -h 255 -T 131072 -v "BOOT IMG" -C ::
	mcopy -i $(BOOT_IMG) $(LINUX_PATH)/arch/arm64/boot/Image ::
	mcopy -i $(BOOT_IMG) $(LINUX_PATH)/arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb ::
	mmd -i $(BOOT_IMG) ::/EFI
	mmd -i $(BOOT_IMG) ::/EFI/BOOT
	mcopy -i $(BOOT_IMG) $(OUT_PATH)/grubaa64.efi ::/EFI/BOOT/
	mcopy -i $(BOOT_IMG) $(GRUBCFG) ::/EFI/BOOT/grub.cfg
	mcopy -i $(BOOT_IMG) $(GEN_ROOTFS_PATH)/filesystem.cpio.gz ::/initrd.img
	mcopy -i $(BOOT_IMG) $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/AARCH64/AndroidFastbootApp.efi ::/EFI/BOOT/fastboot.efi

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

################################################################################
# atf-fastboot
################################################################################
ARM_TF_EXPORTS ?= \
	CFLAGS="-O0 -gdwarf-2" \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ATF_FB_FLAGS ?= \
	DEBUG=$(DEBUG) \
	PLAT=hikey

atf-fb:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ATF_FB_PATH) $(ATF_FB_FLAGS)

.PHONY: atf-fb-clean
atf-fb-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ATF_FB_PATH) $(ATF_FB_FLAGS) clean

################################################################################
# l-loader
################################################################################
lloader-bin: arm-tf atf-fb
	cd $(LLOADER_PATH) && \
		ln -sf $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin && \
		ln -sf $(ATF_FB_PATH)/build/hikey/$(ATF_FB_BUILD)/bl1.bin fastboot.bin && \
		$(AARCH32_CROSS_COMPILE)gcc -c -o start.o start.S && \
		$(AARCH32_CROSS_COMPILE)ld -Bstatic -Tl-loader.lds -Ttext 0xf9800800 start.o -o loader && \
		$(AARCH32_CROSS_COMPILE)objcopy -O binary loader temp && \
		python gen_loader_hikey.py -o l-loader.bin --img_loader=temp --img_bl1=bl1.bin --img_ns_bl1u=fastboot.bin

.PHONY: lloader-bin-clean
lloader-bin-clean:
	cd $(LLOADER_PATH) && \
		rm -f l-loader.bin temp loader start.o

lloader-ptbl:
	cd $(LLOADER_PATH) && \
		PTABLE=linux-$(CFG_FLASH_SIZE)g SECTOR_SIZE=512 bash -x generate_ptable.sh

.PHONY: lloader-ptbl-clean
lloader-ptbl-clean:
	cd $(LLOADER_PATH) && rm -f prm_ptable.img sec_ptable.img

lloader: lloader-bin lloader-ptbl

.PHONY: lloader-clean
lloader-clean: lloader-bin-clean lloader-ptbl-clean

################################################################################
# nvme image
################################################################################
.PHONY: nvme
nvme: prepare
	wget https://builds.96boards.org/releases/hikey/linaro/binaries/latest/nvme.img -O $(NVME_IMG)

.PHONY: nvme-cleaner
nvme-cleaner:
	rm -f $(NVME_IMG)

################################################################################
# Flash
################################################################################
define flash_help
	@read -r -p "1. Connect USB OTG cable, the micro USB cable (press enter)" dummy
	@read -r -p "2. Connect HiKey to power up (press enter)" dummy
endef

.PHONY: recovery
recovery:
	@echo "Enter recovery mode to flash a new bootloader"
	@echo
	@echo "Make sure udev permissions are set appropriately:"
	@echo "  # /etc/udev/rules.d/hikey.rules"
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="d00d", MODE="0666"'
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="12d1", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"'
	@echo
	@echo "Set jumpers or switches as follows:"
	@echo "Jumper 1-2: Closed	or	Switch  1: On"
	@echo "       3-4: Closed	or		2: On"
	@echo "       5-6: Open	or		3: Off"
	@read -r -p "Press enter to continue" dummy
	@echo
	$(call flash_help)
	@echo
	python $(ROOT)/burn-boot/hisi-idt.py --img1=$(LLOADER_PATH)/l-loader.bin
	@echo
	@echo "3. Wait until you see the (UART) message"
	@echo "    \"Enter downloading mode. Please run fastboot command on Host.\""
	@echo "    \"usb: online (highspeed)\""
	@$(MAKE) --no-print flash FROM_RECOVERY=1

.PHONY: flash
flash:
ifneq ($(FROM_RECOVERY),1)
	@echo "Flash binaries using fastboot"
	@echo
	@echo "Set jumpers or switches as follows:"
	@echo "Jumper 1-2: Closed	or	Switch  1: On"
	@echo "       3-4: Open	or		2: Off"
	@echo "       5-6: Closed	or		3: On"
	@read -r -p "Press enter to continue" dummy
	@echo
	$(call flash_help)
	@echo "3. Wait until you see the (UART) message"
	@echo "    \"Android Fastboot mode - version x.x Press any key to quit.\""
endif
	@read -r -p "Then press enter to continue flashing" dummy
	@echo
	fastboot flash ptable $(LLOADER_PATH)/prm_ptable.img
	fastboot flash fastboot $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/fip.bin
	fastboot flash nvme $(NVME_IMG)
	fastboot flash boot $(BOOT_IMG)
