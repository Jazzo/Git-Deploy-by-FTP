#!/bin/sh

# Include the config file
source deploy-production-config.sh

#### FUNCTIONS ####
function usage {
	echo "usage: system_page [[[-f file ] [-i]] | [-h]]"
}
#### FUNCTIONS ####


######### Start script ########
echo "\033[34mProduction deployment script (ver. 0.2)"

# Check parameters and Set defaults
if [ "$1" == "" ]; then
    usage
	exit 1
fi

SIMULATION=0
while [ "$1" != "" ]; do
    case $1 in
        -d | --deploy )
							shift
							DEPLOY_SELECTED=$1
							;;
        --not-simulate )
							SIMULATION=1
							;;
        -h | --help )
							usage
							exit;;
        * )
							usage
							exit 1
    esac
    shift
done

# Check if Deploy commit EXISTS
cd $PROJECT_REPO_DIR
C_DEPLOY=`git rev-list $DEPLOY_SELECTED | head -n 1`
if [[ -z "$C_DEPLOY" ]]
then
	echo "\033[31mThe commit '$DEPLOY_SELECTED' does NOT EXISTS in the repo: \n$PROJECT_REPO_DIR!"
	exit 0
else
	echo "\033[35mCommit to deploy: $C_DEPLOY"
fi

# Check production tag
echo "Check for '$PRODUCTION_TAG_NAME' tag..."
C_PRODUCTION=`git rev-list $PRODUCTION_TAG_NAME | head -n 1`
if [[ -z "$C_PRODUCTION" ]]
then
	echo "\033[31mThe tag 'production' does NOT EXISTS in the repo: \n$PROJECT_REPO_DIR!"
	exit 0
else
	echo "\033[35mProduction environment is on commit: $C_PRODUCTION"
fi

# Simulation alert
if [ "$SIMULATION" == 0 ]
then
	echo "\033[34m** SIMULATION MODE ENABLED **"
fi

echo "\033[35mClean Exported directory...\033[32m"
rm -fR $EXPORTED_DIR

echo "\033[35mClone Git Repository...\033[32m"
#git clone --recursive file://$PROJECT_REPO_DIR$PROJECT_NAME $REPO_CLONED_DIR
git clone file://$PROJECT_REPO_DIR $REPO_CLONED_DIR
cd $REPO_CLONED_DIR

echo "\033[35mGet diff between commits: $C_PRODUCTION - $C_DEPLOY \033[32m"
git diff --name-status $C_PRODUCTION $C_DEPLOY > $EXPORTED_DIR$FILENAME_DIFF

echo "\033[35mChecking out $C_DEPLOY ...\033[32m"
git checkout $C_DEPLOY

echo "\033[35mStart to read the diff files...\033[32m"
# Start to Deploy Production environment
COUNTER=0
while read row; do
	COUNTER=$[COUNTER + 1]
	read -r f_status f_path <<< "$row"
	echo "$COUNTER - \c" # write the Row line
	# Check if it Is a file
	case $f_status in

		# STATUS: M (Modified), A (Added)
		[AM] )
			echo "Upload... ($f_status): $f_path";
			if [ "$SIMULATION" == 1 ]
			then
				curl -u $FTP_USERNAME:$FTP_PASSWORD --ftp-create-dirs --silent --show-error -T $f_path ftp://$FTP_SERVER$FTP_PATH$f_path
			fi
			continue;;

		# STATUS: D (Deleted)
		D )
			# Check if it Is a file
			echo "DELETE... ($f_status): Trying to delete $f_path: \c"
			if curl -u $FTP_USERNAME:$FTP_PASSWORD --output /dev/null --silent --head --fail ftp://$FTP_SERVER$FTP_PATH$f_path; then
				if [ "$SIMULATION" == 1 ]
				then
					curl -u $FTP_USERNAME:$FTP_PASSWORD --output /dev/null --silent --show-error --quote 'DELE $FTP_PATH$f_path' ftp://$FTP_SERVER
				fi
				echo "DELETED!";
			else
				echo "it does NOT exists!"
			fi
			continue;;

		# UNKNOWN STATUS! (TO DO...)
		* )
			echo "WARNING: I don't know this status: $f_status";
			break;;
	esac

done < $EXPORTED_DIR$FILENAME_DIFF

echo "\033[34mThe commit $C_DEPLOY is in PRODUCTION!"
if [ "$SIMULATION" == 0 ]
then
	echo "\033[34m** SIMULATION MODE ENABLED **"
else
	cd $PROJECT_REPO_DIR
	git tag -f production $C_DEPLOY
	echo "\033[34mMoved production tag to the commit '$C_DEPLOY'"
fi
echo "Success!\033[32m"
