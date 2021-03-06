#!/bin/bash
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "--usage" ]; then
  echo "usage: $0 <app-metadata from fdroiddata repo> <folder to save all metadata (max. 1GB of space needed!)>"
else
  if [ -f "$1" ] && [ -d "$2" ]; then 
    # APP_NAME1 comes from the F-Droid Metadata THING, after "Auto Name:"
    # APP_NAME2 comes from the F-Droid Metadata THING, after "Name:"
    # APP_NAME3 comes from the AndroidManifest.xml THING, from manifest/application/@android:name="..."
    # SOURCE_URL1 comes from the F-Droid Metadata THING, after "Repo:"
    # SOURCE_URL2 comes from the F-Droid Metadata THING, after "Source Code:"
    SOURCE_URL=; 	SOURCE_URL1=; 	SOURCE_URL2=;
    DEVELOPER=; 	DEVELOPER_URL=; 
    REPO_TYPE=; 	REPO_NAME=; 
    APP_NAME=; 	APP_NAME1=; 	APP_NAME2=; 	APP_NAME3=; 	APP_NAME_SIMPLE=; 
    GIT_URL=; 	SVN_URL=; 	HG_URL=; 
    SUBDIR=; 
    THING=$1; DEST_DIR=$2
    THINGNAME=$(basename $THING); PACKAGE_NAME=; 
    # PART 1: PARSE ALL THE NECESSARY INFORMATION FROM THE METADATA THINGS IN F-DROID
    # ===================================================================================================================================
    SOURCE_URL1=$(grep "^Repo:" $THING | sed 's/Repo\://' | sed 's/\.git$//')
    SOURCE_URL2=$(grep "^Source Code:" $THING | sed 's/Source Code\://')
    SOURCE_URL=; 
    # only take the SOURCE_URL* that is not empty.
    # test if both SOURCE_URLS are empty => ERROR 
    if [ -z "$SOURCE_URL1" ] && [ -z "$SOURCE_URL2" ]; then
      echo "$THINGNAME - ERROR: no SOURCE_URL specified" >&2; exit 1; 
    else
      # test if SOURCE_URL1 is empty => SOURCE_URL=$SOURCE_URL2
      if [ -z "$SOURCE_URL1" ]; then
        SOURCE_URL="$SOURCE_URL2"; 
      fi
      # test if SOURCE_URL2 is empty => SOURCE_URL=$SOURCE_URL1
      if [ -z "$SOURCE_URL2" ]; then
        SOURCE_URL="$SOURCE_URL1"
      fi
      # test if neither SOURCE_URL1 nor SOURCE_URL2 are empty => SOURCE_URL=$SOURCE_URL1
      if [ ! -z "$SOURCE_URL1" ] && [ ! -z "$SOURCE_URL2" ]; then
        SOURCE_URL="$SOURCE_URL1"
      fi
    fi
    # Create the URL to checkout the REPO via git/svn
    REPO_TYPE=$(grep "^Repo Type:" $THING | sed 's/Repo Type\://')
    if [ "$REPO_TYPE"=="git" ]; then
      GIT_URL=$(echo $SOURCE_URL | sed 's/$/.git/'); 
    else
      if [ "$REPO_TYPE"=="svn" ]; then
        SVN_URL="$SOURCE_URL"
      else
        if [ "$REPO_TYPE"=="hg" ]; then
          HG_URL="$SOURCE_URL"
        else
          echo "$THINGNAME - ERROR: unrecognized or unsupported REPO_TYPE called $REPO_TYPE" >&2; exit 1; 
        fi
      fi
    fi
    REPO_NAME=$(basename $SOURCE_URL)
    DEVELOPER_URL=$(echo $SOURCE_URL | sed "s|/$REPO_NAME||")
    DEVELOPER=$(basename $DEVELOPER_URL)
    # Get the app name
    APP_NAME1=$(grep "^Auto Name:" $THING | sed 's/^Auto Name\://' )
    APP_NAME2=$(grep "^Name:"      $THING | sed 's/^Name\://')
    # only take the APP_NAME* that is not empty.
    # test if both SOURCE_URLS are empty => ERROR
    if [ -z "$APP_NAME1" ] && [ -z "$APP_NAME2" ]; then
      echo "$THINGNAME - ERROR: no APP_NAME specified" >&2; exit 1;  
    else
      # test if $APP_NAME1 is empty => $APP_NAME = $APP_NAME2
      if [ -z "$APP_NAME1" ]; then
        APP_NAME="$APP_NAME2"
      fi
      # test if $APP_NAME2 is empty => $APP_NAME = $APP_NAME1
      if [ -z "$APP_NAME2" ]; then
        APP_NAME="$APP_NAME1"
      fi
      # test if both $APP_NAME1 and $APP_NAME2 are empty
      if [ ! -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then
        APP_NAME="$APP_NAME1"
      fi
    fi
    # Give the $APP_NAME a canonical form (without whitespace, without special chars, etc.)
    APP_NAME_SIMPLE=$(echo $APP_NAME | tr '[:upper:]' '[:lower:]' | sed -E "s|^ ||g" | sed -E "s|[\;:,. /+\(\)\!\?\*=\`\´}{'$ -]|_|g" | sed -E 's/[_]{1,3}/_/g' | sed -E "s|[_]{1,5}\$||g" )
    # Search for last occurence of $SUBDIR (that's were I can get all the source): 
    SUBDIR=$(tac $THING | grep -m 1 subdir= | sed 's/  subdir=//g' | tr -d '[:space:]')
    POSSIBLE_SUB_PATH1="$SUBDIR"
    POSSIBLE_SUB_PATH2="$SUBDIR/src/main"
    POSSIBLE_SUB_PATH3="app"
    POSSIBLE_SUB_PATH4="app/src/main"
  # PART 2: CHECKOUT THE SOURCE (IF POSSIBLE, ONLY THE NEEDED THINGS) FROM THE $SOURCE_URL
  # ===================================================================================================================================
    # test, if SOURCE_URL contains github
    SEARCH_GITHUB=$(echo $SOURCE_URL | grep "github")
    SEARCH_GITLAB=$(echo $SOURCE_URL | grep "gitlab")
    SEARCH_BITBUCKET=$(echo $SOURCE_URL | grep "bitbucket")
    SEARCH_SOURCEFORGE=$(echo $SOURCE_URL | grep "sf.net")
    SEARCH_GOOGLECODE=$(echo $SOURCE_URL | grep "google")
    ANDROID_MANIFEST_URL1=; ANDROID_MANIFEST_URL2=; ANDROID_MANIFEST_URL3=; ANDROID_MANIFEST_URL4=; 
    if [ ! -z "$SEARCH_GITHUB" ]; then
      ANDROID_MANIFEST_URL1="https://raw.githubusercontent.com/$DEVELOPER/$REPO_NAME/master/$POSSIBLE_SUB_PATH1/AndroidManifest.xml"
      ANDROID_MANIFEST_URL2="https://raw.githubusercontent.com/$DEVELOPER/$REPO_NAME/master/$POSSIBLE_SUB_PATH2/AndroidManifest.xml";
      ANDROID_MANIFEST_URL3="https://raw.githubusercontent.com/$DEVELOPER/$REPO_NAME/master/$POSSIBLE_SUB_PATH3/AndroidManifest.xml";
      ANDROID_MANIFEST_URL4="https://raw.githubusercontent.com/$DEVELOPER/$REPO_NAME/master/$POSSIBLE_SUB_PATH4/AndroidManifest.xml"; 
    else
      # test, if SOURCE_URL contains gitlab
      if [ ! -z "SEARCH_GITLAB" ]; then
        ANDROID_MANIFEST_URL1="https://gitlab.com/$DEVELOPER/$REPO_NAME/raw/master/$POSSIBLE_SUB_PATH1/AndroidManifest.xml"
        ANDROID_MANIFEST_URL2="https://gitlab.com/$DEVELOPER/$REPO_NAME/raw/master/$POSSIBLE_SUB_PATH2/AndroidManifest.xml"; 
        ANDROID_MANIFEST_URL3="https://gitlab.com/$DEVELOPER/$REPO_NAME/raw/master/$POSSIBLE_SUB_PATH3/AndroidManifest.xml"
        ANDROID_MANIFEST_URL4="https://gitlab.com/$DEVELOPER/$REPO_NAME/raw/master/$POSSIBLE_SUB_PATH4/AndroidManifest.xml"; 
      else
        # test, if SOURCE_URL contains bitbucket
        if [ ! -z "SEARCH_BITBUCKET" ]; then
          ANDROID_MANIFEST_URL1="https://api.bitbucket.org/1.0/repositories/$DEVELOPER/$REPO_NAME/raw/tip/$POSSIBLE_SUB_PATH1/AndroidManifest.xml"
          ANDROID_MANIFEST_URL2="https://api.bitbucket.org/1.0/repositories/$DEVELOPER/$REPO_NAME/raw/tip/$POSSIBLE_SUB_PATH2/AndroidManifest.xml"; 
          ANDROID_MANIFEST_URL3="https://api.bitbucket.org/1.0/repositories/$DEVELOPER/$REPO_NAME/raw/tip/$POSSIBLE_SUB_PATH1/AndroidManifest.xml"; 
          ANDROID_MANIFEST_URL4="https://api.bitbucket.org/1.0/repositories/$DEVELOPER/$REPO_NAME/raw/tip/$POSSIBLE_SUB_PATH1/AndroidManifest.xml"; 
        else
          # test, if SOURCE_URL contains sourceforge
          if [ ! -z "SEARCH_SOURCEFORGE" ]; then
            if [ "$REPO_TYPE"=="svn" ]; then
              echo "ERROR: SOURCEFORGE + Repo Type SVN are not supported yet." >&2; exit 1; 
            fi; 
            if [ "$REPO_TYPE"=="git" ]; then
              echo "ERROR: SOURCEFORGE + Repo Type GIT are not supported yet." >&2; exit 1; 
            fi; 
          else
            if [! -z "SEARCH_GOOGLECODE" ]; then
              echo "ERROR: GOOGLECODE is not supported yet" >&2; exit 1; 
            fi
          fi
        fi
      fi
    fi
    # DOWNLOAD the AndroidManifest.xml THING
    mkdir -p $DEST_DIR/"$APP_NAME_SIMPLE"
    cd $DEST_DIR/"$APP_NAME_SIMPLE"
    if $(wget -q "$ANDROID_MANIFEST_URL1" || \
         wget -q "$ANDROID_MANIFEST_URL2" || \
         wget -q "$ANDROID_MANIFEST_URL3" || \
         wget -q "$ANDROID_MANIFEST_URL4"); then  
      # What I am searching for inside the AndroidManifest: 
      # $PACKAGE_NAME
      # $LAUNCHER_ICON_PATHS 
      # $LAUNCHER_ACTIVITIES
      PACKAGE_NAME=$(xmllint --xpath 2>/dev/null \
        "/manifest/@package" AndroidManifest.xml | sed 's/package=\"//g' | sed 's/\"//g' | tr -d '[:space:]')
      # Parsing the AndroidManifest.xml THING: 
      cat AndroidManifest.xml | sed 's/android://g' > AndroidManifestWithoutAndroidNS.xml 
      LIST_OF_ACTIVITIES=$(xmllint --xpath 2>/dev/null     "//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@name" \
        AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
      LIST_OF_ACTIVITY_ICONS=$(xmllint --xpath 2>/dev/null "//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@icon" \
        AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/icon=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
      APPLICATION_ICON=$(xmllint --xpath  "//application/@icon" \
        AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/icon=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
      APP_NAME3=$(xmllint --xpath "//application/@name" \
        AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
      for ACTIVITY in $LIST_OF_ACTIVITIES
      do
        NEW_ACTIVITY_NAME=$(echo $ACTIVITY | sed "s|^\.|$PACKAGE_NAME\.|g")
        NEW_LIST_OF_ACTIVITIES="$NEW_LIST_OF_ACTIVITIES $NEW_ACTIVITY_NAME"
      done
      for ACTIVITY in $NEW_LIST_OF_ACTIVITIES
      do
        echo "<!-- $APP_NAME - $ACTIVITY -->" >> $DEST_DIR/appfilter.xml
        echo "<item component=\"ComponentInfo{$PACKAGE_NAME/$ACTIVITY}\" drawable=\"$APP_NAME_SIMPLE\" />" >> $DEST_DIR/appfilter.xml
      done
      rm $DEST_DIR/$APP_NAME_SIMPLE/AndroidManifestWithoutAndroidNS.xml
    else
      echo "$THINGNAME - ERROR: could not download AndroidManifest.xml THING" >&2; 
    fi
    echo "APP_NAME_SIMPLE:  $APP_NAME_SIMPLE" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  APP_NAME:         $APP_NAME" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  APP_NAME1:        $APP_NAME1" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  APP_NAME2:        $APP_NAME2"   
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  APP_NAME3:        $APP_NAME3"
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  PACKAGE_NAME:     $PACKAGE_NAME" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  SOURCE_URL:       $SOURCE_URL" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  SOURCE_URL1:      $SOURCE_URL1" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  SOURCE_URL2:      $SOURCE_URL2" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  DEVELOPER_URL:    $DEVELOPER_URL" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  DEVELOPER:        $DEVELOPER" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt 
    echo "  REPO_NAME:        $REPO_NAME" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  SUBDIR:           $SUBDIR" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  ADMANIF_URL1:     $ANDROID_MANIFEST_URL1"
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt 
    echo "  ADMANIF_URL2:     $ANDROID_MANIFEST_URL2"
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  ADMANIF_URL3:     $ANDROID_MANIFEST_URL3"
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt 
    echo "  ADMANIF_URL4:     $ANDROID_MANIFEST_URL4"
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt 
    echo "  ACTIVITIES:       $NEW_LIST_OF_ACTIVITIES" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  ACTIVITY_ICONS:   $LIST_OF_ACTIVITY_ICONS" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
    echo "  APPLICATION_ICON: $APPLICATION_ICON" 
    # >> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
  else
    echo "$THINGNAME - ERROR: FIRST argument has to be a THING, the SECOND one a FOLDER" >&2; exit 1; 
  fi
fi







