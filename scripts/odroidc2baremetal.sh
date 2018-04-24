#!/bin/bash

##
#
#	author:		David Loosli (dloosli)
#	license:	WTFPL (http://www.wtfpl.net)
#
#	This piece of code is distributed in the hope that it will
#	be useful, but WITHOUT ANY WARRANTY.
#
#	All bare metal applications running on the Odroid C2 Single
#	Board Computer need to be signed with the official software
#	provided by hardkernel and AMLogic. This script tries to
#	simplify this process by providing
#
#		(a) a setup option that creates a firmware directory
#		    and downloads all the required firmware provided
#			by hardkernel to sign bare metal applications for
#			the Odroid C2;
#
#		(b) a signing option that actually signs the bare
#			metal application;
#
#		(c) a flashing option that writes a binary file to
#			a FAT formatted SD Card or an eMMC module with
#			one (mountet) partition '/dev/sdx1'; ATTENTION
#			this option usually needs root privileges.
#
#
#	Requirements:	wget, umount, dd, sync, eject, dirname,
#					basename
#
#
#	Downloads the following files:
#					- fip_create (composition application)
#					- bl1.bin.hardkernel (first boot layer)
#					- bl2.package (second boot layer) 
#					- bl30.bin, bl301.bin, bl31.bin
#					  (third boot layer)
#					- aml_encrypt_gxb (signing application)
#
##

function usage {
	echo "usage: odroidc2baremetal [-s] --setup [-f dir] | --sign -i input [-o output] [-f dir]"
	echo "				| --flash -b bin -d dev [-f dir]| -h | --help"
	echo ""
	echo "	-s			silent (i.e. without any output), optional; can"
	echo "				be used with every option except -h and --help"
	echo ""
	echo "	--setup [-f dir]	creates a directory 'firmware' in the specified"
	echo "				directory and downloads all the binaries needed"
	echo "				for signing; if no directory is specified the"
	echo "				current execution path of the script is used"
	echo ""
	echo "	--sign			signs the specified bare metal binary with"
	echo ""
	echo "		-i		specifies the input binary file to be signed"
	echo "				(e.g. '/path/program.bin' for program.bin); if"
	echo "				only a name is given, the script tries to find"
	echo "				the file in the current directory"
	echo ""
	echo "		-o		specifies the name and the output path of the out-"
	echo "				put binary file (e.g. '/path/bootloader.bin' for"
	echo "				bootloader.bin); if no directory is specified the"
	echo "				current execution path of the script and the name"
	echo "				of the input file are used (overwriting possible!)"
	echo ""
	echo "		-f		specifies the path to the firmware directory (e.g."
	echo "				'/home/projects' for '/home/projects/firmware); if"
	echo "				no directory is specified the script tries to find"
	echo "				the firmware folder in the current execution path"
	echo "				of the script"
	echo ""
	echo "	--flash			writes the specified binary to the selected device"
	echo "				with"
	echo ""
	echo "		-b		specifies the binary file to be written to flash"
	echo "				(e.g. '/path/program.bin' for program.bin); if"
	echo "				only a name is given, the script tries to find"
	echo "				the file in the current directory"
	echo ""
	echo "		-d		specifies the device path of the SD Card or eMMC"
	echo "				module (e.g. /dev/sdb); the path can be found by"
	echo "				running the 'fdisk -l' command"
	echo ""
	echo "		-f		specifies the path to the firmware directory (e.g."
	echo "				'/home/projects' for '/home/projects/firmware); if"
	echo "				no directory is specified the script tries to find"
	echo "				the firmware folder in the current execution path"
	echo "				of the script "
	echo ""
	echo "	-h | --help		display usage info"
	echo ""
}

function check_command_result {
	if (( $1 != 0 )); then
		echo "external command failed with exit status $1"
		echo "script terminated with exit status $2"
		exit $2
	fi
}

function check_firmware {
	if [ -d $firmwaredir ]; then
		for f in "${firmwarefiles[@]}"; do
			if [ ! -f "$firmwaredir/$f" ]; then
				echo "Missing firmware binary $1 in $firmwaredir."
				echo "Please run the --setup option again for the"
				echo "specified firmware directory!"
				exit 1
			fi
		done
		return 0
	else
		echo "Specified firmware directory $firmwaredir does not exist!"
		exit 1
	fi
}


