################################################################################
#
# SoftHSMv2
#
################################################################################

SOFTHSMV2_VERSION = 2.6.1
SOFTHSMV2_SOURCE = SoftHSMv2-$(SOFTHSMV2_VERSION).tar.gz
SOFTHSMV2_SITE = $(call github,opendnssec,SoftHSMv2,$(SOFTHSMV2_VERSION))
#SOFTHSMV2_SITE_METHOD = git

SOFTHSMV2_INSTALL_STAGING = NO
SOFTHSMV2_INSTALL_TARGET = YES

SOFTHSMV2_AUTORECONF = YES
SOFTHSMV2_AUTORECONF_OPTS = --verbose --install --force
SOFTHSMV2_DEPENDENCIES = openssl

#SOFTHSMV2_CONF_OPTS = --with-pkcs11-provider=/usr/lib/libckteec.so

$(eval $(autotools-package))
