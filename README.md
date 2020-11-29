ALMSI
=====
**Description:** This bash script installs Arch Linux in a remote system

**Copyright:** 2020 Fabio Castelli <muflone(at)muflone.com>

**License:** GPL-3+

**Source code:** https://github.com/muflone/ALMSI

**Documentation:** http://www.muflone.com/almsi

Information
-----------

This script is used to install Arch Linux in a running GNU/Linux installation.

WARNING !!!
THIS SCRIPT WILL WIPE EVERY DATA IN THE REMOTE SYSTEM,
REINSTALLING ARCH LINUX UPON YOUR CURRENTLY INSTALLED OS.

It uses the external script vps2arch ( https://github.com/drizzt/vps2arch ) to
execute the real installation.

The rest of te process setup the network and the SSH keys.

System Requirements
-------------------

* Bash

Usage
-----

    sh ALMSI.sh <ip address> <hostname> 1
