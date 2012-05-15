#!/bin/bash

if [ "$DESKTOP_SESSION" = "ubuntu" ]
then

 gxmessage "Are you sure you want to shut down your computer?" -center -title "Take action" -font "Sans bold 10" -default "Cancel" -buttons "_Cancel":1,"L_ock screen":101,"_Log out":102,"_Reboot":103,"_Shut down":104

 case $? in

 1)
  echo "Exit";;
 101)
  gnome-screensaver-command -l;;
 102)
  gnome-session-quit --logout;;
 103)
  echo ON > /sys/kernel/debug/vgaswitcheroo/switch;
  gnome-terminal -e 'sudo shutdown -r now';;
 104)
  echo ON > /sys/kernel/debug/vgaswitcheroo/switch
  gnome-terminal -e 'sudo shutdown -h now';;
 esac

fi
