# Dynamic Analysis Using Full System Emulation 
The dynamic analysis is built using Qemu 4.1.1 and BuildRoot 2.
We have created six different Linux enviornment for ARM, MIPS, MIPS-EL, SPARC, PPC, and SH4.
We have packaged them using Docker to simplify their setup and usage.

## Quick Start
First thing you want to do is go over to Dropbox folder and download the docker images here:

```
https://www.dropbox.com/sh/llgvodpe545pu0m/AAAreuO7q4GOcTRWHRBd9Z9ta?dl=0
```

Once you have downloaded the architecture of interest, you must import the docker image into your image library like so:

```bash
# loading ARM Arch analyzer

# gunzip the file
$> gunzip -d arm-qemu-1.0-uclibc.tar.gz
$> docker load -i arm-qemu-1.0-uclibc.tar 
```

Once you load the docker image, you can not run a test to make sure it works correctly like so:

```bash
$> docker run --rm -it arm-qemu:1.0-uclibc -h

usage: /br2/run_analysis.sh PARAMETERS [OPTION]

PARAMETERS:
  -i, --input-bin  VAL  The path to the binary for analysis

OPTION:
  -t, --timeout    VAL How long to allow the binary to run before terminating analysis, default 60 sec
  -R, --full-run       Run the analysis for the timeout even if no system activity is detected
  -r, --rename-bin VAL Rename the binary file before running it to VAL
  -h,  --help          Prints this help

example: /br2/run_analysis.sh -i /br2/malware.bin -t 60 -R -r evil.bin

```

Next, you need to map the directory with the malware you want to analyze to a mount point inside the container (i.e. /br2/bins/).
You can choose any path you want, but make sure to specify it as a parameter when running the docker container.
The following is an example of how to run a malware sample in the ARM analyzer and what the output will look like:

```bash
$> ls
bin  dst  src
$> ls bin
4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e.bin
```

As you can see, my current directory has a folder called bin, which contains the malware binary file.
Next, we are going to run the newly imported docker container and mount the bin directory so that our full system analyzer runs the sample in a Linux environment.

```bash
$> docker run -it --rm -v $PWD/bin:/br2/bins --privileged arm-qemu:1.0-uclibc -i /br2/bins/4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e.bin -r abc.exe -t 35
```

To understand the docker command, we will go through each flag and parameter to make this example illustrative.
First, we invoke docker with the `run`command and pass `-it` flag, which tells docker to attach the output to the terminal output and allow interaction.
Next, we specify the `--rm` flag, which removes the container after it is done running.
It does not remove the container's image, only the instance that ran the malware because we don't want them accumulating on the system.
Next, we pass the `-v` flag, which tells docker to mount a "Volume" from the host machine to the docker container.
In this case we mount our `bin` directory to the mount point `/br2/bins`. 
Next, we pass the flag `--priviledged`, which gives the docker container the right to use the `mount` command.
The `mount` command is required to load the malware into the analysis environment using the Qemu file system.
Finally, we specify the docker image we want to run, in this case it is `arm-qemu:1.0-uclibc`.
The image is for the ARM arch. and it uses the `uClibc` for the Linux environment. 

After that, we specify the malware analysis parameters to the analyzer, which will run inside the QEMU emulator.
The `-i` flag specifies the path for the malware sample to run, the `-r` flag renames the sample to `abc.exe` and the `-t` flag sets the analysis timeout (35 seconds, the default is 60 seconds).
The following is the output from the full system emulation:
```bash
2021-08-13 04:38:49 INFO: Full file path to analyze: 
  /br2/bins/4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e.bin
2021-08-13 04:38:49 INFO: Analysis timeout: 35 sec
2021-08-13 04:38:49 INFO: Binary file renamed from 4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e.bin 
  to abc.exe
2021-08-13 04:38:49 INFO: Running system call tracing
2021-08-13 04:38:49 INFO: Full analysis timeout disabled
2021-08-13 04:38:49 INFO: Preping rootfs for analysis
2021-08-13 04:38:49 INFO: Mounting rootfs
2021-08-13 04:38:51 INFO: Copying binary into rootfs
2021-08-13 04:38:51 INFO: Unmounting rootfs
2021-08-13 04:38:51 INFO: Starting analysis VM...
VNC server running on 127.0.0.1:5900
2021-08-13 04:38:51 INFO: Analysis VM started, waiting on guest to boot
ssh: connect to host 127.0.0.1 port 22: Connection timed out
2021-08-13 04:39:01 DEBUG: Guest not responding, sleeping and checking later
2021-08-13 04:39:11 DEBUG: Checking guest...
Warning: Permanently added '127.0.0.1' (ECDSA) to the list of known hosts.
Linux IOT-GENOME 4.19.16 #3 SMP Fri Dec 27 22:50:20 EST 2019 armv7l GNU/Linux
2021-08-13 04:39:12 INFO: Guest is up and kicking!
2021-08-13 04:39:12 DEBUG: Checking liveness
Warning: Permanently added '127.0.0.1' (ECDSA) to the list of known hosts.
liveness test: ping
2021-08-13 04:39:12 INFO: Running abc.exe
2021-08-13 04:39:13 INFO: Analyzing...
2021-08-13 04:39:48 WARNING: SSH failed, retrying...
2021-08-13 04:39:55 WARNING: Cannot access VM via SSH, sleeping for rest of the analysis
2021-08-13 04:39:55 INFO: Analysis complete!
2021-08-13 04:39:55 INFO: Powering off VM...
QEMU 4.1.1 monitor - type 'help' for more information
(qemu) q
2021-08-13 04:39:58 INFO: Done!
2021-08-13 04:39:58 INFO: Collecting system traces
2021-08-13 04:39:58 INFO: Creating dir /br2/bins/4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e
2021-08-13 04:39:58 INFO: Mounting volume
2021-08-13 04:39:58 INFO: Copying over artifacts...
2021-08-13 04:39:58 INFO: Number of files found: 10
2021-08-13 04:39:58 INFO: Creating archive...
2021-08-13 04:39:58 INFO: Done!
```

Once the analysis is done, you will find a tar gzip archive in the `bin` file like so:

```bash
$> ls -1 bin/
4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e.bin
4c962e8714a622d114a6b083e5eb9b2699bff4f4f04efd669020fb2d6f158e1e.results.tgz
```

The archive file contains the system call trace and the network traffic packet capture (PCAP).