##
# setup functions
##
function create_firmwarepackage {
	echo "****************************************************************"
	echo "create and enter firmware directory.."
	mkdir firmware
	cd firmware
	echo "****************************************************************"
	echo "Downloading fip_create..."
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/fip/fip_create
	check_command_result $? 2
	echo "****************************************************************"
	echo "Downloading hardkernel boot layer binaries..."
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/sd_fuse/bl1.bin.hardkernel
	check_command_result $? 2
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/fip/gxb/bl2.package
	check_command_result $? 2
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/fip/gxb/bl30.bin
	check_command_result $? 2
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/fip/gxb/bl301.bin
	check_command_result $? 2
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/fip/gxb/bl31.bin
	check_command_result $? 2
	echo "****************************************************************"
	echo "Downloading AM Logic aml_encrypt_gbx..."
	wget https://github.com/hardkernel/u-boot/raw/odroidc2-v2015.01/fip/gxb/aml_encrypt_gxb
	check_command_result $? 2
	echo "****************************************************************"
	echo "make firmware applications executable..."
	cd ../
	chmod 775 ./firmware/aml_encrypt_gxb
	chmod 775 ./firmware/fip_create
	echo "****************************************************************"
	echo ""
	echo "Setup process successfully terminated!"
	echo ""
	echo "****************************************************************"
	return 0
}

