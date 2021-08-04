PARSEC_SERVICE_VERSION = 0.72
#PARSEC_SERVICE_SOURCE = parsec-$(PARSEC_SERVICE_VERSION).tar.gz
#PARSEC_SERVICE_SITE = $(call github,parallaxsecond,parsec,$(PARSEC_SERVICE_VERSION))
PARSEC_SERVICE_SOURCE = local
PARSEC_SERVICE_SITE = $(BR2_PACKAGE_PARSEC_SERVICE_SITE)
PARSEC_SERVICE_SITE_METHOD = local
PARSEC_SERVICE_LICENSE = Public Domain
PARSEC_SERVICE_INSTALL_STAGING = YES

PARSEC_SERVICE_DEPENDENCIES = host-rustc host-cargo

PARSEC_SERVICE_CARGO_ENV = CARGO_HOME=$(HOST_DIR)/usr/share/cargo
#PARSEC_SERVICE_CARGO_ENV += RUST_TARGET_PATH=$(HOST_DIR)/etc/rustc

PARSEC_SERVICE_BIN_DIR = target/$(RUSTC_TARGET_NAME)/$(PARSEC_SERVICE_CARGO_MODE)

PARSEC_SERVICE_CARGO_OPTS = \
	$(if $(BR2_ENABLE_DEBUG),,--release) \
	--target=$(RUSTC_TARGET_NAME) \
	--manifest-path=$(@D)/Cargo.toml \
	--features all-providers,cryptoki/generate-bindings,tss-esapi/generate-bindings

define PARSEC_SERVICE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(PARSEC_SERVICE_CARGO_ENV) \
		cargo build $(PARSEC_SERVICE_CARGO_OPTS)
endef

define PARSEC_SERVICE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(PARSEC_SERVICE_BIN_DIR)/parsec \
		$(TARGET_DIR)/usr/bin/parsec
endef

$(eval $(generic-package))
