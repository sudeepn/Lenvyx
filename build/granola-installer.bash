#!/bin/bash

# COPYRIGHT (c) 2009, MiserWare, Inc. ALL RIGHTS RESERVED
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of MiserWare, Inc. nor the names of its contributors may
#   be used to endorse or promote products derived from this software without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

if [ `id -u` != "0" ]; then
    echo "Sorry, but this script must be run as the root user."
    exit 1
fi

BASE_URL=https://download.miserware.com
REPO_URL=$BASE_URL/linux
SHARE_PATH=/usr/share/miserware-repo

# Hardcode paths
RPM=/bin/rpm
MKTEMP=/bin/mktemp
WGET=/usr/bin/wget
DPKG=/usr/bin/dpkg
RM=/bin/rm
APT_GET=/usr/bin/apt-get
APT_CACHE=/usr/bin/apt-cache
MKDIR=/bin/mkdir
PERL=/usr/bin/perl
RUG=/usr/bin/rug
UP2DATE=/usr/bin/up2date
YUM=/usr/bin/yum
DPKG_QUERY=/usr/bin/dpkg-query
GREP=/bin/grep
CHKCONFIG=/sbin/chkconfig
SERVICE=/sbin/service

# Detect distribution and release
DISTRIBUTION=unsupported
if [ -f /etc/debian_version ]; then
    if [ -f /etc/lsb-release ]; then
        # 95% chance this is Ubuntu, but the file needs to be sourced to be sure
        . /etc/lsb-release
        if [ "$DISTRIB_ID" = "Ubuntu" ]; then
            # MiserWare doesn't support all versions of Ubuntu
            case $DISTRIB_CODENAME in
                hardy|lucid|natty|oneiric|precise)
                    DISTRIBUTION=ubuntu
                    CODENAME=$DISTRIB_CODENAME
                ;;
            esac
        fi
    else
        # Determine which (supported) version of Debian this is
        case $(cat /etc/debian_version) in
            6.0*)
                # Debian 6.0 (squeeze)
                DISTRIBUTION=debian
                CODENAME=squeeze
                ;;
        esac
    fi
elif [ -x $RPM ]; then
    # Figure out which RPM-based distribution we are
    RPMQ="$RPM --qf %{name}-%{version}-%{release}\n -q"
    if $RPMQ --whatprovides redhat-release >/dev/null 2>&1; then
        # RHEL or Fedora
        RELEASE_RPM=$($RPMQ --whatprovides redhat-release 2>/dev/null | tail -n1)
        VERSION=$($RPM -q --qf "%{version}\n" $RELEASE_RPM)
        # Strip extraneous stuff
        VERSION=${VERSION%%[.a-zA-Z]*}

        case $RELEASE_RPM in
            fedora-release*)
                VERSION=$($RPM --eval "%{fedora}")
                # MiserWare doesn't support all versions of Fedora
                if [ $VERSION -ge 15 -a $VERSION -le 16 ]; then
                    DISTRIBUTION=fedora
                fi
                ;;
            redhat-release*)
                # MiserWare doesn't support all versions of RHEL
                if [ $VERSION = 5 -o $VERSION = 6 ]; then
                    DISTRIBUTION=rhel
                fi
                ;;
        esac
    fi
fi

if [ $DISTRIBUTION = unsupported ]; then
    echo "Sorry, but you appear to be running an unsupported distribution or version."
    exit 1
fi

