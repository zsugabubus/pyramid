# To be implemented by you:
# pyramid_uid <target>: Return a stable, unique id of `target`.
# pyramid_recipe <target>: Run recipe of `target`.

pyramid_init() {
	PYRAMID_UID=$(pyramid_uid "$1")
	if test -z "${PYRAMID_LEVEL:-}"; then
		# Nice landscape. We are top of the pyramid.
		mkdir 2>&- -m755 "${PYRAMID_WORKDIR:=$PWD/.pyramid}" ||:
		export PYRAMID_WORKDIR
		mkfifo "$PYRAMID_WORKDIR/jobs"
		# TODO: It would be better to parse `$MAKEFLAGS`.
		exec 4<>"$PYRAMID_WORKDIR/jobs"
		unlink "$PYRAMID_WORKDIR/jobs"
		# https://www.gnu.org/software/make/manual/html_node/POSIX-Jobserver.html
		export MAKEFLAGS="--jobserver-auth=4,4${MAKEFLAGS:+ }${MAKEFLAGS:-}"
		for i in $(seq 1 ${PYRAMID_PARALLELISM:-1}); do
			echo
		done >&4
		mkdir -m755 "$PYRAMID_WORKDIR/$PYRAMID_UID"
	fi
	export PYRAMID_WORKDIR PYRAMID_LEVEL="$((${PYRAMID_LEVEL:-0} + 1))"

	# Is already running?
	if ! mkfifo -m700 "$PYRAMID_WORKDIR/$PYRAMID_UID/$PYRAMID_UID"; then
		exit 126
	fi
	trap pyramid_exit EXIT INT TERM

	read -r <&4 _
}

pyramid_spawn() {
	if mkdir 2>&- -m755 "$PYRAMID_WORKDIR/${PYRAMID_DEPUID:-$(pyramid_uid "$1")}"; then
		pyramid_recipe "$1"
	fi
}

pyramid_depend() {
	PYRAMID_DEPUID="$(pyramid_uid "$1")"
	until stderr=$(LC_ALL=C ln "$PYRAMID_WORKDIR/$PYRAMID_UID/$PYRAMID_UID" "$PYRAMID_WORKDIR/$PYRAMID_DEPUID/$PYRAMID_UID" 2>&1); do
		_=$?
		if test -n "${stderr#*: No such file or directory}"; then
			if test -z "${stderr#*: File exists}"; then
				break
			fi
			printf >&2 "%s" "$stderr"
			exit "$_"
		fi
		pyramid_spawn	"$1"
	done
	unset stderr
	unset PYRAMID_DEPUID
}

pyramid_join() {
	echo >&4

	if test $# -gt 0; then
		PYRAMID_DEPUID="$(pyramid_uid "$1")"
		IFS=' ' read -r <"$PYRAMID_WORKDIR/$PYRAMID_DEPUID/$PYRAMID_UID" pkg_status pkg_info
	else
		nlinks=$(stat -c%h "$PYRAMID_WORKDIR/$PYRAMID_UID/$PYRAMID_UID")
		while test "$nlinks" -gt 1; do
			IFS=' ' read -r <"$PYRAMID_WORKDIR/$PYRAMID_UID/$PYRAMID_UID" pkg_status pkg_info
			if test "$pkg_status" -ne 0; then
				return "$pkg_status"
			fi
			nlinks=$((nlinks - 1))
		done
	fi

	read -r <&4 _
}

pyramid_exit() {
	pyramid_join
	cd "$PYRAMID_WORKDIR"
	while ! rmdir "$PYRAMID_UID"; do
		for f in "$PYRAMID_UID"/*; do
			if test ! "$PYRAMID_UID/$PYRAMID_UID" = "$f"; then
				mv -Tf "$f" "$PYRAMID_UID/$PYRAMID_UID" &&
				echo >"$PYRAMID_UID/$PYRAMID_UID" "${1:-0}"
			fi
			unlink "$PYRAMID_UID/$PYRAMID_UID"
		done
	done 2>&-
	if test "$PYRAMID_LEVEL" -eq 0; then
		rmdir "$PYRAMID_WORKDIR"
	else
		echo >&4
	fi
	pyramid_exit() { :; }
}
# vi:ft=sh noet
