KMGK_EXT_VERSION = 1.0
KMGK_EXT_SOURCE = local
KMGK_EXT_SITE = $(BR2_PACKAGE_KMGK_EXT_SITE)
KMGK_EXT_SITE_METHOD = local
KMGK_EXT_INSTALL_STAGING = YES
KMGK_EXT_DEPENDENCIES = optee_client_ext host-python3-pycryptodomex
KMGK_EXT_SDK = $(BR2_PACKAGE_KMGK_EXT_SDK)
KMGK_EXT_CONF_OPTS = -DKMGK_SDK=$(KMGK_EXT_SDK)

define KMGK_EXT_BUILD_TAS
	@$(foreach f,$(wildcard $(@D)/*/ta/Makefile), \
		echo Building $f && \
			$(MAKE) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_KMGK_EXT_CROSS_COMPILE))" \
			O=out TA_DEV_KIT_DIR=$(KMGK_EXT_SDK) \
			PYTHON3=$(HOST_DIR)/bin/python3 \
			$(TARGET_CONFIGURE_OPTS) -C $(dir $f) all &&) true
endef

define KMGK_EXT_INSTALL_TAS
	@$(foreach f,$(wildcard $(@D)/*/ta/out/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

KMGK_EXT_POST_BUILD_HOOKS += KMGK_EXT_BUILD_TAS
KMGK_EXT_POST_INSTALL_TARGET_HOOKS += KMGK_EXT_INSTALL_TAS

$(eval $(cmake-package))
