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

## Run on Android phone

