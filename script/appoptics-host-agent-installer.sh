#!/usr/bin/env bash

###############################################################################
# FILE:         appoptics-host-agent-installer.sh
# VERSION:      1.0.0
# DESCRIPTION:  Agent installation script for multiple OS/Distributions
# BUGS:         support@appoptics.com
# COPYRIGHT:    (c) 2017 Librato
# LICENSE:      Apache 2.0; http://www.apache.org/licenses/LICENSE-2.0
# ORGANIZATION: http://appoptics.com
#
# NOTICE: Some code borrowed from bootstrap-salt.sh (License: Apache 2.0)
#         https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh
###############################################################################
_SD_SCRIPT_VERSION="1.0.0"

APPOPTICS_TOKEN=${APPOPTICS_TOKEN:-""}
APPOPTICS_URL=${APPOPTICS_URL:-"https://api.appoptics.com/v1/measurements"}
DEFAULT_INSTALL_DIR=/opt/appoptics
INSTALL_DIR=${INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}
APPOPTICS_CONF="${INSTALL_DIR}/etc/config.yaml"
SNAP_SERVICE_NAME=appoptics-snapteld
AGENT_DISPLAY_NAME="AppOptics Host Agent"
PACKAGE_NAME=appoptics-snaptel
if [ $AO_ENV -eq 'staging' ]
then
  PACKAGECLOUD_REPO=appoptics-snap-staging
else
  PACKAGECLOUD_REPO=appoptics-snap
fi
PACKAGECLOUD_REPO_URL="https://packagecloud.io/install/repositories/AppOptics/${PACKAGECLOUD_REPO}/config_file"
SNAP_TMP_DIR=/tmp/appoptics-snaptel

# Settings for the user used to run the daemon
APPOPTICS_USERNAME=appoptics
APPOPTICS_GROUPNAME=appoptics

SYSTEMCTL_BIN=`command -v systemctl 2>/dev/null`
CHKCONFIG_BIN=`command -v chkconfig 2>/dev/null`
SERVICE_BIN=`command -v service 2>/dev/null`
CURL_BIN=`command -v curl 2>/dev/null`
GROUPADD_BIN=`command -v groupadd 2>/dev/null`
PGREP_BIN=`command -v pgrep 2>/dev/null`

# Return error codes
readonly SUCCESS=0
readonly FAILURE=1
readonly FAILURE_SERVICE_NOT_RUNNING=2
readonly FAILURE_NOT_ENOUGH_RIGHTS=3
readonly FAILURE_UNABLE_TO_EXTRACT=4
readonly FAILURE_MISSING_EXECUTABLE=5

# truth values
__IS_TRUE=1
__IS_FALSE=0

# When set to true, install the package but don't start the service
APPOPTICS_INSTALL_ONLY=${APPOPTICS_INSTALL_ONLY:-${__IS_FALSE}}

_SD_NO_COLOR=$__IS_FALSE
_CURL_ARGS="-L"

# --------------------------------------------
# -------------- Begin Helper Functions ------
# --------------------------------------------

# Check for "--no-color" flag in opts
printf "%s" "$@" | grep -q -- '--no-color' >/dev/null 2>&1
if [ $? -eq 0 ]; then
    _SD_NO_COLOR=$__IS_TRUE
fi

# Current directory used to run the script
ROOT_DIR=`pwd`

INSTALLER_LOG_FILE="${ROOT_DIR}/appoptics.log"
exec >  >(tee -ia ${INSTALLER_LOG_FILE})
exec 2> >(tee -ia ${INSTALLER_LOG_FILE} >&2)

declare -A ubuntu_codename
ubuntu_codename["12.04"]="precise"
ubuntu_codename["14.04"]="trusty"
ubuntu_codename["15.04"]="vivid"
ubuntu_codename["16.04"]="xenial"
ubuntu_codename["17.04"]="zesty"

declare -A amazon_codename
amazon_codename["2016.03"]="6"
amazon_codename["2016.09"]="6"
amazon_codename["2017.03"]="6"
amazon_codename["2017.09"]="6"

_COLORS=${BS_COLORS:-$(tput colors 2>/dev/null || echo 0)}
__detect_color_support()
{
    if [ $? -eq 0 ] && [ "$_COLORS" -gt 2 ] && [ $_SD_NO_COLOR -eq $__IS_FALSE ]; then
        RC="\033[1;31m"
        GC="\033[1;32m"
        BC="\033[1;34m"
        YC="\033[1;33m"
        EC="\033[0m"
    else
        RC=""
        GC=""
        BC=""
        YC=""
        EC=""
    fi
}
__detect_color_support

# Override built-in echo for consistency. Has newline at end
echo () (
fmt=%s end=\\n IFS=" "

while [ $# -gt 1 ] ; do
    case "$1" in
        [!-]*|-*[!ne]*) break ;;
        *ne*|*en*) fmt=%b end= ;;
        *n*) end= ;;
        *e*) fmt=%b ;;
    esac
    shift
done

printf "$fmt$end" "$*"
)

echored()
{
    printf "${RC}%s${EC}\n" "$*";
}

echogreen()
{
    printf "${GC}%s${EC}\n" "$*";
}

echoblue()
{
    printf "${BC}%s${EC}\n" "$*";
}

echoyellow()
{
    printf "${YC}%s${EC}\n" "$*";
}

exists()
{
  command -v "$1" >/dev/null 2>&1
}

now()
{
  echo $(date +'%Y-%m-%d-%H_%M_%S')
}

echoerror()
{
    printf "${RC} * ERROR${EC}: %s\n" "$*" 1>&2;
}

echoinfo ()
{
    printf "${GC} *  INFO${EC}: %s\n" "$*";
}

echowarn ()
{
  printf "${YC} *  WARN${EC}: %s\n" "$*";
}

