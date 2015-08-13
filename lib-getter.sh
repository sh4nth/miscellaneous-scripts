
#   Just export your goodreads data to csv by going to: https://www.goodreads.com/review_porter/goodreads_export.csv
#   Save the csv file and then run this script with:
#   $ bash lib-getter.sh your_csv_filename > output_filename
#   When the script completes you should have a list of all the books on your shelf that are present at the Palo Alto public libraries ( http://www.cityofpaloalto.org/gov/depts/lib/default.asp  ) 
#   As well as the ones that could not be found :(

# Set this to the shelf you want to search for (it's just a basic regex search, and not really optimized for collisions between shelf names and title / author names)
SHELF="to-read"

# For MAC_OS, if you are on Linux then set MD5="md5sum"
MD5="md5" 

IFS=$'\n'

TEMP_FILE_1="/tmp/$(echo "`date` --"| $MD5).tmp"
TEMP_FILE_2="/tmp/$(date | $MD5).tmp"

TOTAL_BOOKS=`grep $SHELF $1 | sed 's/,\"/\|\"/g; s/\"//g; s/  */ /g; s/ /+/g; s/:[A-Za-z0-9+'"'"',-]*|/|/g; s/([A-Za-z 0-9+,#]*)//g; s/+[-+]*/+/g  ' | awk -F '|' '{print $2"+"$3}' | wc -l`
DONE=0

echo -n " [ $DONE / $TOTAL_BOOKS ]" 1>&2 
for string in `grep $SHELF $1 | sed 's/,\"/\|\"/g; s/\"//g; s/  */ /g; s/ /+/g; s/:[A-Za-z0-9+'"'"',-]*|/|/g; s/([A-Za-z 0-9+,#]*)//g; s/+[-+]*/+/g  ' | awk -F '|' '{print $2"+"$3}'`
do
    
    SANITIZED_NAME=$( echo "$string" | sed 's/ /+/g' - )
    echo $SANITIZED_NAME >> $TEMP_FILE_2
    
    curl "http://webcat.cityofpaloalto.org/ipac20/ipac.jsp?index=.GW&term=${SANITIZED_NAME}&go=Search" 2>/dev/null | tr '>' '\n'| grep -A7 -B7 "buildNewList"|grep -A1 mediumBold | sed s/"^.*3Dfull%3D"//g| sed s/"%26ri.*$"//g| sed s/"<\/a"//g| awk '{if(NR%3==1){x=$0} else if (NR%3==2){print x"|"$0}}' > $TEMP_FILE_1

    for line in `cat $TEMP_FILE_1`
    do 
        arr=($(echo $line | tr "|" "\n"))
        URI=${arr[0]}
        NAME=${arr[1]}
        
        curl "http://webcat.cityofpaloalto.org/ipac20/ipac.jsp?uri=full=$URI" 2>/dev/null| tr '>' '\n' | grep -A1 "Item Information\|<.tr" | grep -v "-"| sed s/"<\/a"//g|grep -v "Item Information"|sed s/"^<.*"/"<"/g | awk '{if($0!="<"){x = x"|"$0} else{if(x!=""){print x}; x=""} }' | awk '{print "   >| '"$NAME|$URI"'"$0}' >> $TEMP_FILE_2
        
    done
    DONE=$((DONE+1))
    echo -n $'\r' 1>&2
    echo -n " [ $DONE / $TOTAL_BOOKS ]" 1>&2 

done
FAIL="$TEMP_FILE_1.s.tmp"
OK="$TEMP_FILE_1.f.tmp"
echo " " >>  $TEMP_FILE_2
grep -v "^  [OC]"  $TEMP_FILE_2 |awk -F'|' '{if(NR==1){flag="'$FAIL'"} if(NF>1){x=x"\n"$0; flag="'$OK'"} else{print "echo \""x"\" >> "flag; x=$0; flag="'$FAIL'"}  }' | bash 

echo ">>Found:"
cat $OK
echo " --------------------------- "
echo ">>NoT Found:"
cat $FAIL

rm $FAIL $OK $TEMP_FILE_1 $TEMP_FILE_2


