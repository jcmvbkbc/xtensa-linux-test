#! /bin/bash -ex

print_help()
{
	cat <<EOF
Usage: kill-qemu.sh -h	
       kill-qemu.sh RUN_CONFIG
	-h, --help		this help.

	RUN_CONFIG		configuration to run. It's the path to a directory with config file
				and dhcpd.conf, PID file is created there when the config is running.
EOF
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

kill $(cat ${RUN_CONFIG}/pid)
rm -f ${RUN_CONFIG}/pid