# Print debug to STDOUT
echodebug()
{
    if [ "$_ECHO_DEBUG" = "$__IS_TRUE" ]; then
        printf "${BC} * DEBUG${EC}: %s\n" "$*";
    fi
}

display_error_no_token ()
{
  echowarn "Environment variable APPOPTICS_TOKEN has not been set. "
  echowarn "Please use --token option or set APPOPTICS_TOKEN environment variabile."
  exit 1
}

failed ()
{
  error_code=${1}
  echored "###################################################"
  echored "An error occured during the installation of ${AGENT_DISPLAY_NAME}."
  echored "Please contact AppOptics customer service for support at support@appoptics.com."
  echored "###################################################"
}


owner_of_file()
{
    if [ -e $1 ]; then
        ls -ld $1 | awk '{print $3}'
    fi
}

group_of_file()
{
    if [ -e $1 ]; then
        ls -ld $1 | awk '{print $4}'
    fi
}

# Retrieves a URL and writes it to a given path
__fetch_url()
{
    echodebug "Downloading $2 into $1 ..."
    curl $_CURL_ARGS -s -o "$1" "$2" >/dev/null 2>&1 ||
        wget $_WGET_ARGS -q -O "$1" "$2" >/dev/null 2>&1 ||
            fetch $_FETCH_ARGS -q -o "$1" "$2" >/dev/null 2>&1 ||
                fetch -q -o "$1" "$2" >/dev/null 2>&1           # Pre FreeBSD 10

    # Check that file is created and it is not empty
    if [ -s "$1" ] ; then
        echodebug "File $1 downloaded."
    else
        echoerror "Unable to download the $2 into $1."
        exit 1
    fi
}

# Discover hardware information
__gather_hardware_info()
{
    if [ -f /proc/cpuinfo ]; then
        CPU_VENDOR_ID=$(awk '/vendor_id|Processor/ {sub(/-.*$/,"",$3); print $3; exit}' /proc/cpuinfo )
    elif [ -f /usr/bin/kstat ]; then
        # SmartOS.
        # Solaris!?
        # This has only been tested for a GenuineIntel CPU
        CPU_VENDOR_ID=$(/usr/bin/kstat -p cpu_info:0:cpu_info0:vendor_id | awk '{print $2}')
    else
        CPU_VENDOR_ID=$( sysctl -n hw.model )
    fi
    # shellcheck disable=SC2034
    CPU_VENDOR_ID_L=$( echo "$CPU_VENDOR_ID" | tr '[:upper:]' '[:lower:]' )
    CPU_ARCH=$(uname -m 2>/dev/null || uname -p 2>/dev/null || echo "unknown")
    CPU_ARCH_L=$( echo "$CPU_ARCH" | tr '[:upper:]' '[:lower:]' )

}
__gather_hardware_info

# DESCRIPTION:  Discover operating system information
__gather_os_info()
{
    OS_NAME=$(uname -s 2>/dev/null)
    OS_NAME_L=$( echo "$OS_NAME" | tr '[:upper:]' '[:lower:]' )
    OS_VERSION=$(uname -r)
    OS_VERSION_L=$( echo "$OS_VERSION" | tr '[:upper:]' '[:lower:]' )
}
__gather_os_info

#   Parse version strings ignoring the revision.
#   MAJOR.MINOR.REVISION becomes MAJOR.MINOR
__parse_version_string()
{
    VERSION_STRING="$1"
    PARSED_VERSION=$(
        echo "$VERSION_STRING" |
        sed -e 's/^/#/' \
            -e 's/^#[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\)\(\.[0-9][0-9]*\).*$/\1/' \
            -e 's/^#[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/' \
            -e 's/^#[^0-9]*\([0-9][0-9]*\).*$/\1/' \
            -e 's/^#.*$//'
    )
    echo "$PARSED_VERSION"
}

#   Strip single or double quotes from the provided string.
__unquote_string()
{
    echo "${@}" | sed "s/^\([\"']\)\(.*\)\1\$/\2/g"
}

#   Convert CamelCased strings to Camel_Cased
__camelcase_split() {
    echo "${@}" | sed -r 's/([^A-Z-])([A-Z])/\1 \2/g'
}

#   DESCRIPTION:  Strip duplicate strings
__strip_duplicates()
{
    echo "${@}" | tr -s '[:space:]' '\n' | awk '!x[$0]++'
}

__distro_packager_info()
{
    case "${DISTRO_NAME_L}" in
        "ubuntu"|"debian")
            DISTRO_PACKAGE_TYPE="deb"
            DISTRO_PACKAGE_MANAGER="dpkg"
            ;;
        red_hat*|"centos"|"scientific_linux"|"oracle_linux")
            DISTRO_PACKAGE_TYPE="rpm"
            DISTRO_PACKAGE_MANAGER="yum"
            ;;
        "amazon_linux_ami")
            DISTRO_PACKAGE_TYPE="rpm"
            DISTRO_PACKAGE_MANAGER="yum"
            ;;
        "fedora")
            DISTRO_PACKAGE_TYPE="rpm"
            DISTRO_PACKAGE_MANAGER="yum"
            ;;
        *)
            DISTRO_PACKAGE_TYPE=""
            echodebug "Could not determine DISTRO_PACKAGE_MANAGER in function ${0}"
            ;;
    esac
}

