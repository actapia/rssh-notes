**Warning: rssh is currently unmaintained and is known to have a [security
vulernability](https://www.holidayhackchallenge.com/2018/winners/esnet_hhc18/)
that allows an attacker to access a shell on the SSH server even when login is
prohibited by rssh. This repository conatins a patch (provided by
[Russ Allbery](https://sourceforge.net/p/rssh/mailman/message/36530715/)) that
might fix the discovered vulnerability, but this has not been tested
carefully. If you are using `rssh` for security, please look elsewhere!**

The following steps describe (roughly) how to set up `rssh` on Ubuntu 18.04,
20.04, or 22.04.  The instructions assume you want a user called "ngs" that can
user scp but not ssh.  The user is chrooted to a jail at `/ngs`.

Create a system user `ngs` (or whatever name you like) with no password.

```bash
sudo useradd --system --no-create-home ngs
```

Change the password for the `ngs` user to something strong (temporarily).

```bash
sudo passwd ngs
```

Download `rssh` from http://www.pizzashack.org/rssh/

```bash
wget http://prdownloads.sourceforge.net/rssh/rssh-2.3.4.tar.gz?download
```

Move

```bash
mv rssh-2.3.4.tar.gz?download rssh.tar.gz
```

Extract

```bash
tar xzvf rssh.tar.gz
```

Change to `rssh-*` dir

```bash
cd rssh-2.3.4
```

Apply the patch (from Russ Allbery).

```bash
patch -s -p1 < ../rssh-notes/rssh_patch.diff
```

Configure

```bash
./configure
```

Compile

```bash
make
```

Install

```bash
sudo make install
```

Apply the patch to `mkchroot.sh`

```bash
patch mkchroot.sh ../rssh-notes/mkchroot.diff
```

Use `mkchroot.sh` to create the initial jail.

```bash
sudo ./mkchroot.sh /ngs
```

`cd` to the `rssh-notes` directory

```bash
cd ../rssh-notes
```

If your chroot jail will not be at `/ngs`, make sure to change it in the
l2chroot script!

Make `bin` directories

```bash
sudo mkdir /ngs/bin
sudo mkdir /ngs/usr
sudo mkdir /ngs/usr/bin
```

Run the `l2chroot` script for our programs.

```bash
sudo ./l2chroot "$(which rssh)"
sudo ./l2chroot "$(which scp)"
sudo ./l2chroot /usr/local/libexec/rssh_chroot_helper
sudo ./l2chroot /usr/lib/openssh/sftp-server
```

(Optional?) Add some programs to the jail to make testing less painful.

```bash
sudo cp /bin/bash /ngs/bin
sudo cp /bin/sh /ngs/bin
```

(Optional?) Run `l2chroot` for the new programs.

```bash
sudo ./l2chroot /bin/bash
sudo ./l2chroot /bin/sh
```

Add some more files to the jail.

```bash
sudo cp -r /etc/ld.so.conf.d /ngs/etc
sudo cp /etc/nsswitch.conf /ngs/etc
sudo cp /etc/group /ngs/etc
sudo cp /etc/hosts /ngs/etc
sudo cp /etc/resolv.conf /ngs/etc
```

Add `sftp` to the jail.

```bash
sudo cp /usr/bin/sftp /ngs/usr/bin/sftp
```

Run `l2chroot` for `sftp`.

```bash
sudo ./l2chroot /usr/bin/sftp
```

Create the home directory for `ngs`

```bash
sudo mkdir /ngs/home/
sudo mkdir /ngs/home/ngs
```

Change ownership for `ngs` home directory

```bash
sudo chown ngs /ngs/home/ngs
```

Change permissions for `ngs` home directory (if desired)

```bash
sudo chmod u-w /ngs/home/ngs
```

Add `mknod` to the jail

```bash
sudo cp /bin/mknod /ngs/bin
```

`l2chroot` it

```bash
sudo ./l2chroot /bin/mknod
```

Chroot into the jail

```bash
sudo chroot /ngs
```

Create `/dev/null`

```bash
mknod /dev/null c 1 3
```

Exit jail

```bash
exit
```

Change permissions on jail `/dev/null`

```bash
sudo chmod a+rw /ngs/dev/null
```

Modify the `/usr/local/etc/rssh.conf` to

```bash
allowscp
chrootpath = /ngs/
```
      
Change the shell of the `ngs` user.

```bash
sudo chsh -s "$(which rssh)" ngs
```

Set the home directory of the `ngs` user.

```bash
sudo usermod -d /ngs/home/ngs ngs
```

Add the `passwd` file to the jail

```bash
sudo tail -n 1 /etc/passwd | sudo tee /ngs/etc/passwd
```

Edit the `/ngs/etc/passwd` file to have home directory

```text
/home/ngs
```

The directory structure of the jail should look something like this:

```text
.
├── bin
│   ├── bash
│   ├── mknod
│   ├── rssh -> /ngs/usr/local/bin/rssh
│   ├── scp -> /ngs/usr/bin/scp
│   ├── sftp -> /ngs/usr/bin/sftp
│   └── sh
├── dev
│   └── null
├── etc
│   ├── #passwd#
│   ├── group
│   ├── hosts
│   ├── ld.so.cache
│   ├── ld.so.cache.d
│   ├── ld.so.conf
│   ├── ld.so.conf.d
│   │   ├── fakeroot-x86_64-linux-gnu.conf
│   │   ├── libc.conf
│   │   └── x86_64-linux-gnu.conf
│   ├── nsswitch.conf
│   ├── passwd
│   ├── passwd~
│   └── resolv.conf
├── home
│   └── ngs
│       └── Desktop
│           └── hw1.txt
├── lib
│   └── x86_64-linux-gnu
│       ├── libbsd.so.0
│       ├── libc.so.6
│       ├── libdl.so.2
│       ├── libnss_compat-2.27.so
│       ├── libnss_compat.so.2
│       ├── libnss_files-2.27.so
│       ├── libnss_files.so.2 -> libnss_files-2.27.so
│       ├── libpcre.so.3
│       ├── libpthread.so.0
│       ├── librt.so.1
│       ├── libselinux.so.1
│       └── libtinfo.so.5
├── lib64
│   └── ld-linux-x86-64.so.2
└── usr
    ├── bin
    │   ├── scp
    │   └── sftp
    ├── lib
    │   ├── openssh
    │   │   └── sftp-server
    │   └── x86_64-linux-gnu
    │       └── libedit.so.2
    └── local
        ├── bin
        │   └── rssh
        ├── lib
        │   └── rssh_chroot_helper -> /ngs/usr/local/libexec/rssh_chroot_helper
        └── libexec
            └── rssh_chroot_helper
```

The `/etc/passwd` file should end like this:

```text
ngs:x:113:65534::/ngs/home/ngs:/usr/local/bin/rssh
```

The `/ngs/etc/passwd` file should end like this:

```text
ngs:x:113:65534::/home/ngs:/usr/local/bin/rssh
```
