#!/bin/bash

# Read pipelines env variables
source "${BASH_SOURCE%/*}/variables.sh"

# Print helper
function print_section() {
    # Center the msg
    fmt_str="##########################################################"
    fmt_len=${#fmt_str}
    msg_len=${#1}
    pad=$(((fmt_len-msg_len)/2))
    lead=$((msg_len+pad))
    echo ""
    echo ""
    echo ""
    echo "##########################################################"
    echo "#--------------------------------------------------------#"
    printf "%${lead}s \n" "$1"
    echo "#--------------------------------------------------------#"
    echo "##########################################################"
    echo ""
    echo ""
}


function free_space_packages() {

    print_section "Removing unused packages"
    ###
    ###  Since we'll be upgrading later, we need to remove anything we dont want so we dont upgrade it either
    ###

    UNUSED_PACKAGES="google-chrome-stable \
         ansible \
         bazel \
         firefox \
         google-cloud-sdk \
         heroku \
         hhvm \
         podman \
         snapd \
         '?name(adoptopenjdk.*)' \
         '?name(azure-cli.*)' \
         '?name(buildah.*)' \
         '?name(cabal.*)' \
         '?name(clang-6.*)' \
         '?name(containernetworking-plugins.*)' \
         '?name(cpp-7.*)' \
         '?name(cpp-8.*)' \
         '?name(dotnet-runtime.*)' \
         '?name(dotnet-sdk.*)' \
         '?name(g++-7.*)' \
         '?name(g++-8-.*)' \
         '?name(gcc-7.*)' \
         '?name(gcc-8.*)' \
         '?name(gfortran.*)' \
         '?name(ghc.*)' \
         '?name(initramfs-tools.*)' \
         '?name(libclang-common.*)' \
         '?name(libclang-cpp.*)' \
         '?name(libclang1.*)' \
         '?name(libicu.*)' \
         '?name(libicu66.*)' \
         '?name(libldb.*)' \
         '?name(libllvm10.*)' \
         '?name(libllvm6.*)' \
         '?name(libllvm7.*)' \
         '?name(libllvm8.*)' \
         '?name(libllvm9.*)' \
         '?name(linux-azure-.*)' \
         '?name(linux-cloud.*)' \
         '?name(linux-headers.*)' \
         '?name(linux-image.*)' \
         '?name(linux-modules.*)' \
         '?name(linux-tools.*)' \
         '?name(llvm-10.*)' \
         '?name(llvm-6.*)' \
         '?name(llvm-8.*)' \
         '?name(llvm-9.*)' \
         '?name(mecab-ipadic.*)' \
         '?name(mercurial.*)' \
         '?name(moby.*)' \
         '?name(mongodb.*)' \
         '?name(mono.*)' \
         '?name(mysql.*)' \
         '?name(nginx.*)' \
         '?name(openjdk-11-jre-headless.*)' \
         '?name(postgresql.*)' \
         '?name(ruby2.*)' \
         '?name(skopeo.*)' \
         '?name(vim.*)'"
    sudo DEBIAN_FRONTEND=noninteractive apt purge ${UNUSED_PACKAGES} 2>/dev/null
}

function analyze_storage() {
    print_section "Analyzing Storage"
    sudo DEBIAN_FRONTEND=noninteractive apt -yq install durep wajig >/dev/null
    print_section "Largest packages"
    wajig large
    print_section "Largest files (dh/du)"
    df -h
    du -Sh / 2>/dev/null | sort -rh | head -n 200
    du -akS -d 4  / 2>/dev/null | sort -n -r | head -n 50
    print_section "Largest files durep"
    durep -td 3
}

function setup_yp_deps() {
    print_section "Installing Yocto Project Dependencies"
    ###
    ###  Install YP dependencies
    ###
    sudo DEBIAN_FRONTEND=noninteractive apt update
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade
    # Dependencies from the Yocto Quickstart
    until sudo DEBIAN_FRONTEND=noninteractive apt install gawk wget git-core diffstat unzip texinfo \
               gcc-multilib build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
               xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
               pylint3 xterm python3-subunit mesa-common-dev
    do
      echo "Failed to install dependencies, trying again..."
      sleep 1
    done
}

function check_freespace() {
    print_section "Free Space Available"
    df -h
}

function cleanup_leftover_deps() {
    print_section "Cleanup leftover dependencies"

    sudo DEBIAN_FRONTEND=noninteractive apt autoremove --purge
    sudo DEBIAN_FRONTEND=noninteractive apt autoclean
    sudo DEBIAN_FRONTEND=noninteractive apt clean
}

function purge_space () {

    print_section "Purging container space"
    ###
    ###  Remove files kept to free up even more space
    ###
    #### There are a lot of tools that we dont need inside the container

    export TOFREE=" \
    /home/linuxbrew/.linuxbrew/ \
    /home/vsts/agents/*.tgz \
    /home/vsts/agents/2.150.3/ \
    /home/vsts/agents/2.152.0/ \
    /home/vsts/agents/2.152.1/ \
    /home/vsts/agents/2.160.1/ \
    /home/vsts/agents/2.162.0/ \
    /home/vsts/agents/2.171.1/ \
    /opt/* \
    /usr/lib/cgi-bin \
    /usr/lib/firefox \
    /usr/lib/google-cloud-sdk \
    /usr/lib/heroku \
    /usr/lib/jvm \
    /usr/lib/mono \
    /usr/lib/monodoc \
    /usr/lib/php* \
    /usr/lib32/gconv \
    /usr/libx32/gconv \
    /usr/local/aws-cli/ \
    /usr/local/bin/ \
    /usr/local/doc/ \
    /usr/local/go* \
    /usr/local/julia1.4.2/ \
    /usr/local/lib/android/ \
    /usr/local/lib/node* \
    /usr/local/n/ \
    /usr/local/share/ \
    /usr/share/apache-maven-3.6.2/ \
    /usr/share/az_1* \
    /usr/share/az_2.3* \
    /usr/share/doc/ \
    /usr/share/docs \
    /usr/share/dotnet \
    /usr/share/gradle* \
    /usr/share/icons/ \
    /usr/share/man \
    /usr/share/miniconda/ \
    /usr/share/rust \
    /usr/share/swift/ \
    /usr/share/vim/ \
    /var/cache/apt/ \
    /var/lib/apt/lists \
    "
    # This cant be done in parallel
    for i in ${TOFREE};do sudo rm -rf $i; done;
}

function create_local_dirs() {
    print_section "Creating local directories"
    ###
    ###  Create local directories
    ###
    sudo mkdir ${DL_DIR}
    sudo mkdir ${SSTATE_DIR}
    sudo mkdir ${SSTATE_MIRRORS_DIR}
    sudo mkdir ${DEPLOY_ARTIFACTS_DIR}
    sudo chown vsts:vsts ${SSTATE_DIR}
    sudo chown vsts:vsts ${DL_DIR}
    sudo chown vsts:vsts ${SSTATE_MIRRORS_DIR}
    sudo chown vsts:vsts ${DEPLOY_ARTIFACTS_DIR}
}

function localconf() {

    cd ~/poky
    source oe-init-build-env
    echo "SSTATE_DIR = \"${SSTATE_DIR}\"" >> ./conf/local.conf
    echo "DL_DIR = \"${DL_DIR}\"" >> ./conf/local.conf
    if [ ! -z "${DISTRO}" ]; then
        echo "DISTRO = \"${DISTRO}\"" >> ./conf/local.conf
    fi
    if [ ! -z "${TCLIBC}" ]; then
        echo "TCLIBC = \"${TCLIBC}\"" >> ./conf/local.conf
    fi

    ###
    ###  Sstate and Downloads fetching
    ###
    if [ ! -z "${AZ_SAS}" ]; then
        echo "AZ_SAS = \"${AZ_SAS}\"" >> ./conf/local.conf
        echo "SSTATE_MIRRORS=\" file://.* az://ypcache.blob.core.windows.net/sstate-cache/PATH;downloadfilename=PATH \n\"" >> ./conf/local.conf
        # echo "PREMIRRORS_prepend=\" git://.*/.* az://sstate.blob.core.windows.net/downloads/ \n ftp://.*/.* az://sstate.blob.core.windows.net/downloads/ \n http://.*/.* az://sstate.blob.core.windows.net/downloads/ \n https://.*/.* az://sstate.blob.core.windows.net/downloads/ \n \"" >> ./conf/local.conf

        # Override fetch command to increase timeout
        echo "FETCHCMD_wget=\"/usr/bin/env wget -d --retry-connrefused --waitretry=10 -t 30 -T 60 --passive-ftp\"" >> ./conf/local.conf
    fi

    ###
    ###  Slower builds but more space
    ###
    if [ "${RMWORK}" != "0" ]; then
        echo "INHERIT += \"rm_work\"" >> ./conf/local.conf
    fi
}


function clone_layers() {
    print_section "Cloning Yocto Project"
    if [ "${BRANCH}" == "gatesgarth" ]; then
        BRANCHNAME=${BRANCH}
    elif [ "${BRANCH}" == "dunfell" ]; then
        BRANCHNAME=${BRANCH}
    elif [ "${BRANCH}" == "dunfell-next" ]; then
        BRANCHNAME="dunfell"
    else
        BRANCHNAME="master"
    fi

    print_section "Building Yocto Project branch: ${BRANCHNAME}"

    cd ~
    for layer in "$@"
    do
        echo "Processing ${layer}"
        case ${layer} in
            poky )
                ###
                ###  In case we need local changes
                ###
                git clone git://git.yoctoproject.org/poky -b ${BRANCHNAME}
                cd poky
                # Print out where we were before rebase
                git show
                # Add Az fetcher to Dunfell
                git config --global user.email "you@example.com"
                git config --global user.name "Your Name"
                git remote add gh https://github.com/aehs29/poky.git
                git fetch gh
                git rebase gh/azfetcher-fixes-${BRANCHNAME}
                ;;
            intel )
                git clone https://git.yoctoproject.org/git/meta-intel -b ${BRANCHNAME}
                ;;
            oe )
                git clone git://git.openembedded.org/meta-openembedded -b ${BRANCHNAME}
                ;;
            *)
                echo "Requested layer is not known"
                ;;
        esac
    done
}

