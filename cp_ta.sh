#!/bin/bash

mkdir -p ${GROOT}/aosp/out/target/product/trusty/vendor/lib
rm -rf ${GROOT}/aosp/out/target/product/trusty/vendor/lib/optee_armtz
cp -a ${GROOT}/optee/out-br/target/lib/optee_armtz ${GROOT}/aosp/out/target/product/trusty/vendor/lib/

#mkdir -p ../../../aosp/qemu_trusty_arm64/out/target/product/trusty/vendor/lib
#rm -rf ../../../aosp/qemu_trusty_arm64/out/target/product/trusty/vendor/lib/optee_armtz
#cp -a ../out-br/target/lib/optee_armtz ../../../aosp/qemu_trusty_arm64/out/target/product/trusty/vendor/lib/
#trash-empty
