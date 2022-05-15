# Building Buildroot (BR2) Env
The `.config` file in this directory contains the build packages and options used to build this ARM enviornment.
To rebuild from scratch (it will take a long time) follow these steps:

```bash
$ export BR2PATH=/path/to/your/buildroot/directory
$ export BUILDPATH=/path/to/your/build/env
```
You can download buildroot from the following URL: https://github.com/buildroot/buildroot
For this build, I used branch 2019.11.x.tgz

Run the following command to add/remove addtional packages (optional).
```bash
$ make menuconfig -O $BUILDPATH -C $BR2PATH
```

Run the following command to configure the Linux kernel (optional).
```bash
$ make linux-menuconfig -O $BUILDPATH -C $BR2PATH
```

Run the following command to build the BR2 environment.
```bash
$ make -O $BUILDPATH -C $BR2PATH
```


# Run The BR2 Env
The configuration is based on `qemu_arm_vexpress_defconfig`. 
The included `.config` is already set to use the `defconfig` for `qemu_arm_vexpress_defconfig`.
No additional steps are required.

The QEMU binary is built from source based on version `3.0.5`.
I recommend to use version `3.0.5` and higher to avoid any compatiablity issues.
QEMU source can be downloaded from: `https://github.com/qemu/qemu`
Pre-built QEMU binaries are also available.

```bash
$ /path/to/qemu-system-arm -M vexpress-a9 -smp 1 -m 256 -kernel ./zImage -dtb ./vexpress-v2p-ca9.dtb -drive file=./rootfs.ext2,if=sd,format=raw -append "console=ttyAMA0,115200 rootwait root=/dev/mmcblk0" -serial stdio -net nic,model=lan9118 -net user
```
