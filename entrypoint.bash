#!/bin/bash

# #check if /appdata/space-engineers/config/World is a folder
if [ ! -d "/appdata/space-engineers/World" ]; then
  echo "World folder does not exist, exiting"
  exit 129
fi

# #check if /appdata/space-engineers/config/World/Sandbox.sbc exists and is a file
# if [ ! -f "/appdata/space-engineers/World/World/Sandbox.sbc" ]; then
#   echo "Sandbox.sbc file does not exist, exiting."
#   exit 130
# fi

# #check if /appdata/space-engineers/config/SpaceEngineers-Dedicated.cfg is a file
if [ ! -f "/appdata/space-engineers/SpaceEngineers-Dedicated.cfg" ]; then
  echo "SpaceEngineers-Dedicated.cfg file does not exist, exiting."
  exit 131
else
  sed -i '/LoadWorld/c\<LoadWorld>Z:\\appdata\\space-engineers\\World</LoadWorld>' /appdata/space-engineers/SpaceEngineers-Dedicated.cfg
  rm -rf /appdata/space-engineers/SpaceEngineersDedicated/SpaceEngineers-Dedicated.cfg
  cp /appdata/space-engineers/SpaceEngineers-Dedicated.cfg /appdata/space-engineers/SpaceEngineersDedicated/SpaceEngineers-Dedicated.cfg
  cat /appdata/space-engineers/SpaceEngineers-Dedicated.cfg
fi

tree /appdata/space-engineers/Plugins
tree /appdata/space-engineers/World

chown -R 1000:1000 /appdata

#update the se server
runuser -l wine bash -c 'steamcmd +force_install_dir /appdata/space-engineers/SpaceEngineersDedicated +login anonymous +@sSteamCmdForcePlatformType windows +app_update 298740 +quit'

#get the mod definition lines from the config
mod_list=$(cat /appdata/space-engineers/World/World/Sandbox_config.sbc | grep PublishedFileId | grep -oE '>.*<' | tr -d '<' | tr -d '>' | tr '\n' ' ')
echo "Parsed mods: $mod_list"

#assemble mod download string
mod_download_string=""
for mod_id in $mod_list; do
  mod_download_string="$mod_download_string+workshop_download_item 244850 $mod_id "
done
#download mods
runuser -l wine bash -c 'steamcmd +force_install_dir /appdata/space-engineers/SpaceEngineersDedicated/steamcmd-mods +login anonymous '"$mod_download_string"' +quit'
#clear out old mods
rm -rf /appdata/space-engineers/SpaceEngineersDedicated/Content/244850/*
#copy from downloaded location to content folder
cp -r /appdata/space-engineers/SpaceEngineersDedicated/steamcmd-mods/steamapps/workshop/content/244850/* /appdata/space-engineers/SpaceEngineersDedicated/Content/244850/

countersum=0; for i in {1..18}; do countersum=$((countersum + i)); done; echo $countersum
date=$(date +%s)
#assemble appworkshop file
#header
appworkshop_contents=$(cat <<EOF
"AppWorkshop"
{
  "AppID"        "244850"
  "SizeOnDisk"        "$countersum"
  "NeedsUpdate"        "0"
  "NeedsDownload"        "0"
  "TimeLastUpdated"        "$date"
  "TimeLastAppRan"        "$date"
  "WorkshopItemsInstalled"
  {
EOF
)
counter=0
#WorkshopItemsInstalled section
for mod_id in $mod_list; do
  ((counter++))
  appworkshop_contents=$(cat <<EOF
$appworkshop_contents
    "$mod_id"
    {
      "size"        "$counter"
      "timeupdated"        "$date"
      "manifest"        "$counter"
    }
EOF
)
done

#middle section
appworkshop_contents=$(cat <<EOF
$appworkshop_contents
  }
  "WorkshopItemDetails"
  {
EOF
)

#WorkshopItemDetails section
counter=0
for mod_id in $mod_list; do
  ((counter++))
  appworkshop_contents=$(cat <<EOF
$appworkshop_contents
    "$mod_id"
    {
      "manifest"        "$counter"
      "timeupdated"        "$date"
      "timetouched"        "$date"
    }
EOF
)
done

#footer section
appworkshop_contents=$(cat <<EOF
$appworkshop_contents
  }
}
EOF
)

#write to file
echo "$appworkshop_contents" > /appdata/space-engineers/SpaceEngineersDedicated/appworkshop_244850.acf

runuser -l wine bash -c '/entrypoint-space_engineers.bash'
