CC              ?= aarch64-apple-darwin-clang
STRIP           ?= aarch64-apple-darwin-strip
LDID            ?= ldid
INSTALL         ?= install
FAKEROOT        ?= fakeroot
PREFIX          ?= /usr
TARGET_SYSROOT  ?= /home/cameron/Documents/SDK/iPhoneOS14.2.sdk
CFLAGS          ?= -arch arm64 -isysroot $(TARGET_SYSROOT) -miphoneos-version-min=13.0

DEB_MAINTAINER  ?= Cameron Katri <me@cameronkatri.com>
DEB_ARCH        ?= iphoneos-arm
SNAPRESTORE_V   := 0.3
DEB_SNAPRESTORE := $(SNAPRESTORE_V)

all: build/snaprestore

build/snaprestore: src/snaprestore.m src/ent.xml
	mkdir -p build
	$(CC) $(CFLAGS) -o $@ $< -framework IOKit -framework Foundation -framework CoreServices -fobjc-arc
	$(STRIP) $@
	$(LDID) -S$(word 2,$^) $@

install: build/snaprestore LICENSE
	$(INSTALL) -Dm755 $< $(DESTDIR)$(PREFIX)/bin/snaprestore
	$(INSTALL) -Dm644 $(word 2,$^) $(DESTDIR)$(PREFIX)/share/snaprestore/$(word 2,$^)

package: install
	rm -rf staging
	mkdir -p staging
	cp -a $(DESTDIR)$(PREFIX) staging
	$(FAKEROOT) chown -R 0:0 staging
	$(INSTALL) -Dm755 src/snaprestore.control staging/DEBIAN/control
	sed -e 's/@DEB_SNAPRESTORE@/$(DEB_SNAPRESTORE)/g' \
	    -e 's/@DEB_MAINTAINER@/$(DEB_MAINTAINER)/g' \
	    -e 's/@DEB_ARCH@/$(DEB_ARCH)/g' -i staging/DEBIAN/control
	find staging -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf '"%P" ' | xargs md5sum > staging/DEBIAN/md5sum
	echo "Installed-Size: $$(du -s staging | cut -f 1)" >> staging/DEBIAN/control
	$(FAKEROOT) dpkg-deb -z9 -b staging build
	rm -rf staging

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/bin/snaprestore $(DESTDIR)$(PREFIX)/share/snaprestore

clean:
	rm -rf build

.PHONY: all package uninstall clean