function setup_firmware {
	if [[ $# == 1 ]]; then
		if [ ! -d "$1" ]; then
			echo "Specified path is not an existing directory!"
			exit 1
		fi
		builddir="$1"	
	fi
	
	if [ -d "$builddir/firmware" ]; then
		echo "There already exists a firmware directory in the"
		echo "specified build path. Please choose an other one"
		echo "or delete the old firmware folder!"
		exit 1
	fi
	
	cd $builddir
	eval create_firmwarepackage $silent
	cd $currentdir
	return 0
}


##
# sign functions
##
function sign_binary {
	echo "****************************************************************"
	echo "copy binary to firmware path..."
	cp $inputfilepath "./firmware/${inputfilename}"
	cd firmware
	echo "****************************************************************"
	echo "calling hardkernels fip create with third boot layer binaries..."
	./fip_create --bl30 bl30.bin --bl301 bl301.bin --bl31 bl31.bin --bl33 $inputfilename fip.bin && ./fip_create --dump fip.bin
	check_command_result $? 3
	echo "clean temporary files..."
	rm $inputfilename
	echo "****************************************************************"
	echo "assemble second and third boot layer..." 
	cat bl2.package fip.bin > "${outputfilename}_new.bin"
	echo "clean temporary files..."
	rm fip.bin
	echo "****************************************************************"
	echo "sign application with aml_encrypt_gxb..."
	./aml_encrypt_gxb --bootsig --input "${outputfilename}_new.bin" --output "${outputfilename}.img"
	check_command_result $? 3
	echo "clean temporary files..."
	rm "${outputfilename}_new.bin" "${outputfilename}.img.sd.bin" "${outputfilename}.img.usb.bl2" "${outputfilename}.img.usb.tpl"
	echo "****************************************************************"
	echo "dd signed image..."
	dd if="${outputfilename}.img" of="${outputfilename}.gxbb" bs=512 skip=96
	check_command_result $? 5
	echo "****************************************************************"
	echo "write outputfile..."
	cd ../
	mv "./firmware/${outputfilename}.gxbb" $outputfilepath
	echo "****************************************************************"
	echo "clean temporary files..."
	rm "./firmware/${outputfilename}.img"
	echo "****************************************************************"
	echo ""
	echo "Signing process successfully terminated!"
	echo ""
	echo "****************************************************************"
	return 0
}

function setup_sign {
	if [ "$inputfilepath" = "$inputfilename" ]; then
		inputfilepath="${currentdir}/${inputfilename}"
	fi
	
	if [ -z $outputfilename ]; then
		outputfilepath="${currentdir}/${inputfilename}"
		outputfilename=$inputfilename
	else
		if [ "$outputfilepath" = "$outputfilename" ]; then
			outputfilepath="${currentdir}/${outputfilename}"
		fi
	fi
	
	if [ ! -f $inputfilepath ]; then
		echo "Specified inputfile does not exist!"
		exit 1
	fi
	
	if [ ! -d $(dirname "${outputfilepath}") ]; then
		echo "Specified outputfile directory does not exist!"
		exit 1
	fi
	
	check_firmware
	eval sign_binary $silent
	return 0
}


##
# flash functions
##
function flash_binary {
	echo "****************************************************************"
	echo "unmount SD Card / eMMC module..."
	umount "${devicepath}1"
	check_command_result $? 4
	echo "****************************************************************"
	echo "writing first boot layer..."
	dd if="${firmwaredir}${odroidc2bl1}" of=$devicepath conv=fsync,notrunc bs=1 count=442
	check_command_result $? 5
	dd if="${firmwaredir}${odroidc2bl1}" of=$devicepath conv=fsync,notrunc bs=512 skip=1 seek=1
	check_command_result $? 5
	echo "****************************************************************"
	echo "writing bare metal binary..."
	dd if=$binaryfile of=$devicepath conv=fsync,notrunc bs=512 seek=97
	check_command_result $? 5
	echo "****************************************************************"
	echo "sync..."
	sync
	echo "****************************************************************"
	echo "eject device..."
	eject $devicepath
	echo "****************************************************************"
	echo ""
	echo "Flashing process successfully terminated!"
	echo ""
	echo "****************************************************************"
	return 0
}

function setup_flash {	
	if [ ! -f $binaryfile ]; then
		echo "Specified binary file to write to SD Card / eMMC does not exist!"
		exit 1
	fi
	
	if [ ! -e $devicepath ]; then
		echo "Specified device path does no exist!"
		exit 1
	fi
	
	if [ ! -f "${firmwaredir}${odroidc2bl1}" ]; then
		echo "Can not find boot level 1 binary in firmware path!"
		exit 1
	fi
	
	check_firmware
	eval flash_binary $silent
	return 0
}


##
# script main
##
declare -a firmwarefiles=("aml_encrypt_gxb" "bl1.bin.hardkernel" "bl2.package" "bl30.bin" "bl301.bin" "bl31.bin" "fip_create")
silent=""

builddir="./"
currentdir="${PWD}"
firmwaredir="./firmware"

inputfilepath=""
inputfilename=""
outputfilepath=""
outputfilename=""

binaryfile=""
devicepath=""
odroidc2bl1="/bl1.bin.hardkernel"


if [[ $# == 0 || $# > 8 ]]; then
	echo "Illegal number of options. Please try again!"
	echo ""
	usage
	exit 1
fi

while test $# -gt 0; do
	case "$1" in
	
		-h|--help)
			usage
			exit 0
			;;
		
		-s)
			silent="&>/dev/null"
			shift
			;;
		
		--setup*)
			case "$#" in
				1)
					setup_firmware
					exit 0
					;;
				3)
					setup_firmware $3
					exit 0
					;;
				*)
					echo "Unknown options for --setup. Please try again!"
					echo ""
					usage
					exit 1
					;;
			esac
			;;
			
		--sign*)
			shift
			while test $# -gt 0; do
				case "$1" in
					-i)
						shift
						inputfilepath=$1
						inputfilename=$(basename $1)
						shift
						;;
					-o)
						shift
						outputfilepath=$1
						outputfilename=$(basename $1)
						shift
						;;
					-f)
						shift
						firmwaredir="$1/firmware"
						shift
						;;
					*)
						echo "Unknown options for --sign. Please try again!"
						echo ""
						usage
						exit 1
						;;
				esac
			done
			setup_sign
			;;
			
		--flash*)
			shift
			while test $# -gt 0; do
				case "$1" in
					-b)
						shift
						binaryfile=$1
						shift
						;;
					-d)
						shift
						devicepath=$1
						shift
						;;
					-f)
						shift
						firmwaredir="$1/firmware"
						shift
						;;
					*)
						echo "Unknown options for --sign. Please try again!"
						echo ""
						usage
						exit 1
						;;
				esac
			done
			setup_flash
			;;
			
		*)
			echo "Unknown option - please try again!"
			echo ""
			usage
			exit 1
			;;
	esac
done


# end of script
