#!/bin/sh

# Include the config file
source deploy-production-config.sh

# Start script!
echo "\033[34mProduction deployment script (ver. 0.1)"

if [ "$1" != "--deploy" ]
then
	echo "** SIMULATION MODE ENABLED **"
fi

echo "\033[35mClean directory in Exported...\033[32m"
rm -fR $EXPORTED_DIR
echo "\033[35mClone Git Repository...\033[32m"
#git clone --recursive file://$PROJECT_REPO_DIR$PROJECT_NAME $REPO_CLONED_DIR
git clone file://$PROJECT_REPO_DIR $REPO_CLONED_DIR
cd $REPO_CLONED_DIR

# Ask for commit...
echo "\033[35mProduction environment is on commit: \c"
C_PRODUCTION=`git rev-list production | head -n 1`
echo $C_PRODUCTION
if [[ -z "$C_DEPLOY" ]]
then
	echo "\033[33m\c"
	read -p "What commit do you want to deploy in Production? " C_DEPLOY
fi
echo "\033[35mDeploy: $C_DEPLOY"

echo "\033[35mGet diff between commits: $C_PRODUCTION - $C_DEPLOY \033[32m"
git diff --name-status $C_PRODUCTION $C_DEPLOY > $EXPORTED_DIR$FILENAME_DIFF
# CHECK if DEPLOY hash commit EXISTS!
if [ "$?" -ne 0 ]
then
	echo "\033[31mThe commit ($C_DEPLOY) NOT EXISTS!"
	echo "\033[32m"
	exit
fi

echo "\033[35mChecking out $C_DEPLOY ...\033[32m"
git checkout $C_DEPLOY

echo "\033[35mStart to read the diff files...\033[32m"
cd $REPO_CLONED_DIR

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
			if [ "$1" == "--deploy" ]
			then
				curl -u $FTP_USERNAME:$FTP_PASSWORD --ftp-create-dirs --silent --show-error -T $f_path ftp://$FTP_SERVER$FTP_PATH$f_path
			fi
			continue;;

		# STATUS: D (Deleted)
		D )
			# Check if it Is a file
			echo "DELETE... ($f_status): Trying to delete $f_path: \c"
			if curl -u $FTP_USERNAME:$FTP_PASSWORD --output /dev/null --silent --head --fail ftp://$FTP_SERVER$FTP_PATH$f_path; then
				if [ "$1" == "--deploy" ]
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
if [ "$1" != "--deploy" ]
then
	echo "** SIMULATION MODE ENABLED **"
else
	cd $PROJECT_REPO_DIR
	git tag -f production $C_DEPLOY
fi
echo "\033[32m"
