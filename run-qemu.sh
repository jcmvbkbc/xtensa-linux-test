#! /bin/bash -ex

print_help()
{
	cat <<EOF
Usage: run-qemu.sh -h
       run-qemu.sh RUN_CONFIG [KERNEL_CONFIG] [-- [QEMU options]]
	-h, --help		this help.

	RUN_CONFIG		configuration to run. It's the path to a directory with config file
				and dhcpd.conf, PID file is created there when the config is running
				(used by the corresponding kill script).

	KERNEL_CONFIG		kernel configuration to use. It's a name under build/ subdirectory
				where the kernel is built and also it's interpreted as *-MACHINE-CORE
				to select QEMU machine and CPU.
EOF
}

subst()
{
	eval "cat <<EOF
`cat \"$1\"`
EOF"
}

cleanup()
{
	[ $1 -gt 0 ] && sudo kill `cat ${RUN_CONFIG}/dhcpd.pid`
	tunctl -d ${IF}
}

case "$1" in
	-h|--help)
		print_help
		exit
		;;
	*)
		RUN_CONFIG="$1"
		shift
		;;
esac

. ${RUN_CONFIG}/config

if [ $# -gt 0 ] ; then
	case "$1" in
		--)
			shift
			;;
		*)
			CONFIG="$1"
			shift
			;;
	esac
fi

if [ -n "${IF_CONFIG}" ] ; then
	IF=$(sudo tunctl -u $USER -b)
	trap "cleanup 0" EXIT
	sudo ifconfig ${IF} ${IF_CONFIG}
	[ -f ${RUN_CONFIG}/dhcpd.conf.in ] && subst ${RUN_CONFIG}/dhcpd.conf.in > ${RUN_CONFIG}/dhcpd.conf
	rm -f ${RUN_CONFIG}/dhcpd.leases && touch ${RUN_CONFIG}/dhcpd.leases
	sudo dhcpd -cf ${RUN_CONFIG}/dhcpd.conf -lf ${RUN_CONFIG}/dhcpd.leases -pf ${RUN_CONFIG}/dhcpd.pid ${IF}
	trap "cleanup 1" EXIT
fi

declare -A qemu qemu_args core_map

QEMU_BASE=$(readlink -f qemu)

core_map=(["test_kc705"]=test_kc705_ca
	  ["test_kc705_hifi"]=test_kc705_ca)

for QEMU_BIN in qemu-system-xtensa qemu-system-xtensaeb ; do
	for CORE in $("$QEMU_BASE/$QEMU_BIN" -cpu help | tail -n +2) ; do
		qemu["$CORE"]="$QEMU_BASE/$QEMU_BIN"
	done
done

qemu_args=(["sim"]="-semihosting -serial null"
	   ["lx60"]="-serial mon:stdio -net tap,ifname=${IF},script=no,downscript=no -net nic,model=open_eth"
	   ["kc705"]="-serial mon:stdio -net tap,ifname=${IF},script=no,downscript=no -net nic,model=open_eth -m 1G")

O_BASE=$(readlink -f builds)

O="$O_BASE/$CONFIG"
CORE=${CONFIG/*-/}
BASE_CONFIG=${CONFIG%-$CORE}
[ -z ${core_map[${CORE}]} ] || CORE=${core_map[${CORE}]}
MACHINE=${BASE_CONFIG/*-/}
BASE_CONFIG=${BASE_CONFIG%-$MACHINE}
${qemu[$CORE]} -cpu $CORE -M $MACHINE -pidfile ${RUN_CONFIG}/pid \
	-monitor null -nographic ${qemu_args[$MACHINE]} \
	-kernel "$O/arch/xtensa/boot/${KERNEL_IMAGE:-Image.elf}" "$@"

rm -f ${RUN_CONFIG}/pid
