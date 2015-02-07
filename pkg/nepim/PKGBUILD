# Maintainer: Dan Serban
# Contributors: William Rea, Jaroslaw Swierczynski, Jaroslav Lichtblau

pkgname=nepim
pkgver=0.53
pkgrel=1
pkgdesc="A tool for measuring available bandwidth between hosts"
arch=(i686 x86_64)
url=http://www.nongnu.org/nepim/
license=(GPL)
depends=(liboop)
source=("http://download.savannah.gnu.org/releases/nepim/nepim-${pkgver}.tar.gz")
md5sums=('6f7a09e8cb7e605ebe35815ed9239536')

build()
{
  cd nepim-${pkgver}/src
  unset LDFLAGS
  make OOP_BASE=/usr
}

package()
{
  cd nepim-${pkgver}/src
  install -Dm755 nepim "${pkgdir}"/usr/bin/nepim
}
