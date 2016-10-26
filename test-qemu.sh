#! /bin/bash -ex

print_help()
{
	cat <<EOF
Usage: test-qemu.sh [OPTION]... [--][CONFIG]...
	-h, --help		this help.
	-k, --keep		keep testing CONFIGs even if some of them fail.
	-s SCRIPT, --script SCRIPT
				use named expect script for testing.

	CONFIG			configuration to test. The name has a form PREFIX-MACHINE-CORE,
				where CORE is core variant (e.g. fsf or dc232b), MACHINE is QEMU
				machine name (e.g. sim or lx200).
EOF
}

declare -a pass_args

while : ; do
	case "$1" in
		-h|--help)
			print_help
			exit
			;;
		-k|--keep)
			keep=1
			shift
			;;
		-s|--script)
			expect_script="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			break
			;;
	esac
done

declare -A qemu qemu_args

QEMU_BASE=$(readlink -f qemu)

for QEMU_BIN in qemu-system-xtensa qemu-system-xtensaeb ; do
	for CORE in $("$QEMU_BASE/$QEMU_BIN" -cpu help | tail -n +2) ; do
		qemu["$CORE"]="$QEMU_BASE/$QEMU_BIN"
	done
done

qemu_args=(["sim"]="-semihosting -serial null"
           ["lx60"]="-serial mon:stdio -net tap,ifname=`cat interface`,script=no,downscript=no -net nic,model=open_eth"
           ["kc705"]="-serial mon:stdio -net tap,ifname=`cat interface`,script=no,downscript=no -net nic,model=open_eth -m 1G")

O_BASE=$(readlink -f builds)

for CONFIG in "$@" ; do
	O="$O_BASE/$CONFIG"
	CORE=${CONFIG/*-/}
	BASE_CONFIG=${CONFIG%-$CORE}
	MACHINE=${BASE_CONFIG/*-/}
	BASE_CONFIG=${BASE_CONFIG%-$MACHINE}
	EXPECT_DEFAULT=expect-${BASE_CONFIG/*-/}
	[ -f ${EXPECT_DEFAULT} ] || EXPECT_DEFAULT=expect-default
	expect -c "spawn \"${qemu[$CORE]}\" -cpu $CORE -M $MACHINE -monitor null -nographic ${qemu_args[$MACHINE]} -kernel \"$O/arch/xtensa/boot/Image.elf\"" \
		"${expect_script:-$EXPECT_DEFAULT}" || [ -n "$keep" ]
done
