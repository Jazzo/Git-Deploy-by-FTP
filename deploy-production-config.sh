#!/bin/sh

# DEBUG MODE
#C_DEPLOY="f98ff26"
# DEBUG MODE

# SETTINGS ------
EXPORTED_DIR="/Users/gullo/Documents/Exported/"
PROJECT_REPO_DIR="/Users/gullo/Documents/htdocs/"
FTP_SERVER="my.ftp.server"
FTP_PATH="/public_html/"
FTP_USERNAME="ftp-username"
FTP_PASSWORD="ftp-password"
# SETTINGS ------

# SET some other useful directories
REPO_CLONED_DIR=$EXPORTED_DIR"source"
FILENAME_DIFF="deploy-"$C_DEPLOY".diff"