# Install the repo files
case $DISTRIBUTION in
    ubuntu|debian)
        if ! ( $DPKG_QUERY -l apt-transport-https | grep -q ^ii ); then
            echo
            echo "The MiserWare software repository requires the APT HTTPS transport, but it"
            echo "does not appear to be installed.  This script can attempt to install it"
            echo "automatically by running the following command:"
            echo
            echo "$APT_GET -y install apt-transport-https"
            echo
            echo "Would you like this script to attempt to install the APT HTTPS transport?"
            echo "If you answer \"no\", you will have to install it yourself before this"
            echo "script can continue."
            echo
            echo -n "Install APT HTTPS transport automatically? (yes/NO) "
            read ANSWER
            case $ANSWER in
                yes|Yes|YES)
                    $APT_GET -y install apt-transport-https
                    if [ $? -ne 0 ]; then
                        echo
                        echo "Sorry, this script couldn't automatically install the APT HTTPS transport."
                        echo "The most common reason for this is the system APT sources are out of date."
                        echo "Please e-mail MiserWare support <support@miserware.com> if you require assistance."
                        echo
                        exit 2
                    fi
                    ;;
                *)
                    echo
                    echo "Aborting installation because the APT HTTPS transport isn't installed and the user"
                    echo "declined to allow the script to attept to install it.  Please install it manually."
                    echo "Please e-mail MiserWare support <support@miserware.com> if you require assistance."
                    echo
                    exit 3
                    ;;
            esac
        fi
        DEB_PATH=$($MKTEMP /tmp/repo-deb-$$-XXXXXX)
        trap "$RM -f $DEB_PATH" EXIT HUP QUIT TERM
        DEB_URL=$REPO_URL/deb/$DISTRIBUTION/$CODENAME/miserware-repo-latest.deb
        $WGET -O $DEB_PATH -q $DEB_URL
        if [ $? -ne 0 ]; then
            echo "Failed to download repo deb: $DEB_URL"
            exit 1
        fi
        echo "Installing repo deb: $DEB_URL"
        $DPKG -i -G $DEB_PATH
        SUCCESS=$?
        $RM -f $DEB_PATH
        trap - EXIT HUP QUIT TERM
        if [ $SUCCESS -ne 0 ]; then
            echo "Failed to install the repo package."
            exit 1
        fi
        ;;
    fedora|rhel)
        # RHEL 4 ships cpuspeed as part of kernel-utils rather than its own
        # package, so MicroMiser and ServerMiser can't conflict with it.
        # Check if cpuspeed is enabled, and if it is, offer to turn it off.
        # If the user declines to allow the script to turn cpuspeed off,
        # explain how to do it manually but continue anyway.
        if [ "$DISTRIBUTION" = "rhel" -a $VERSION -eq 4 ] && \
          $CHKCONFIG --list cpuspeed | sed -e "s/1:on//" | grep -q on; then
            echo "The script has noticed that cpuspeed, another userland cpufreq governor that"
            echo "will interfere with MiserWare software, is enabled.  It must be disabled for"
            echo "MiserWare software to function properly.  The script can disable cpuspeed for"
            echo "you, or it can explain how to disable it yourself.  The script will continue"
            echo "regardless, and if you choose to disable cpuspeed yourself the script will"
            echo "remind you to disable it at the end."
            while [ "$CHOICE" != "yes" -a "$CHOICE" != "no" ]; do
                echo
                echo -n "Would you like the script to disable cpuspeed for you? (YES/no) "
                read CHOICE
                CHOICE=$(echo $CHOICE | tr '[:upper:]' '[:lower:]')
            done
            echo
            if [ "$CHOICE" = "yes" ]; then
                $CHKCONFIG cpuspeed off
                $SERVICE cpuspeed stop
                echo "cpuspeed has been disabled."
            else
                echo "To disable cpuspeed yourself, please run the following commands as the root"
                echo "user:"
                echo
                echo "$CHKCONFIG cpuspeed off"
                echo "$SERVICE cpuspeed stop"
                CPUSPEED_REMINDER=yes
            fi
            echo
        fi
        # Import the RPM GPG key first if necessary
        if ! $RPM -q gpg-pubkey-11a8389c-4a54d2a9 >/dev/null; then
            KEY_PATH=$($MKTEMP /tmp/repo-key-$$-XXXXXX)
            trap "$RM -f $KEY_PATH" EXIT HUP QUIT TERM
            KEY_URL=$BASE_URL/RPM-GPG-KEY-MiserWare
            $WGET -O $KEY_PATH -q $KEY_URL
            if [ $? -ne 0 ]; then
                echo "Failed to download the RPM GPG key: $KEY_URL"
                exit 1
            fi
            echo "Installing the RPM GPG key: $KEY_URL"
            $RPM --import $KEY_PATH
            $RM -f $KEY_PATH
            trap - EXIT HUP QUIT TERM
        fi
        RPM_PATH=$($MKTEMP /tmp/repo-rpm-$$-XXXXXX)
        trap "$RM -f $RPM_PATH" EXIT HUP QUIT TERM
        RPM_URL=$REPO_URL/rpm/$DISTRIBUTION/$VERSION/noarch/miserware-repo-latest.noarch.rpm
        $WGET -O $RPM_PATH -q $RPM_URL
        if [ $? -ne 0 ]; then
            echo "Failed to download the repo RPM: $RPM_URL"
            exit 1
        fi
        echo "Installing repo RPM: $RPM_URL"
        $RPM -U --replacepkgs $RPM_PATH
        SUCCESS=$?
        $RM -f $RPM_PATH
        trap - EXIT HUP QUIT TERM
        if [ $SUCCESS -ne 0 ]; then
            echo "Failed to install the repo package."
            exit 1
        fi
        ;;
esac

echo
echo "Congratulations!  You're ready to install your MiserWare software!"
if [ -n "$CPUSPEED_REMINDER" ]; then
    echo
    echo "Please remember to disable cpuspeed by running the following commands as the"
    echo "root user:"
    echo
    echo "$CHKCONFIG cpuspeed off"
    echo "$SERVICE cpuspeed stop"
fi
echo
echo "You can search which software is available to you by running the following"
echo "command(s):"
echo
case $DISTRIBUTION in
    ubuntu|debian)
        echo "$APT_GET update"
        echo "$APT_CACHE search MiserWare "
        ;;
    fedora|rhel)
        if [ $DISTRIBUTION = rhel -a $VERSION = 4 -a ! -x $YUM ]; then
            echo "$UP2DATE --showall | grep miser"
        else
            echo "$YUM search MiserWare"
        fi
        ;;
esac
echo




