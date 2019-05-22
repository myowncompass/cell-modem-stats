#!/bin/bash
#
# This script helps assess wireless values for Sierra Wireless cell modems.
# It finds the IP of the current gateway, uses SNMP to collect the values,
# and then compares those values with accpted ranges. It provides both a 
# quantitative and qualitative assessment of those values.
#
# For a 3G signal, it compares RSSI values. 
# For a 4G signal, it compares RSRP, RSRQ, and SINR.
#
# Ryan Turner, UNAVCO, 2018-10-4
#
####################################

# Welcome
echo "Welcome to the Signal Check script for Sierra Wireless Modems.
Press ^C to exit.

"

# Choose default IP (if directly connected to modem) or 
# enter an IP address manually.
read -r -p "Enter the IP address or press [ENTER] if you are directly connected to the modem.
> " response
    if [ "$response" == "" ]
    then
        # Get default gateway IP address
	GW=`netstat -rn | grep 'default' | grep -v utun | awk '{print $2}'`
	echo "Using this machine's current default gateway, $GW."
    else
	# Use the manually entered IP
	GW=$response
	echo "Using your manually entered address, $GW."
fi

# Confirm the gateway IP address
read -r -p "Is this the correct address? [Y/n]
'No' restarts this script, [ENTER] continues.
> " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
        then
            echo "Using modem IP $GW and collecting SNMP data..."
    elif [[ "$response" = "" ]]
	then
            echo "Using modem IP $GW and collecting SNMP data..."
    else
        ./$(basename $0) && exit
fi

# Use SNMP to determine if the connection is 3G or 4G
BAND=`snmpwalk -v 2c -c public $GW SNMPv2-SMI::enterprises.20542.9.1.1.1.264.0 | grep -o '".*"' | sed 's/"//g'`
echo "It looks like the current connection is using $BAND radio technology."

# Collect the right data, depending on the band.
echo "Collecting appropriate data from the modem..."
if [ "$BAND" == "LTE" ]
  then
	
	# Display the color coded value guide
	echo ""
	echo "            LTE Guide              "
	echo "------------------------------------"
	echo "Metric:     RSRP      RSRQ      SINR"
	echo "Excelent:   $(tput setaf 2)>-90      >-9       >10$(tput setaf 7)"
	echo "Good:       $(tput setaf 3)>-105     >-12      >6$(tput setaf 7)"
	echo "Fair:       $(tput setaf 172)>-120     >-13      >0$(tput setaf 7)"
	echo "Poor:       $(tput setaf 1)<-120     <-13      <0 $(tput setaf 7)"
	echo "------------------------------------"
	echo "Values update every two seconds."
	echo "Press 'q' to quit."

	# Collect RSRP, RSRQ, and SINR from the modem.
	# The 'while' loop continues until the user presses 'q'. 
	# The if loops set the color of the text using 'tput'.
    while true; do
	RSRP=`snmpwalk -v 2c -c public $GW SNMPv2-SMI::enterprises.20542.9.1.1.2.10210.0 | awk '{print $NF}'`
	if [ $RSRP -ge -90 ]
	  then RSRPc="$(tput setaf 2)"
	elif [ $RSRP -ge -105 -a $RSRP -lt -90 ]
	  then RSRPc="$(tput setaf 3)"
	elif [ $RSRP -ge -120 -a $RSRP -lt -105 ]
	  then RSRPc="$(tput setaf 172)"
	elif [ $RSRP -lt -120 ]
	  then RSRPc="$(tput setaf 1)"
	fi

	RSRQ=`snmpwalk -v 2c -c public $GW SNMPv2-SMI::enterprises.20542.9.1.1.2.10209.0 | awk '{print $NF}'`
	if [ $RSRQ -ge -9 ]
	  then RSRQc="$(tput setaf 2)"
	elif [ $RSRQ -ge -12 -a $RSRQ -lt -9 ]
	  then RSRQc="$(tput setaf 3)"
	elif [ $RSRQ -ge -13 -a $RSRQ -lt -12 ]
	  then RSRPc="$(tput setaf 172)"
	elif [ $RSRQ -lt -13 ]
	  then RSRQc="$(tput setaf 1)"
	fi

	SINR=`snmpwalk -v 2c -c public $GW SNMPv2-SMI::enterprises.20542.9.1.1.2.10211.0 | grep -o '".*"' | sed 's/"//g'`
	if (( $(echo "$SINR >= 10" | bc -l) ))
	  then SINRc="$(tput setaf 2)"
	elif (( $(echo "$SINR >= 6" | bc -l) ))
	  then SINRc="$(tput setaf 3)"
	elif (( $(echo "$SINR >= 0" | bc -l) ))
	  then SINRc="$(tput setaf 172)"
	elif (( $(echo "$SINR < 0" | bc -l) ))
	  then SINRc="$(tput setaf 1)"
	fi

	echo -ne "Yours:      $RSRPc$RSRP       $RSRQc$RSRQ       $SINRc$SINR$(tput setaf 7)"\\r
	echo 

	# In the following line -t for timeout, -N for just 1 character
    	read -t 2 -n 1 input
    	if [[ $input = "q" ]] || [[ $input = "Q" ]]; then
	# The following line is for the prompt to appear on a new line.
        	echo
        	break 
    	fi
    done

  elif [ "$BAND" == "EV-DO Rev.A " ] || [ "$BAND" == "EV-DO Rev.A. " ] || [ "$BAND" == "UMTS" ] || [ "$BAND" == "3G" ] || [ "$BAND" == "HSPA " ]
  then
	# Display the 3G signal guide
        echo "     3G Guide    "
	echo "-----------------"
        echo "Metric:     RSSI"
        echo "Excelent:   $(tput setaf 2)>-70$(tput setaf 7)"
        echo "Good:       $(tput setaf 3)>-85$(tput setaf 7)"
        echo "Fair:       $(tput setaf 172)>-120$(tput setaf 7)"
        echo "Poor:       $(tput setaf 1)<-120$(tput setaf 7)"
	echo "-----------------"
	echo "Values update every two seconds."
	echo "Press 'q' to quit."

  while true; do
	# Collect RSSI from the modem. 
	# The 'while' loop continues until the user presses 'q'. 
	# The if loops set the color of the text using 'tput'.
	RSSI=`snmpwalk -v 2c -c public $GW SNMPv2-SMI::enterprises.20542.9.1.1.1.261.0 | awk '{print $NF}'`
        if (( $(echo "$RSSI > -70" | bc -l) ))
          then RSSIc="$(tput setaf 2)"
        elif [ "$RSSI" -gt -85 -a $RSSI -lt -70 ]
          then RSSIc="$(tput setaf 3)"
        elif [ "$RSSI" -gt -120 -a $RSSI -lt -85 ]
          then RSSIc="$(tput setaf 172)"
        elif [ "$RSSI" -lt -120 ]
          then RSSIc="$(tput setaf 1)"
        fi
        echo -ne "Yours:      $RSSIc$RSSI$(tput setaf 7)"\\r
	echo
	# In the following line -t for timeout, -N for just 1 character
        read -t 2 -n 1 input
    	if [[ $input = "q" ]] || [[ $input = "Q" ]]; then
	# The following line is for the prompt to appear on a new line.
          echo
          break
    	fi
  done

  else
	echo "Band type not recognized. This is a script error. Please proceed manually and maybe let the author know."
	exit
fi

