#!/run/current-system/sw/bin/zsh
# reloads wifi module when it is buggy.
nmcli d disconnect lo
echo 'Removing  module'
sudo modprobe -r mt7925e 
sleep 2
echo 'Adding mt7925e module back'
sudo modprobe mt7925e
sleep 3
echo 'Switching wifi off'
nmcli radio wifi off
sleep 5
echo 'Switching wifi on'
nmcli radio wifi on
