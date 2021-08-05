CARGO_VERSION = 0.55.0
#CARGO_SOURCE = parsec-$(CARGO_VERSION).tar.gz
#CARGO_SITE = $(call github,rust-lang,cargo,$(CARGO_VERSION))
CARGO_SOURCE = local
CARGO_SITE = $(BR2_PACKAGE_CARGO_SITE)
CARGO_SITE_METHOD = local
CARGO_LICENSE = Public Domain
CARGO_INSTALL_STAGING = YES

# host-cargo does NOT exist
#CARGO_DEPENDENCIES = host-rustc host-cargo
CARGO_DEPENDENCIES = host-rustc

CARGO_CARGO_ENV = CARGO_HOME=$(HOST_DIR)/usr/share/cargo
#CARGO_CARGO_ENV += RUST_TARGET_PATH=$(HOST_DIR)/etc/rustc

ifeq ($(BR2_ENABLE_DEBUG),y)
CARGO_CARGO_MODE = debug
else
CARGO_CARGO_MODE = release
endif

CARGO_BIN_DIR = target/$(RUSTC_TARGET_NAME)/$(CARGO_CARGO_MODE)

CARGO_CARGO_OPTS = \
	--$(CARGO_CARGO_MODE) \
	--target=$(RUSTC_TARGET_NAME) \
	--manifest-path=$(@D)/Cargo.toml \

define CARGO_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(CARGO_CARGO_ENV) \
		cargo build $(CARGO_CARGO_OPTS)
endef

define CARGO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(CARGO_BIN_DIR)/parsec-tool \
		$(TARGET_DIR)/usr/bin/parsec-tool
endef

$(eval $(generic-package))
