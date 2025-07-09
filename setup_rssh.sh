#!/usr/bin/env bash
readonly username_flag="--username"
readonly jail_flag="--jail"
readonly help_flag="--help"
readonly readonly_flag="--read-only"
readonly clean_flag="--clean"
declare -A ARG_SHORT
ARG_SHORT["$username_flag"]="-u"
ARG_SHORT["$jail_flag"]="-j"
ARG_SHORT["$help_flag"]="-h"
ARG_SHORT["$readonly_flag"]="-r"
ARG_SHORT["$clean_flag"]="-c"
declare -A ARG_HELP
ARG_HELP["$username_flag"]="Username of user that will be acessible by rssh."
ARG_HELP["$jail_flag"]="Path to chroot jail for rssh."
ARG_HELP["$readonly_flag"]="Make new user's home directory read-only."
ARG_HELP["$clean_flag"]="Clean before starting."
declare -A METAVAR
for flag in "${!ARG_SHORT[@]}"; do
    mv="${flag//[^A-Za-z]/}"   
    METAVAR["$flag"]="${mv^^}"
done
USERNAME=ngs
JAIL=/ngs
do_help=false
make_readonly=false
clean=false
while [ "$#" -gt 0 ]; do
    case "$1" in
	"$username_flag" | "${ARG_SHORT[$username_flag]}")
	    shift;
	    USERNAME="$1"
	    ;;
	"$jail_flag" | "${ARG_SHORT[$jail_flag]}")
	    shift;
	    JAIL="$1"
	    ;;
	"$help_flag" | "${ARG_SHORT[$help_flag]}")
	    shift;
	    do_help=true
	    ;;
	"$readonly_flag" | "${ARG_SHORT[$readonly_flag]}")
	    make_readonly=true
	    ;;
	"$clean_flag" | "${ARG_SHORT[$clean_flag]}")
	    clean=true
	    ;;
    esac
    shift
done
if [ "$do_help" = true ]; then
    # Print help.
    printf "Usage: $0 "
    longest=0
    for arg in "${!ARG_HELP[@]}"; do
	if [[ -v "ARG_SHORT[$arg]" ]]; then
	    arg_str="${ARG_SHORT[$arg]}"
	else	    
	    arg_str="$arg"
	fi
	if [[ -v "METAVAR[$arg]" ]]; then
	    arg_str="$arg_str ${METAVAR[$arg]}"
	fi
	arg_str="[$arg_str]"
	printf "%s " "$arg_str"
	len="${#arg}"
	if [[ -v "ARG_SHORT[$arg]" ]]; then
	    len=$((len + "${#ARG_SHORT[$arg]}" + 2))
	fi
	if [ "$len" -gt "$longest" ]; then
	    longest="$len"
	fi
    done
    #printf "DIR [ ..."
    longest=$((longest+3))
    echo
    echo
    echo "optional arguments:"
    for arg in "${!ARG_HELP[@]}"; do

	    arg_str="$arg"
	    if [[ -v "ARG_SHORT[$arg]" ]]; then
		arg_str="${ARG_SHORT[$arg]}, $arg_str"
	    fi
	    printf "  %-${longest}s" "$arg_str"
	    echo "${ARG_HELP[$arg]}"

    done
    exit 0
fi
if [ "$clean" = true ]; then
    sudo deluser --remove-home "$USERNAME"
    sudo delgroup "$USERNAME"
    rm "rssh.tar.gz"
    rm -rf "rssh-2.3.4"
fi
set -x
set -e
sudo useradd --system --no-create-home "$USERNAME"
>&2 echo "Set a password for $USERNAME:"
sudo passwd "$USERNAME"
wget "http://prdownloads.sourceforge.net/rssh/rssh-2.3.4.tar.gz?download"
mv rssh-2.3.4.tar.gz?download rssh.tar.gz
tar xzvf rssh.tar.gz
cd rssh-2.3.4
patch -s -p1 < ../rssh_patch.diff
./configure
make
sudo make install
patch mkchroot.sh ../mkchroot.diff
sudo ./mkchroot.sh "$JAIL"
cd ..
export BASE="$JAIL"
sudo mkdir  "$JAIL/bin"
sudo mkdir -p "$JAIL/usr/bin"
sudo ./l2chroot "$(which rssh)"
sudo ./l2chroot "$(which scp)"
sudo ./l2chroot /usr/local/libexec/rssh_chroot_helper
sudo ./l2chroot /usr/lib/openssh/sftp-server
sudo cp /bin/bash "$JAIL/bin"
sudo cp /bin/sh "$JAIL/bin"
sudo ./l2chroot /bin/bash
sudo ./l2chroot /bin/sh
sudo cp -r /etc/ld.so.conf.d "$JAIL/etc"
sudo cp /etc/nsswitch.conf "$JAIL/etc"
sudo cp /etc/group "$JAIL/etc"
sudo cp /etc/hosts "$JAIL/etc"
sudo cp /etc/resolv.conf "$JAIL/etc"
sudo cp /usr/bin/sftp "$JAIL/usr/bin/sftp"
sudo ./l2chroot /usr/bin/sftp
sudo mkdir -p "$JAIL/home/$USERNAME"
sudo chown "$USERNAME" "$JAIL/home/$USERNAME"
#sudo chmod u-w "$JAIL/home/$USERNAME"
if [ "$make_readonly" = true ]; then
    sudo chmod u-w "$JAIL/home/$USERNAME"
fi
sudo cp /bin/mknod "$JAIL/bin"
sudo ./l2chroot /bin/mknod
sudo chroot "$JAIL" mknod /dev/null c 1 3
sudo chmod a+rw "$JAIL/dev/null"
sudo tee /usr/local/etc/rssh.conf <<EOF
allowscp
chrootpath = $JAIL
EOF
sudo chsh -s "$(which rssh)" "$USERNAME"
sudo usermod -d "$JAIL/home/$USERNAME" "$USERNAME"
sudo getent passwd "$USERNAME" | sudo tee "$JAIL/etc/passwd" > /dev/null
sudo usermod -P "$JAIL" -d "$/home/$USERNAME" "$USERNAME"
