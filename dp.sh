#!/bin/sh

#### FUNCTIONS ####
function usage {
	echo "usage: \033[32m dp.sh -p <project-name> -d <commit-sha> [--not-simulate]"
	echo "\t -p, --project \tThe name of the project to deploy (it is the correct configuration file)"
	echo "\t -d, --deploy \tThe commit you want to deploy"
	echo "\t --not-simulate \tDeploy, not simulate!"
}

######### Start script ########
echo $COLOR_ALERT"Production deployment script (ver. 0.2)"

# Check parameters and Set defaults
if [ "$1" == "" ]; then
    usage
	exit 1
fi

SIMULATION=0
while [ "$1" != "" ]; do
    case $1 in
        -p | --project )
							shift
							PROJECT_NAME=$1
							;;
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

# Check if the config file selected EXISTS and include it
if [[ -z "$PROJECT_NAME" ]]
then
	echo $COLOR_ERROR"Please, select a project name to use the correct config file!"
	exit 0
else
	if [ -f .dp-config-$PROJECT_NAME ]
	then
		source .dp-config-$PROJECT_NAME
	else
		echo $COLOR_ERROR"The config file '.dp-config-$PROJECT_NAME' does NOT EXISTS!"
		exit 0
	fi
fi

# Check if Deploy commit EXISTS
cd $PROJECT_REPO_DIR
C_DEPLOY=`git rev-list $DEPLOY_SELECTED | head -n 1`
if [[ -z "$C_DEPLOY" ]]
then
	echo $COLOR_ERROR"The commit '$DEPLOY_SELECTED' does NOT EXISTS in the repo: \n$PROJECT_REPO_DIR!"
	exit 0
else
	echo $COLOR_MSG"Commit to deploy: $C_DEPLOY"
fi

# Check production tag
echo "Check for '$PRODUCTION_TAG_NAME' tag..."
C_PRODUCTION=`git rev-list $PRODUCTION_TAG_NAME | head -n 1`
if [[ -z "$C_PRODUCTION" ]]
then
	echo $COLOR_ERROR"The tag 'production' does NOT EXISTS in the repo: \n$PROJECT_REPO_DIR!"
	exit 0
else
	echo $COLOR_MSG"Production environment is on commit: $C_PRODUCTION"
fi

# Simulation alert
if [ "$SIMULATION" == 0 ]
then
	echo $COLOR_ALERT"** SIMULATION MODE ENABLED **"
fi

echo $COLOR_MSG"Clean Exported directory...\033[32m"
rm -fR $EXPORTED_DIR

echo $COLOR_MSG"Clone Git Repository...\033[32m"
#git clone --recursive file://$PROJECT_REPO_DIR$PROJECT_NAME $REPO_CLONED_DIR
git clone file://$PROJECT_REPO_DIR $REPO_CLONED_DIR
cd $REPO_CLONED_DIR

echo $COLOR_MSG"Get diff between commits: $C_PRODUCTION - $C_DEPLOY \033[32m"
git diff --name-status $C_PRODUCTION $C_DEPLOY > $EXPORTED_DIR$FILENAME_DIFF

echo $COLOR_MSG"Checking out $C_DEPLOY ...\033[32m"
git checkout $C_DEPLOY

echo $COLOR_MSG"Start to read the diff files...\033[32m"
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
			echo $COLOR_ERROR"WARNING: I don't know this status: $f_status";
			break;;
	esac

done < $EXPORTED_DIR$FILENAME_DIFF

echo $COLOR_MSG"The commit $C_DEPLOY is deployed in PRODUCTION environment!"
if [ "$SIMULATION" == 0 ]
then
	echo $COLOR_ALERT"** SIMULATION MODE ENABLED **"
else
	cd $PROJECT_REPO_DIR
	git tag -f production $C_DEPLOY
	echo $COLOR_MSG"Moved production tag to the commit '$C_DEPLOY'"
	echo "Success!"
fi
# Reset sh color
echo "\033[32m"