function add_layers() {
    print_section "Creating bblayers.conf"
    for layer in "$@"
    do
        echo "Processing ${layer}"
        case ${layer} in
            intel )
                bitbake-layers add-layer ../meta-intel
                ;;
            oe )
                bitbake-layers add-layer ../meta-openembedded/meta-oe
                ;;
            python )
                bitbake-layers add-layer ../meta-openembedded/meta-python
                ;;
            networking )
                bitbake-layers add-layer ../meta-openembedded/meta-networking
                ;;
            skeleton )
                bitbake-layers add-layer ../meta-skeleton
                ;;
            *)
                echo "Requested layer is not known"
                ;;
        esac
    done
    if [ ! -z "${SELF}" ]; then
        bitbake-layers add-layer ${SELF}
    fi
    cat conf/bblayers.conf
}

function sync_sstate() {

    print_section "Shared State Sync"

    export AZCOPY_VERSION="10"
    wget -O azcopy_v$AZCOPY_VERSION.tar.gz https://aka.ms/downloadazcopy-v$AZCOPY_VERSION-linux && tar -xf azcopy_v$AZCOPY_VERSION.tar.gz  --strip-components=1

    if [ -z "${SASW_TOKEN}" ]; then
        echo "No Shared Access Token provided"
        echo "##vso[task.logissue type=error;]No Shared Access Token provided"
        exit 0
    fi
    retries=0
    until [ "$retries" -ge 3 ]
    do
        ./azcopy sync ${SSTATE_DIR} --recursive "https://ypcache.blob.core.windows.net/sstate-cache${SASW_TOKEN}"
        ECODE=$?
        if [ $ECODE -eq 0 ]; then
            break
        fi
        retries=$((retries+1))
        echo "Uploading sstate artifacts failed (try #$retries), retrying ..."
        sleep 10
    done
    if [ $ECODE -ne 0 ]; then
        echo "Couldn't upload build cache, error: $ECODE"
        exit $ECODE
    fi
}
