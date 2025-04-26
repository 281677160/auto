include $(TOPDIR)/rules.mk

PKG_NAME:=autoupdate
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Your Name <your@email.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/autoupdate
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=OpenWrt Auto Update Utility
  DEPENDS:=+curl +wget
  PKGARCH:=all
endef

define Package/autoupdate/description
  Auto update utility for OpenWrt firmware.
endef

define Package/autoupdate/conffiles
/etc/config/autoupdate
/etc/openwrt_update
endef

define Package/autoupdate/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/autoupdate $(1)/etc/config/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/autoupdate $(1)/etc/init.d/
	
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/autoupdate.sh $(1)/usr/bin/AutoUpdate
	$(INSTALL_BIN) ./files/AutoUpdate.sh $(1)/usr/bin/AutoUpdate.sh
	
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_CONF) ./files/etc/openwrt_update $(1)/etc/
endef

$(eval $(call BuildPackage,autoupdate))
