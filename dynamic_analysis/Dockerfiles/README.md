# Dockerfile
These are files to help build the docker image for each arch.

1. The `Dockerfile` is a template for building qemu-4.1 image inside docker
2. The `logger.sh` file is a utility file to log information, warnings, errors, and debug messages.
3. The `run_analysis.sh` is the main script that runs the analysis inside the docker container

This docker build is missing four files, which need to be built out.

1. `zImage` file is the the Linux Kernel image for a given arch
2. `rootfs.ext2` file is the root file system, which the VM boots into
3. `vexpress-v2p-ca9.dtb` file is the device table file for the Linux Kernel

All of these three files are built using Buildroot2.
The instructions for building these specific environment is documented in the `BR2` folder.

The last file `run_vm.sh`, is a shell script that has all the configuration required to boot the VM.
This includes setting up the path to the Linux Kernel, the device table, rootfs, network device, packet capture, and more.
See example files.

# Building docker container

```bash
$ docker build . -t arm-qemu:1.0-glibc
```

# Running docker container

```bash
docker run -d --rm --privileged -v $PWD/bins:/br2/bins --name ${fileHash} arm-qemu:1.0-glibc /br2/bins/${fileName} 60
```

# Running MANY containers

```bash
find bins/ -type f -name "*.bin" | parallel 'docker run -d --rm --privileged -v $PWD/bins:/br2/bins --name {/.} arm-qemu:1.0-glibc /br2/{} 60; sleep 3; docker logs -f {/.} &> logs/{/.}.log &' 
```
