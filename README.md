# ARM

## Build

* Enable multiarch for docker:
```
sudo apt-get install qemu binfmt-support qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```
* Build:
```
docker build -f Dockerfile.arm -t rcmorano/cardano-node:arm .
```
* Extract binaries:
```
CID=$(docker create rcmorano/cardano-node:arm)
docker cp ${CID}:/output /tmp
mv /tmp/output/* /usr/local/bin
```

## Run on Android phone

* Setup an ubuntu-focal chroot in e.g., using [termux-ubuntu-baids]
* Spawn a shell inside the chroot:
```
termux-ubuntu-shell focal
```
* Install depends inside the chroot:
```
apt-get install libatomic1
```
* Copy precompiled binaries from this project's releases (or build your own, tho it will take a while!) into /usr/local/bin:
* Enjoy!

[termux-ubuntu-baids]: https://github.com/rcmorano/termux-ubuntu-baids#instructions
