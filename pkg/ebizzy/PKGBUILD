# Maintainer: Masami Ichikawae <masami256@gmail.com>
# vim:set ts=2 sw=2 et filetype=sh:
pkgname=ebizzy
pkgver=0.3
pkgrel=2
pkgdesc="Generate a workload resembling common web application server workloads."
arch=('i686' 'x86_64')
url="http://ebizzy.sourceforge.net/"
license=('GPL2')
depends=('glibc')
source=('http://downloads.sourceforge.net/project/ebizzy/ebizzy/0.3/ebizzy-0.3.tar.gz')
md5sums=('af038bc506066bb3d28db08aba62bc38') 

build() {
    cd "$srcdir/$pkgname-$pkgver"
    ./configure
    make
}

package() {
    cd "$srcdir/$pkgname-$pkgver"

    mkdir -p "$pkgdir/usr/bin/"
    mkdir -p "$pkgdir/usr/share/licenses/$pkgname"
    mkdir -p "$pkgdir/usr/share/$pkgname"

    install -D -m 755 -o root -g root "$pkgname" "$pkgdir/usr/bin/$pkgname"
    install -D -m 644 -o root -g root "LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    install -D -m 644 -o root -g root "README" "$pkgdir/usr/share/$pkgname/README"
    
}