__sort_release_files()
{
    KNOWN_RELEASE_FILES=$(echo "(arch|centos|debian|ubuntu|fedora|redhat|suse|\
        mandrake|mandriva|gentoo|slackware|turbolinux|unitedlinux|lsb|system|\
        oracle|os)(-|_)(release|version)" | sed -r 's:[[:space:]]::g')
    primary_release_files=""
    secondary_release_files=""
    # Sort know VS un-known files first
    for release_file in $(echo "${@}" | sed -r 's:[[:space:]]:\n:g' | sort --unique --ignore-case); do
        match=$(echo "$release_file" | egrep -i "${KNOWN_RELEASE_FILES}")
        if [ "${match}" != "" ]; then
            primary_release_files="${primary_release_files} ${release_file}"
        else
            secondary_release_files="${secondary_release_files} ${release_file}"
        fi
    done
    # Now let's sort by know files importance, max important goes last in the max_prio list
    max_prio="redhat-release centos-release oracle-release"
    for entry in $max_prio; do
        if [ "$(echo "${primary_release_files}" | grep "$entry")" != "" ]; then
            primary_release_files=$(echo "${primary_release_files}" | sed -e "s:\(.*\)\($entry\)\(.*\):\2 \1 \3:g")
        fi
    done
    # Now, least important goes last in the min_prio list
    min_prio="lsb-release"
    for entry in $min_prio; do
        if [ "$(echo "${primary_release_files}" | grep "$entry")" != "" ]; then
            primary_release_files=$(echo "${primary_release_files}" | sed -e "s:\(.*\)\($entry\)\(.*\):\1 \3 \2:g")
        fi
    done
    # Echo the results collapsing multiple white-space into a single white-space
    echo "${primary_release_files} ${secondary_release_files}" | sed -r 's:[[:space:]]+:\n:g'
}

#   DESCRIPTION:  Discover Linux system information
__gather_linux_system_info()
{
    DISTRO_NAME=""
    DISTRO_VERSION=""
    # Let's test if the lsb_release binary is available
    rv=$(lsb_release >/dev/null 2>&1)
    if [ $? -eq 0 ]; then
        DISTRO_NAME=$(lsb_release -si)
        if [ "${DISTRO_NAME}" = "Scientific" ]; then
            DISTRO_NAME="Scientific Linux"
        elif [ "$(echo "$DISTRO_NAME" | grep RedHat)" != "" ]; then
            # Let's convert CamelCase to Camel Case
            DISTRO_NAME=$(__camelcase_split "$DISTRO_NAME")
        elif [ "${DISTRO_NAME}" = "openSUSE project" ]; then
            # lsb_release -si returns "openSUSE project" on openSUSE 12.3
            DISTRO_NAME="opensuse"
        elif [ "${DISTRO_NAME}" = "SUSE LINUX" ]; then
            if [ "$(lsb_release -sd | grep -i opensuse)" != "" ]; then
                # openSUSE 12.2 reports SUSE LINUX on lsb_release -si
                DISTRO_NAME="opensuse"
            else
                # lsb_release -si returns "SUSE LINUX" on SLES 11 SP3
                DISTRO_NAME="suse"
            fi
        elif [ "${DISTRO_NAME}" = "EnterpriseEnterpriseServer" ]; then
            # This the Oracle Linux Enterprise ID before ORACLE LINUX 5 UPDATE 3
            DISTRO_NAME="Oracle Linux"
        elif [ "${DISTRO_NAME}" = "OracleServer" ]; then
            # This the Oracle Linux Server 6.5
            DISTRO_NAME="Oracle Linux"
        elif [ "${DISTRO_NAME}" = "AmazonAMI" ]; then
            DISTRO_NAME="Amazon Linux AMI"
        elif [ "${DISTRO_NAME}" = "Arch" ]; then
            DISTRO_NAME="Arch Linux"
            return
        fi
        rv=$(lsb_release -sr)
        [ "${rv}" != "" ] && DISTRO_VERSION=$(__parse_version_string "$rv")
    elif [ -f /etc/lsb-release ]; then
        # We don't have the lsb_release binary, though, we do have the file it parses
        DISTRO_NAME=$(grep DISTRIB_ID /etc/lsb-release | sed -e 's/.*=//')
        rv=$(grep DISTRIB_RELEASE /etc/lsb-release | sed -e 's/.*=//')
        [ "${rv}" != "" ] && DISTRO_VERSION=$(__parse_version_string "$rv")
    fi
    if [ "$DISTRO_NAME" != "" ] && [ "$DISTRO_VERSION" != "" ]; then
        # We already have the distribution name and version
        return
    fi
    for rsource in $(__sort_release_files "$(
            cd /etc && /bin/ls *[_-]release *[_-]version 2>/dev/null | env -i sort | \
            sed -e '/^redhat-release$/d' -e '/^lsb-release$/d'; \
            echo redhat-release lsb-release
            )"); do
        [ -L "/etc/${rsource}" ] && continue        # Don't follow symlinks
        [ ! -f "/etc/${rsource}" ] && continue      # Does not exist
        n=$(echo "${rsource}" | sed -e 's/[_-]release$//' -e 's/[_-]version$//')
        shortname=$(echo "${n}" | tr '[:upper:]' '[:lower:]')
        rv=$( (grep VERSION "/etc/${rsource}"; cat "/etc/${rsource}") | grep '[0-9]' | sed -e 'q' )
        [ "${rv}" = "" ] && [ "$shortname" != "arch" ] && continue  # There's no version information. Continue to next rsource
        v=$(__parse_version_string "$rv")
        case $shortname in
            redhat             )
                if [ "$(egrep 'CentOS' /etc/${rsource})" != "" ]; then
                    n="CentOS"
                elif [ "$(egrep 'Scientific' /etc/${rsource})" != "" ]; then
                    n="Scientific Linux"
                elif [ "$(egrep 'Red Hat Enterprise Linux' /etc/${rsource})" != "" ]; then
                    n="Red Hat Enterprise Linux"
                else
                    n="Red Hat Linux"
                fi
                ;;
            arch               ) n="Arch Linux"     ;;
            centos             ) n="CentOS"         ;;
            debian             ) n="Debian"         ;;
            ubuntu             ) n="Ubuntu"         ;;
            fedora             ) n="Fedora"         ;;
            suse               ) n="SUSE"           ;;
            mandrake*|mandriva ) n="Mandriva"       ;;
            gentoo             ) n="Gentoo"         ;;
            slackware          ) n="Slackware"      ;;
            turbolinux         ) n="TurboLinux"     ;;
            unitedlinux        ) n="UnitedLinux"    ;;
            oracle             ) n="Oracle Linux"   ;;
            system             )
                while read -r line; do
                    [ "${n}x" != "systemx" ] && break
                    case "$line" in
                        *Amazon*Linux*AMI*)
                            n="Amazon Linux AMI"
                            break
                    esac
                done < "/etc/${rsource}"
                ;;
            os                 )
                nn="$(__unquote_string "$(grep '^ID=' /etc/os-release | sed -e 's/^ID=\(.*\)$/\1/g')")"
                rv="$(__unquote_string "$(grep '^VERSION_ID=' /etc/os-release | sed -e 's/^VERSION_ID=\(.*\)$/\1/g')")"
                [ "${rv}" != "" ] && v=$(__parse_version_string "$rv") || v=""
                case $(echo "${nn}" | tr '[:upper:]' '[:lower:]') in
                    amzn        )
                        # Amazon AMI's after 2014.9 match here
                        n="Amazon Linux AMI"
                        ;;
                    arch        )
                        n="Arch Linux"
                        v=""  # Arch Linux does not provide a version.
                        ;;
                    debian      )
                        n="Debian"
                        if [ "${v}" = "" ]; then
                            if [ "$(cat /etc/debian_version)" = "wheezy/sid" ]; then
                                # I've found an EC2 wheezy image which did not tell its version
                                v=$(__parse_version_string "7.0")
                            elif [ "$(cat /etc/debian_version)" = "jessie/sid" ]; then
                                # Let's start detecting the upcoming Debian 8 (Jessie)
                                v=$(__parse_version_string "8.0")
                            fi
                        else
                            echowarn "Unable to parse the Debian Version"
                        fi
                        ;;
                    *           )
                        n=${nn}
                        ;;
                esac
                ;;
            *                  ) n="${n}"           ;
        esac
        DISTRO_NAME=$n
        DISTRO_VERSION=$v
        break
    done
}

