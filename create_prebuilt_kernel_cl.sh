#!/bin/sh

modules=""
audio_module_dir=""
wlan_module_dir=""
prebuilt_kernel_dir=`cat build.config | grep PREBUILT_KERNEL_REPO | cut -d '=' -f 2`
kernel_home=`cat build.config | grep KERNEL_DIR | cut -d '=' -f 2`
kernel_branch=`cat build.config | grep BRANCH | awk 'NR == 1'| cut -d '=' -f 2`
kernel_build_branch=`cat build.config | grep KERNEL_BUILD_BRANCH | cut -d '=' -f 2`
product=`cat build.config | grep 'DEFCONFIG\=' | cut -d '=' -f 2 | cut -d '_' -f 1`
audio_module_dir=`cat build.config | grep AUDIO_MODULE_DIR | cut -d '=' -f 2`
wlan_module_dir=`cat build.config | grep WLAN_MODULE_DIR | cut -d '=' -f 2`

echo "prebuilt_kernel_dir = $prebuilt_kernel_dir"
echo "kernel_home= $kernel_home"
echo "kernel_branch= $kernel_branch"
echo "kernel_build_branch= $kernel_build_branch"
echo "product= $product"
echo "audio_module_dir=$audio_module_dir"
echo "wlan_module_dir=$wlan_module_dir"

cd $prebuilt_kernel_dir
repo abandon new_kernel_$product
repo start new_kernel_$product .
commit_msg="$product: update prebuilt kernel"

previous_prebuilt_commit=`extract-version kernel | awk 'NR == 1' | cut -d ' ' -f 3 | cut -d '-' -f 2  | cut -c 2-`

/google/data/ro/projects/android/fetch_artifact --latest --kernel --branch $kernel_build_branch zImage-dtb
latest_prebuilt_commit=`extract-version zImage-dtb | awk 'NR == 1' | cut -d ' ' -f 3 | cut -d '-' -f 2  | cut -c 2-`

kernel_version=`extract-version zImage-dtb| awk 'NR == 1'`
echo "previous prebuilt commit = $previous_prebuilt_commit"
echo "latest prebuilt commit = $latest_prebuilt_commit"
echo "kernel_version from zimage  $kernel_version"

if [ $previous_prebuilt_commit = $latest_prebuilt_commit ]; then
  echo "No update in prebuilt kernel"
  rm -f .fetch_artifact2.dat
  rm -f zImage-dtb
  kernel_git_history="No Kernel Change"
else
  mv zImage-dtb kernel
  git add kernel
  rm -f .fetch_artifact2.dat
  cd -
  cd $kernel_home
  pwd
  kernel_git_history=`git log --oneline $previous_prebuilt_commit..$latest_prebuilt_commit`
  cd -
fi

if [ ! -z $audio_module_dir ] ||[ ! -z $wlan_module_dir ]; then
  /google/data/ro/projects/android/fetch_artifact --latest --kernel --branch $kernel_build_branch kernel-modules.tar.gz
  tar -xf kernel-modules.tar.gz  wlan.ko
  tar -xf kernel-modules.tar.gz  --wildcards --no-anchored 'audio*'
  rm -f  kernel-modules.tar.gz
  rm -f .fetch_artifact2.dat
fi

if [ ! -z $audio_module_dir ]; then
  # TODO: Check if there is no change
  cd $audio_module_dir
  audio_git_history=`git log -1 --oneline`
  cd -
fi

if [ ! -z $wlan_module_dir ]; then
  # TODO: Check if there is no change
  cd $wlan_module_dir
  wlan_git_history=`git log -1 --oneline`
  cd -
fi

cd $prebuilt_kernel_dir
if [ ! -z $audio_module_dir ] ||[ ! -z $wlan_module_dir ]; then
  git add *.ko
  git commit -m "$commit_msg" -m "audio: $audio_git_history" -m "wlan: $wlan_git_history"  -m "kernel:" -m "$kernel_git_history" -m "$kernel_version"
else
  git commit -m "$commit_msg" -m "$kernel_git_history" -m "$kernel_version"
fi

cd -
echo "You can now upload the the prebuilt kernel: "
echo "cd $prebuilt_kernel_dir"
echo "repo upload ."
