#!/bin/sh
set -e

REPO="https://www.collaboraoffice.com/repos/CollaboraOnline/CODE-deb"

case "$(uname -m)" in
    x86_64)  DEB_ARCH="amd64" ;;
    aarch64) DEB_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

download "${REPO}/Packages" > /tmp/Packages

pkg_filename() {
    python3 -c "
import sys
target_pkg, target_arch = sys.argv[1], sys.argv[2]
pkg = arch = filename = None
with open('/tmp/Packages') as f:
    for line in f:
        line = line.rstrip('\n')
        if line.startswith('Package: '):
            pkg = line[9:]; arch = filename = None
        elif line.startswith('Architecture: '):
            arch = line[14:]
        elif line.startswith('Filename: '):
            filename = line[10:]
        elif line == '':
            if pkg == target_pkg and arch in (target_arch, 'all') and filename:
                print(filename)
                sys.exit(0)
            pkg = arch = filename = None
" "$1" "$DEB_ARCH"
}

install_deb() {
    local deb="$1"
    local staging=/tmp/deb_staging
    rm -rf "$staging"
    dpkg-deb -x "$deb" "$staging"
    # Debian hasn't completed usr-merge: /lib is separate, Gentoo has /lib -> usr/lib
    if [ -d "$staging/lib" ]; then
        cp -a "$staging/lib/." /usr/lib/
        rm -rf "$staging/lib"
    fi
    cp -a "$staging/." /
    rm -rf "$staging"
}

for pkg in \
    collaboraoffice-ure \
    collaboraofficebasis-core \
    collaboraofficebasis-images \
    collaboraofficebasis-libreofficekit-data \
    collaboraofficebasis-ooofonts \
    collaboraofficebasis-ooolinguistic \
    collaboraofficebasis-graphicfilter \
    collaboraofficebasis-xsltfilter \
    collaboraofficebasis-writer \
    collaboraofficebasis-calc \
    collaboraofficebasis-impress \
    collaboraofficebasis-draw \
    collaboraofficebasis-math \
    collaboraofficebasis-extension-pdf-import \
    collaboraofficebasis-en-us \
    coolwsd \
; do
    filename=$(pkg_filename "$pkg")
    if [ -z "$filename" ]; then
        echo "ERROR: Package not found in repo: $pkg ($DEB_ARCH)" >&2
        exit 1
    fi
    echo "Installing ${pkg}: ${filename}"
    download "${REPO}/${filename}" > /tmp/${pkg}.deb
    install_deb /tmp/${pkg}.deb
    rm -f /tmp/${pkg}.deb
done

rm -f /tmp/Packages

# Directory setup (mirrors postinst)
mkdir -p /opt/cool/child-roots /opt/cool/cache
chown cool: /opt/cool /opt/cool/child-roots /opt/cool/cache
chown cool: /etc/coolwsd/coolwsd.xml
chmod 640 /etc/coolwsd/coolwsd.xml

# Build systemplate (chroot sandbox for document conversion)
fc-cache /opt/collaboraoffice/share/fonts/truetype
coolwsd-systemplate-setup /opt/cool/systemplate /opt/collaboraoffice

# Generate WOPI proof key
coolconfig generate-proof-key

# Disable SSL (terminated by reverse proxy upstream)
python3 -c "
import re
with open('/etc/coolwsd/coolwsd.xml') as f:
    content = f.read()
content = re.sub(
    r'(<ssl\b[^>]*>.*?<enable\b[^>]*>)true(</enable>)',
    r'\1false\2', content, flags=re.DOTALL)
content = re.sub(
    r'(<ssl\b[^>]*>.*?<termination\b[^>]*>)false(</termination>)',
    r'\1true\2', content, flags=re.DOTALL)
with open('/etc/coolwsd/coolwsd.xml', 'w') as f:
    f.write(content)
print('ssl.enable=false, ssl.termination=true')
"
