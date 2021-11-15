# OP-TEE build.git

This git contains makefiles etc to be able to build a full OP-TEE developer
setup for the OP-TEE project.

All official OP-TEE documentation has moved to http://optee.readthedocs.io. The
pages that used to be here in this git can be found under [build] and [Device
specific information] at he new location for the OP-TEE documentation.

// OP-TEE core maintainers

# About the configuration

Option SWTPM has been added for this flow. It is enabled by default. It also enables
MEASURED_BOOT option internally.

Manifest to be used - https://github.com/ruchi393/manifest/tree/swtpm

	$ repo init -u https://github.com/ruchi393/manifest.git -m qemu_v8.xml -b swtpm
	$ repo sync

Follow the regular steps to get the toolchain.

Rootfs is pre-built for this flow as we want to use the latest tpm2-tools not available with buildroot.
    
Linux is available in this rootfs, so it has not been built separately.


# sw-tpm

Before launching qemu, install sw-tpm on your host machine

	$ sudo apt install swtpm
[I couldn't find this package for Ubuntu, so followd the wiki pages here
 Debian seems to have a package for swtpm though ]

### Install libtpms
Clone path - https://github.com/stefanberger/libtpms.git

### Installation steps at:
https://github.com/stefanberger/libtpms/wiki

### Install swtpm
Clone path - https://github.com/stefanberger/swtpm.git 
https://github.com/stefanberger/swtpm/wiki

Once Installed, you can launch it using the following command

	$ swtpm socket --tpmstate dir=/tmp/mytpm1 --ctrl type=unixio,path=/tmp/mytpm1/swtpm-sock  --log level=40 --tpm2
    
# How to run

### Launch sw-tpm as mentioned above

### Create esp.img

ESP partition is required for variable storage and boot using bootefi. 
You need to manually follow the steps below to generate a esp.img and manually place it in out/bin folder

	$ dd if=/dev/zero of=esp.img bs=1MB count=500
	$ sudo gdisk esp.img

- When asked create a GPT ,then press n and create a new partiton with all 500mb.
- Then press 't' (once you create a new partition) then select ef00 as it's type
- Now press w to write the changes

Once esp.img is created, do the following

	$ sudo losetup -f -P esp.img

if you check your dmesg, there should be a message like. It can be loop0 or loop1

	$ [621627.530154]  loop1: p1

Change the argument based on dmesg in below command.

	$ sudo mkfs.vfat /dev/loop1p1
	$ sudo losetup -D

Anytime you want to make changes on the image just use losetup -> mount -> losetup -D again

### Launch QEMU

	$ cd build
	$ make -j12 run

### On u-boot
On u-boot, using boot command would use bootefi and also invoke softtpm.
    
### On Linux
At linux, do the following to see evenlog

	$ sh log

[build]: https://optee.readthedocs.io/en/latest/building/index.html
[Device specific information]: https://optee.readthedocs.io/en/latest/building/devices/index.html
