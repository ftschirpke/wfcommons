#/usr/bin/env bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

if [ ! -f $1 ]; then
    echo "File $1 does not exist"
    exit 2
fi

dir=$(dirname $1)
file=$(basename $1)
cd $dir

total=$(wc -l $file | awk '{print $1}')
count=0

while read line; do 
    count=$((count+1))
    pair=($line)
    
    filename=${pair[0]}
    filesize=${pair[1]}

    if [ -f $filename ]; then
        existing_filesize=$(stat -c %s $filename)
        if [ $existing_filesize -eq $filesize ]; then
            echo "Skipping file $filename ($count/$total): already exists (size $filesize)"
            continue
        fi
        echo "Overwriting existing $filename ($count/$total): wrong size (is: $existing_filesize, should: $filesize)"
    else 
        echo "Creating file $filename ($count/$total) with size $filesize"
    fi

    head -c $filesize </dev/urandom > $filename

done < $file

