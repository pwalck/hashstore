#!/bin/bash

function include
{
  perl -le '$config = `cat hashstore.cfg`;
            ($includes) = $config =~ /^<include>\s*(.*?)^<\/include>/ms;
            print for split /\n/, $includes'
}

function exclude
{
  perl -lne 'BEGIN
             {
               $config = `cat hashstore.cfg`;
               ($excludes) = $config =~ /^<exclude>\s*(.*?)^<\/exclude>/ms;
               $exclude = join "|", split /\n/, $excludes;
               $regex = qr/$exclude/;
             }
             print unless /$regex/'
}

function metadata
{
  perl -MDigest::MD5 -lne \
    '($mtime, $size) = (stat)[9,7];
     $md5 = do { open F, $_; Digest::MD5->new->addfile(F)->hexdigest };
     print $md5, " ", $mtime, " ", $size, " ", $_'
}

metadata=$(date +%F_%H%M%S.metadata)
last_metadata=$(ls *.metadata 2>/dev/null | tail -n1)

include | while read dir
do
  find "$dir" -type f
done | exclude | sort | metadata > "$metadata"

if [ -n "$last_metadata" ]
then
  diff "$metadata" "$last_metadata" > "$last_metadata".diff
  rm "$last_metadata"
fi