__gather_system_info()
{
    case ${OS_NAME_L} in
        linux )
            __gather_linux_system_info
            ;;
        * )
            echoerror "${OS_NAME} not supported.";
            exit 1
            ;;
    esac
}

#   Check for end of life distribution versions
__check_end_of_life_versions()
{
    case "${DISTRO_NAME_L}" in
        debian)
            # Debian versions bellow 6 are not supported
            if [ "$DISTRO_MAJOR_VERSION" -lt 6 ]; then
                echoerror "End of life distributions are not supported."
                echoerror "Please consider upgrading to the next stable. See:"
                echoerror "    https://wiki.debian.org/DebianReleases"
                exit 1
            fi
            ;;
        ubuntu)
            # Ubuntu versions not supported
            #
            #  < 10
            #  = 10.10
            #  = 11.04
            #  = 11.10
            if ([ "$DISTRO_MAJOR_VERSION" -eq 10 ] && [ "$DISTRO_MINOR_VERSION" -eq 10 ]) || \
               ([ "$DISTRO_MAJOR_VERSION" -eq 11 ] && [ "$DISTRO_MINOR_VERSION" -eq 04 ]) || \
               ([ "$DISTRO_MAJOR_VERSION" -eq 11 ] && [ "$DISTRO_MINOR_VERSION" -eq 10 ]) || \
               [ "$DISTRO_MAJOR_VERSION" -lt 10 ]; then
                echoerror "End of life distributions are not supported."
                echoerror "Please consider upgrading to the next stable. See:"
                echoerror "    https://wiki.ubuntu.com/Releases"
                exit 1
            fi
            ;;
        fedora)
            # Fedora lower than 18 are no longer supported
            if [ "$DISTRO_MAJOR_VERSION" -lt 18 ]; then
                echoerror "End of life distributions are not supported."
                echoerror "Please consider upgrading to the next stable. See:"
                echoerror "    https://fedoraproject.org/wiki/Releases"
                exit 1
            fi
            ;;
        centos)
            # CentOS versions lower than 6 are no longer supported
            if [ "$DISTRO_MAJOR_VERSION" -lt 6 ]; then
                echoerror "End of life distributions are not supported."
                echoerror "Please consider upgrading to the next stable. See:"
                echoerror "    http://wiki.centos.org/Download"
                exit 1
            fi
            ;;
        red_hat*linux)
            # Red Hat (Enterprise) Linux versions lower than 5 are no longer supported
            if [ "$DISTRO_MAJOR_VERSION" -lt 5 ]; then
                echoerror "End of life distributions are not supported."
                echoerror "Please consider upgrading to the next stable. See:"
                echoerror "    https://access.redhat.com/support/policy/updates/errata/"
                exit 1
            fi
            ;;
        *)
            ;;
    esac
}

__package_status()
{
    if [ "${1}" = "" ]; then
        echo ""
    else
        case "${DISTRO_PACKAGE_MANAGER}" in
            "dpkg")
                dpkg -s ${1} 2>/dev/null| grep Status | sed 's/^Status: //'
                ;;
            "yum")
                yum list installed ${1} 2>/dev/null | grep "^${1}" | awk '{print $NF}'
                ;;
        esac
    fi
}

__is_package_installed()
{
    __package_state="unknown"
    case "${DISTRO_PACKAGE_MANAGER}" in
        "yum")
            $(__package_status ${1} | grep -q -E "(^installed$|^@)")
            if [ $? -eq 0 ]; then
                __package_state="installed"
            fi
            ;;
        "dpkg")
            $(__package_status ${1} | grep -q " installed$")
            if [ $? -eq 0 ]; then
                __package_state="installed"
            fi
            ;;
    esac
    if [ "$__package_state" = "installed" ]; then
        echo $__IS_TRUE
    else
        echo $__IS_FALSE
    fi
}

