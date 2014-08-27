#! /bin/bash -ex

print_help()
{
	cat <<EOF
Usage: build.sh [OPTION]... [VAR=VAL]... [--][CONFIG]...
	-f, --force		force kernel rebuild.
	-h, --help		this help.
	-i TEMPLATE, --interactive TEMPLATE
				make menuconfig using TEMPLATE as initial configuration
				(may be file name or predefined kernel config name).
				CONFIGs will be updated.
	-k, --keep		keep building CONFIGs even if some of them fail.
	-n TEMPLATE, --non-interactive TEMPLATE
				configure using TEMPLATE as initial configuration
				(may be file name or predefined kernel config name).
				CONFIGs will be updated.
	-r, --reconfigure	run interactive configure for each CONFIG

	VAR=VAL			pass build modifiers to the kernel make (e.g. V=1).
				If VAR is MAKE_ARGS, VALs are accumulated and passed
				to the kernel make (e.g. MAKE_ARGS="-k -j").

	CONFIG			configuration to build. The name has a form PREFIX-CORE,
				where CORE is core variant (e.g. fsf or dc232b).
EOF
}

declare -a make_args pass_args

while : ; do
	case "$1" in
		-f|--force)
			force=1
			shift
			;;
		-h|--help)
			print_help
			exit
			;;
		-i|--interactive)
			template="$2"
			interactive=1
			shift 2
			;;
		-k|--keep)
			keep=1
			shift
			;;
		-n|--non-interactive)
			template="$2"
			shift 2
			;;
		-r|--reconfigure)
			reconfigure=1
			interactive=1
			shift
			;;
		MAKE_ARGS=*)
			make_args+=(${1#MAKE_ARGS=})
			shift
			;;
		*=*)
			pass_args+=("$1")
			shift
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

export ARCH=xtensa
SRC=$(readlink -f source)
O_BASE=$(readlink -f builds)
LOG_BASE=$(readlink -f logs)
mkdir -p "$O_BASE"
mkdir -p "$LOG_BASE"

for CONFIG in "$@" ; do
	rm -f "$LOG_BASE"/{BUILD,OK,FAIL}"-$CONFIG"
done

for CONFIG in "$@" ; do
	O="$O_BASE/$CONFIG"
	CORE=${CONFIG/*-/}
	export CROSS_COMPILE=$(readlink -f "toolchains/build-$CORE/root/bin/xtensa-$CORE-elf-")
	[ -z "$force" ] || rm -rf "$O"
	mkdir -p "$O"
	[ -n "$reconfigure" ] && template="$CONFIG"
	if [ -n "$template" ] ; then
		[ -f "$template" ] && cp "$template" "$O/.config" || make -C "$SRC" O="$O" "${pass_args[@]}" "$template"
		[ -n "$interactive" ] && make -C "$SRC" O="$O" menuconfig
		cp "$O/.config" "$CONFIG"
	else
		[ -f "$O/.config" ] || cp "$CONFIG" "$O/.config"
		make -C "$SRC" O="$O" oldconfig
	fi
	make -C "$SRC" ${make_args[@]} O="$O" "${pass_args[@]}" all 2>&1 | tee "$O/build.log" "$LOG_BASE/BUILD-$CONFIG"
	RC=${PIPESTATUS[0]}
	if [ $RC = 0 ] ; then
		mv "$LOG_BASE/BUILD-$CONFIG" "$LOG_BASE/OK-$CONFIG"
	else
		mv "$LOG_BASE/BUILD-$CONFIG" "$LOG_BASE/FAIL-$CONFIG"
		[ -n "$keep" ] || exit $RC
	fi
done
