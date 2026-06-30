###############################################
# Repository
###############################################
if ! command -v extrepo >/dev/null 2>&1; then
    apt update
    apt install -y extrepo
fi

# enable librewolf repo only if package is not available
if ! apt-cache show librewolf >/dev/null 2>&1; then
    extrepo enable librewolf
    apt-get update
fi

###############################################
# Installation
###############################################

if ! dpkg -s librewolf >/dev/null 2>&1; then
    apt-get install -y librewolf
fi