__create_temp_directory()
{
    _SD_TMP_DIR=$(mktemp -d -t appoptics.XXXX)
    if [ $? -ne 0 ]; then
        echoerror "Could not create temporary directory"
        exit 1
    fi
    echodebug "Created temp directory: $_SD_TMP_DIR"
}

# --------------------------------------------
# -------------- End Helper Functions --------
# --------------------------------------------

create_daemon_user()
{
    echodebug "Configuring user and group settings ..."

    # Check if the group already exists
    if getent group ${APPOPTICS_GROUPNAME} >/dev/null; then
        echodebug "Group ${APPOPTICS_GROUPNAME} already exists. No need to create it."
    else
       echodebug "Creating ${APPOPTICS_GROUPNAME} system group ..."
       groupadd --system ${APPOPTICS_GROUPNAME}
       RETVAL=$?
       if [ $RETVAL -ne 0 ]; then
           echoerror "Unable to create ${APPOPTICS_GROUPNAME} system group. Error code: ${RETVAL}."
           exit 1
       fi
       echodebug "${APPOPTICS_GROUPNAME} group created."
    fi

    if ! getent passwd ${APPOPTICS_USERNAME} >/dev/null; then
       echodebug "Creating ${APPOPTICS_USERNAME} system user ..."
       useradd --system \
               --gid ${APPOPTICS_GROUPNAME} \
               --no-create-home \
               --home-dir ${INSTALL_DIR} \
               --comment "${AGENT_DISPLAY_NAME} Daemon" \
               --shell /bin/sh \
               ${APPOPTICS_USERNAME}
       RETVAL=$?
       if [ $RETVAL -ne 0 ]; then
          echoerror "Unable to create ${APPOPTICS_USERNAME} system user. Error code: ${RETVAL}."
          exit 1
       fi
       echodebug "${APPOPTICS_USERNAME} system user created."
    else
       echodebug "System user ${APPOPTICS_USERNAME} already exists. No need to create it."
    fi

    echodebug "user and group settings configured."
}

set_daemon_user_rights()
{
    echodebug "Setting user access rights ..."

    ############################
    # General user requirements

    # Changed user to be owner of the installation directory
    chown ${APPOPTICS_USERNAME}:${APPOPTICS_GROUPNAME} -R ${INSTALL_DIR}

    # Changed user to be owner of the temporary directory.
    # Temporary directory is used by daemon to launch executables,
    # logging.
    chown ${APPOPTICS_USERNAME}:${APPOPTICS_GROUPNAME} -R ${SNAP_TMP_DIR}
    chmod 775 -R ${SNAP_TMP_DIR}

    ###########################
    # Docker user requirements

    # Add user to Docker group
    local docker_group_name=docker
    if getent group ${docker_group_name} >/dev/null; then
        echodebug "Found ${docker_group_name} group. Adding ${APPOPTICS_USERNAME} to ${docker_group_name} group ..."
        usermod -aG ${docker_group_name} ${APPOPTICS_USERNAME}
        RETVAL=$?
        if [ $RETVAL -ne 0 ]; then
          echoerror "Unable to add ${APPOPTICS_USERNAME} user to ${docker_group_name} group. Error code: ${RETVAL}."
          exit 1
        else
          echodebug "${APPOPTICS_USERNAME} added to ${docker_group_name} group."
        fi
    else
        echoinfo "Unable to find ${docker_group_name} group. Docker plugin will not work without ${APPOPTICS_USERNAME} user being added to ${docker_group_name} group."
    fi

    echodebug "user access rights configured."
}

detect_operating_system()
{
    echodebug "Detecting operating system ..."
    __gather_system_info
    DISTRO_NAME_L=$(echo "$DISTRO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_ ]//g' | sed -re 's/([[:space:]])+/_/g')
    DISTRO_MAJOR_VERSION=$(echo "$DISTRO_VERSION" | sed 's/^\([0-9]*\).*/\1/g')
    DISTRO_MINOR_VERSION=$(echo "$DISTRO_VERSION" | sed 's/^\([0-9]*\).\([0-9]*\).*/\2/g')
    __distro_packager_info
    __check_end_of_life_versions
}

distro_not_supported()
{
    echodebug "Using DISTRO_NAME_L: ${DISTRO_NAME_L}"
    echoerror "Sorry, we don't currently support ${DISTRO_NAME} ${DISTRO_VERSION}."
    exit 1
}

cpu_arch_not_supported()
{
    echoerror "Sorry, we don't currently support your CPU Architecture, ${CPU_ARCH}."
    exit 1
}

print_system_info()
{
    echodebug "System Information:"
    echodebug "  CPU:          ${CPU_VENDOR_ID}"
    echodebug "  CPU Arch:     ${CPU_ARCH}"
    echodebug "  OS Name:      ${OS_NAME}"
    echodebug "  OS Version:   ${OS_VERSION}"
    echodebug "  Distribution: ${DISTRO_NAME} ${DISTRO_VERSION}"
}

check_distro_supported()
{
    print_system_info
    case ${CPU_ARCH_L} in
        i[3456]86|x86_64)
            ;;
        *)
            cpu_arch_not_supported
            ;;
    esac

    case "${DISTRO_NAME_L}" in
        "ubuntu")
            if [ ${DISTRO_MAJOR_VERSION} -lt 12 ] || [ ${DISTRO_MAJOR_VERSION} -gt 17 ]; then
                distro_not_supported
            fi
            ;;
        "debian")
            if [ ${DISTRO_MAJOR_VERSION} -lt 7 ] || [ ${DISTRO_MAJOR_VERSION} -gt 9 ]; then
                distro_not_supported
            fi
            ;;
        red_hat*|"centos")
            if [ ${DISTRO_MAJOR_VERSION} -lt 6 ]; then
                distro_not_supported
            fi
            ;;
        "amazon_linux_ami")
            if [ ${DISTRO_MAJOR_VERSION} -lt 2016 ] || [ ${DISTRO_MAJOR_VERSION} -gt 2017 ]; then
                distro_not_supported
            fi
            ;;
        *)
            distro_not_supported
            ;;
    esac
}

