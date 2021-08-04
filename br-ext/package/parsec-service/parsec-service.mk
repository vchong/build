PARSEC_SVC_VERSION = 0.72
#PARSEC_SVC_SOURCE = parsec-$(PARSEC_SVC_VERSION).tar.gz
#PARSEC_SVC_SITE = $(call github,parallaxsecond,parsec,$(PARSEC_SVC_VERSION))
PARSEC_SVC_SOURCE = local
PARSEC_SVC_SITE = $(BR2_PACKAGE_PARSEC_SVC_SITE)
PARSEC_SVC_SITE_METHOD = local
PARSEC_SVC_LICENSE = Public Domain
PARSEC_SVC_INSTALL_STAGING = YES

PARSEC_SVC_DEPENDENCIES = host-rustc host-cargo

PARSEC_SVC_CARGO_ENV = CARGO_HOME=$(HOST_DIR)/usr/share/cargo
#PARSEC_SVC_CARGO_ENV += RUST_TARGET_PATH=$(HOST_DIR)/etc/rustc

PARSEC_SVC_BIN_DIR = target/$(RUSTC_TARGET_NAME)/$(PARSEC_SVC_CARGO_MODE)

PARSEC_SVC_CARGO_OPTS = \
	$(if $(BR2_ENABLE_DEBUG),,--release) \
	--target=$(RUSTC_TARGET_NAME) \
	--manifest-path=$(@D)/Cargo.toml \
	--features all-providers,cryptoki/generate-bindings,tss-esapi/generate-bindings

define PARSEC_SVC_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(PARSEC_SVC_CARGO_ENV) \
		cargo build $(PARSEC_SVC_CARGO_OPTS)
endef

define PARSEC_SVC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(PARSEC_SVC_BIN_DIR)/parsec \
		$(TARGET_DIR)/usr/bin/parsec
endef

$(eval $(generic-package))
