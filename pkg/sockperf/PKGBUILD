# Maintainer:  Daniel YC Lin <dlin.tw@gmail.com>

pkgname=sockperf
pkgver=2.5.241
pkgrel=1
pkgdesc='Benchmarking tool for many different types of networking'
url='http://www.netperf.org/'
license=('custom') # BSD-3
arch=('i686' 'x86_64' sh4)
#depends=('glibc' 'libsmbios' 'lksctp-tools')
#install=$pkgname.install
source=("http://sockperf.googlecode.com/files/sockperf-$pkgver.tar.gz")
#  2.5.240-install.patch)

#prepare() {
#  cd $pkgname-$pkgver
#  patch -p1 -i $srcdir/2.5.240-install.patch
#}
build() {
  cd $pkgname-$pkgver
  #./autogen.sh
  ./configure --prefix=/usr --enable-test --enable-doc --enable-tool
  make
}

package() {
  cd $pkgname-$pkgver
  make DESTDIR="$pkgdir" install
  # license
  install -D -m 644 copying "$pkgdir/usr/share/licenses/$pkgname/COPYING"
}

# vim:set ts=2 sw=2 et:
md5sums=('9daf18578324407dbbb9547da48ab433')