_contact_us_for_help()
{
    echo -e "Please contact us at ${BC}support@appoptics.com${EC} if you need assistance."
}

display_postinstall_summary()
{
    echo     ""
    echo -e  " ${BC}================== ${GC}Installation Summary ${BC}=======================${EC}"
    echo     ""
    echo -e  "   ${BC}${AGENT_DISPLAY_NAME} is now running as a system service named ${GC}${SNAP_SERVICE_NAME}${EC}"
    echo -e  "   ${BC}The ${AGENT_DISPLAY_NAME} configuration file is ${GC}${APPOPTICS_CONF}${EC}"
    echo -e  "   ${BC}Enable plugins by copying and editing example configurations in ${GC}${INSTALL_DIR}/etc/plugins.d${EC}"
    echo     ""
}

check_install_requirements()
{
    # Verify that APPOPTICS_TOKEN enviroment variable was provided
    case ${APPOPTICS_TOKEN} in
      (*[![:blank:]]*) echodebug "Token set to ${APPOPTICS_TOKEN}";;
      (*) display_error_no_token
    esac

    # Detect operating system
    detect_operating_system

    # Verify that distribution is supported
    check_distro_supported
}

_setup_repository_deb()
{
   local variant=${1}
   echodebug "Updating ${variant} repository information ..."
   apt-get update &> /dev/null

   if [ ! -x "${CURL_BIN}" ] ; then
        echodebug "Installing curl ..."
        apt-get install -q -y curl &> /dev/null
   fi

   if [ ! -x "${PGREP_BIN}" ] ; then
        echodebug "Installing pgrep ..."
        apt-get install -q -y procps &> /dev/null
   fi

   echodebug "Installing debian keyring ..."
   apt-get install -y debian-archive-keyring &> /dev/null

   echodebug "Installing apt-transport-https ..."
   apt-get install -y apt-transport-https &> /dev/null

   if [ "${variant}" = "ubuntu" ]; then
       local distro_codename=${ubuntu_codename[${DISTRO_VERSION}]}
   else
       local distro_codename=${DISTRO_MAJOR_VERSION}
   fi
   local apt_config_url="${PACKAGECLOUD_REPO_URL}.list?os=${DISTRO_NAME_L}&dist=${distro_codename}&source=script"
   local apt_repo_name=appoptics-snaptel
   local apt_source_path="/etc/apt/sources.list.d/${apt_repo_name}.list"

   echodebug "Installing ${apt_source_path}"
   __fetch_url ${apt_source_path} ${apt_config_url}

   echodebug "Importing packagecloud gpg key ..."
   __fetch_url ${ROOT_DIR}/packagecloud.key https://packagecloud.io/AppOptics/${PACKAGECLOUD_REPO}/gpgkey

   echodebug "Installing GnuPG ..."
   apt-get install -y gnupg &> /dev/null

   echodebug "Adding  packagecloud gpg key to keyring ..."
   apt-key add ${ROOT_DIR}/packagecloud.key

   echodebug "Updating repository information ..."
   apt-get update &> /dev/null

   echodebug "The repository is set up! You can now install packages."
}

_setup_repository_redhat()
{
   echodebug "Updating RedHat repository information ..."
   if [ ! -x "${CURL_BIN}" ] ; then
      echodebug "Installing curl ..."
      yum install -d0 -e0 -y curl &> /dev/null
   fi

   if [ ! -x "${PGREP_BIN}" ] ; then
        echodebug "Installing pgrep ..."
        yum install -d0 -e0 -y procps &> /dev/null
   fi

   yum_repo_config_url="${PACKAGECLOUD_REPO_URL}.repo?os=el&dist=${DISTRO_MAJOR_VERSION}&source=script"
   yum_repo_name=AppOptics_${PACKAGECLOUD_REPO}
   yum_repo_path=/etc/yum.repos.d/${yum_repo_name}.repo

  echodebug "Installing ${yum_repo_path} ..."
  __fetch_url ${yum_repo_path} ${yum_repo_config_url}

  echodebug "Installing pygpgme to verify GPG signatures..."
  yum install -y pygpgme --disablerepo="${yum_repo_name}"
  pypgpme_check=`rpm -qa | grep -qw pygpgme`
  if [ "$?" != "0" ]; then
    echowarn "The pygpgme package could not be installed. This means GPG verification is not possible for any RPM installed on your system. "
    echowarn "To fix this, add a repository with pygpgme. Usualy, the EPEL repository for your system will have this. "
    echowarn "More information: https://fedoraproject.org/wiki/EPEL#How_can_I_use_these_extra_packages.3F"

    sed -i'' 's/repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/${yum_repo_name}.repo
  fi

  echodebug "The repository is set up! You can now install packages."
}

_setup_repository_amazon()
{
    echodebug "Updating Amazon Linux repository information ..."
    if [ ! -x "${CURL_BIN}" ] ; then
      echodebug "Installing curl ..."
      yum install -d0 -e0 -y curl &> /dev/null
    fi

    if [ ! -x "${PGREP_BIN}" ] ; then
        echodebug "Installing pgrep ..."
        yum install -d0 -e0 -y procps &> /dev/null
    fi

    # Install groupadd command which is missing on Docker Amazon Linux images like 2016.09, 2017.03
    if [ ! -x "${GROUPADD_BIN}" ] ; then
      echodebug "Installing groupadd command ..."
      yum install -y shadow-utils.x86_64
    fi

    # Amazon Linux packages live inside CentOS 6/7 repositories
    local distro_codename=${amazon_codename[${DISTRO_VERSION}]}
    yum_repo_config_url="${PACKAGECLOUD_REPO_URL}.repo?os=el&dist=${distro_codename}&source=script"
    yum_repo_name=AppOptics_${PACKAGECLOUD_REPO}
    yum_repo_path=/etc/yum.repos.d/${yum_repo_name}.repo

    echodebug "Installing ${yum_repo_path} ..."
    __fetch_url ${yum_repo_path} ${yum_repo_config_url}

    echodebug "Installing pygpgme to verify GPG signatures..."
    yum install -y pygpgme --disablerepo="${yum_repo_name}"
    pypgpme_check=`rpm -qa | grep -qw pygpgme`
    if [ "$?" != "0" ]; then
      echowarn "The pygpgme package could not be installed. This means GPG verification is not possible for any RPM installed on your system. "
      echowarn "To fix this, add a repository with pygpgme. Usualy, the EPEL repository for your system will have this. "
      echowarn "More information: https://fedoraproject.org/wiki/EPEL#How_can_I_use_these_extra_packages.3F"
      sed -i'' 's/repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/${yum_repo_name}.repo
    fi

    echodebug "Installing yum-utils..."
    yum install -y yum-utils --disablerepo="${yum_repo_name}"
    yum_utils_check=`rpm -qa | grep -qw yum-utils`
    if [ "$?" != "0" ]; then
      echowarn "The yum-utils package could not be installed. This means you may not be able to install source RPMs or use other yum features."
    fi

    echodebug "Generating yum cache for ${yum_repo_name}..."
    yum -q makecache -y --disablerepo='*' --enablerepo="${yum_repo_name}"

    yum install -y epel-release &> /dev/null
    yum-config-manager --enable epel &> /dev/null
    echodebug "The repository is set up! You can now install packages."
}

setup_repository()
{
   echodebug "Setting up package repository ..."
   case "${DISTRO_NAME_L}" in
        "ubuntu")
            _setup_repository_deb ubuntu
            ;;
        "debian")
            _setup_repository_deb debian
            ;;
        red_hat*|"centos")
            _setup_repository_redhat
            ;;
        "amazon_linux_ami")
            _setup_repository_amazon
            ;;
        *)
            distro_not_supported
            ;;
    esac
   echodebug "Package repository added."
}

start_service()
{
    local RETVAL=${SUCCESS}
    if [ -x "${SYSTEMCTL_BIN}" ]; then
        if [ "`${SYSTEMCTL_BIN} is-active ${SNAP_SERVICE_NAME}`" = "active" ]; then
            echodebug "${SNAP_SERVICE_NAME} service is already RUNNING. Nothing to do."
        else
            # Start service
            echodebug "Starting ${AGENT_DISPLAY_NAME} service ..."
            ${SYSTEMCTL_BIN} start ${SNAP_SERVICE_NAME}.service
            RETVAL=$?
            if [ ${RETVAL} -eq ${SUCCESS} ]; then
                echodebug "${SNAP_SERVICE_NAME} service has STARTED."
            else
                RETVAL=${FAILURE_SERVICE_NOT_RUNNING}
                echoerror ${RETVAL} "Unable to start ${SNAP_SERVICE_NAME} service. Service is NOT STARTED."
            fi

            echodebug "Waiting for ${SNAP_SERVICE_NAME} service to be fully initialized ..."
            sleep 10

            echodebug "Checking if ${SNAP_SERVICE_NAME} service is running ..."
            if [ "`${SYSTEMCTL_BIN} is-active ${SNAP_SERVICE_NAME}`" = "active" ]; then
                echodebug "${SNAP_SERVICE_NAME} service is RUNNING."
                RETVAL=${SUCCESS}
            else
                RETVAL=${FAILURE_SERVICE_NOT_RUNNING}
                echoerror ${RETVAL} "Unable to start ${SNAP_SERVICE_NAME} service. Service is NOT RUNNING."
            fi
            return $RETVAL
       fi

    else
        # Start service
        if exists ${SERVICE_BIN} ; then
          # Check if the service is running before trying to start.
          if pgrep -x "snapteld" > /dev/null
          then
              echodebug "${SNAP_SERVICE_NAME} service is running."
          else
              echodebug "Starting ${SNAP_SERVICE_NAME} service ..."
              ${SERVICE_BIN} ${SNAP_SERVICE_NAME} start
              RETVAL=$?
              if [ ${RETVAL} -eq ${SUCCESS} ] ; then
                  echodebug "${SNAP_SERVICE_NAME} service is STARTED."
              else
                  RETVAL=${FAILURE_SERVICE_NOT_RUNNING}
                  echoerror ${RETVAL} "Unable to start ${SNAP_SERVICE_NAME} service. Service is NOT RUNNING."
              fi
          fi
      else
              RETVAL=${FAILURE_MISSING_EXECUTABLE}
              echoerror ${RETVAL} "Unable to start ${SNAP_SERVICE_NAME} service. Service ${SERVICE_BIN} command is missing."
        fi

        return $RETVAL
    fi
}

running_in_docker()
{
    grep -q "docker" /proc/self/cgroup
    RETVAL=$?
    if [ $RETVAL -eq 0 ] ; then
        return 1
    fi
    return 0
}

install_service()
{
    echodebug "Installing the ${AGENT_DISPLAY_NAME} package ..."
    export APPOPTICS_TOKEN
    export APPOPTICS_INSTALL_ONLY
    export _ECHO_DEBUG
    export _SD_NO_COLOR
    case "${DISTRO_NAME_L}" in
        "ubuntu")
            apt-get install -y ${PACKAGE_NAME} 2>&1
            ;;
        "debian")
            apt-get install -y ${PACKAGE_NAME} 2>&1
            ;;
        red_hat*|"centos")
            yum -q -y install ${PACKAGE_NAME} 2>&1
            ;;
        "amazon_linux_ami")
            yum -q -y install ${PACKAGE_NAME} 2>&1
            ;;
        *)
            distro_not_supported
            ;;
    esac
    _AGENT_INSTALLED=$(__is_package_installed "${PACKAGE_NAME}")
    if [ "$_AGENT_INSTALLED" != "$__IS_TRUE" ]; then
        echoerror "Failed to install the ${PACKAGE_NAME} package. Check ${INSTALLER_LOG_FILE} for more information."
        exit 1
    fi

    # Post installer script can finish the installation with success even when the service could not be started.
    # Post installer script would just warn the user about the failure to start the service.
    # When service is running inside a Docker container, the policy might prevent starting the service during installation
    # so a start of the service is required after execution of post install script. However at this point, the start
    # must succeed or the installation is considered failed.

    # Check to see if running inside a docker with systemd
    can_start_service=${__IS_TRUE}
    running_in_docker
    RETVAL=$?
    if [ $RETVAL -eq 1 ] ; then
        echodebug "Running inside a Docker container."
        if [ -x "${SYSTEMCTL_BIN}" ]; then
            echodebug "Running as a service inside a docker container using systemd is not supported."
            can_start_service=${__IS_FALSE}
        fi
    fi

    if [ ${can_start_service} -eq ${__IS_TRUE} ] && [ ${APPOPTICS_INSTALL_ONLY} -eq ${__IS_FALSE} ] ; then
        start_service
        RETVAL=$?
        if [ ${RETVAL} -ne ${SUCCESS} ]; then
            echoerror "Failed to install the ${PACKAGE_NAME} package. Unable to start the service. Check ${INSTALLER_LOG_FILE} for more information."
            exit 1
        fi
    fi
}

usage()
{
    cat << EOU

  Usage:  ${0} [script options]

  Script Options:
    -h, --help         Show this help screen
    -t, --token        AppOptics token
    --debug            Show debug output
    --no-color         Disable color output
    --reinstall        Reinstall ${AGENT_DISPLAY_NAME}
    -y, --yes          Assume yes to all questions (non-interactive).

EOU
}

do_agent_reinstall()
{
    echowarn "It looks like ${AGENT_DISPLAY_NAME} is already installed!"
    echowarn "Refer to the documentation for configuring ${AGENT_DISPLAY_NAME}: http://docs.appoptics.com/kb/host_infra/host_agent"
    exit 0
}

do_agent_install()
{
    check_install_requirements
    setup_repository
    create_daemon_user
    install_service
    set_daemon_user_rights
    display_postinstall_summary
}

_ORIG_OPTS=$@
while :; do
    if [ $# -eq 0 ]; then break; fi
    case ${1} in
        -h|--help)
            usage
            exit
            ;;
        -t|--token)
            APPOPTICS_TOKEN=${2}
            shift 2
            continue
            ;;
        -D|--debug)
            _ECHO_DEBUG=${__IS_TRUE}
            ;;
        --no-color)
            # This is already detected at the very beginning of the script,
            # but we have to detect this as a valid script option otherwise
            # it will be caught in the *) case and cause the option loop to exit
            _SD_NO_COLOR=${__IS_TRUE}
            ;;
        --reinstall)
            _SD_REINSTALL=${__IS_TRUE}
            ;;
        -y|--yes)
            _SD_ASSUME_YES=${__IS_TRUE}
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [ "$BASH_VERSION" = "" ]; then
    __bash_path=$(which bash)
    echoerror "This script must run under bash."
    if [ "$__bash_path" != "" ]; then
        echoerror "Try running: $__bash_path $0 $@"
    fi
    exit 1
fi

if [ $? -ne 0 ] && [ "$_SD_ASSUME_YES" = "" ]; then
    echoerror "No tty detected. Specify the -y option to run non-interactively."
    echoerror "Running remotely via SSH? Allocate a pseudo TTY using \"ssh -t ...\""
    usage
    exit 1
fi

if ((${EUID:-0} || "$(id -u)")); then
  echoerror "You need to be root to run this script. Try running: sudo $0 $@"
  exit 1
fi

echoblue ""
echo -e  " ${BC}======================${GC} ${AGENT_DISPLAY_NAME} Installer ${BC}=======================${EC}"
echoblue "  This script will walk you through the installation of ${AGENT_DISPLAY_NAME}."
echoblue ""
echoblue "  For detailed instructions, FAQ, and full documentation:"
echoyellow "   http://docs.appoptics.com"
echoblue ""
echoblue "  If you have any questions or problems, please contact us:"
echoyellow "   email: support@appoptics.com"
echoblue " ==============================================================="
echo     ""

echo -ne "${YC}Are you ready to install ${AGENT_DISPLAY_NAME}? (Y/n)${EC} "
if [ "$_SD_ASSUME_YES" = "" ]; then
    while :; do
        IFS= read -r _GET_INPUT
        case "$_GET_INPUT" in
            "Y"|"y"|"")
                break
                ;;
            "N"|"n")
                echoyellow "Ok, not installing."
                echoyellow ""
                exit 1
                ;;
        esac
    done
else # unattended install, assume we want to install
    echo "y"
fi
echo ""

echo -e  " ${BC}======================${GC} ${AGENT_DISPLAY_NAME} Install ${BC}=======================${EC}"
echoinfo " Installing the AppOptics Host Agent package ..."

_AGENT_INSTALLED=$(__is_package_installed "appoptics-snaptel")
if [ $_AGENT_INSTALLED -eq $__IS_TRUE ]; then
    do_agent_reinstall
else
    do_agent_install
fi
