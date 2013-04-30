#!/bin/bash


# Read config file. Needs the "$config_file" variable and takes
# one or more dot separated paths to config file variables.
# 
# If a variable path points to a section, the lines from that
# section are returned. If it points to a config variable, it is
# returned.
# 
# Examples:
#   config_file="backup.cfg"
#   config include
#   config target.host
# 
function config
{
  perl -le '
    # Read config file, discard comment lines.
    $config = do { open F, $ARGV[0]; join "", grep { !/^;/ } <F> };
    shift @ARGV;

    # Parse config sections.
    while ($config =~ /^<(.*?)>\n(.*?)\n<\/\1>/msg)
    {
      ($tag, $content) = ($1, $2);
      
      # Save numbered lines from section.
      $sections{$tag} = { map { $count{$tag}++ => $_ } split /\n/, $content };
      
      # Save named variables from section.
      $sections{$tag}{$1} = $2 while $content =~ /^(.*?) *= *(.*)/mg;
    }
    
    for $arg (@ARGV)
    {
      # Save a reference to the sections hash.
      $v = \%sections;
      
      # Dig deeper for each dot in the argument.
      for (split /\./, $arg)
      {
        $v = $v->{$_};
      }
      
      if (ref($v) eq "HASH")
      {
        # A hash was found, print the numbered section lines.
        print for map { $v->{$_} } grep { /^\d+$/ } sort { $a <=> $b } keys %{$v};
      }
      else
      {
        # A scalar was found, print it.
        print $v;
      }
    }' "$config_file" "$@"
}

function exclude
{
  local pattern=$(config exclude | perl -lne 'chomp(@lines = <>); print join "|", @lines')

  perl -lne '
    BEGIN
    {
      $exclude = '"'$pattern'"';
      $regex = qr/$exclude/;
    }
    print unless /$regex/'
}

function metadata
{
  perl -MDigest::MD5 -lne '
    ($size, $mtime) = (stat)[7,9];
    $md5 = do { open F, $_; Digest::MD5->new->addfile(F)->hexdigest };
    print $md5, " ", $mtime, " ", $size, " ", $_'
}

function usage
{
  cat <<EOF
Usage:
  $(basename "$0") CONFIGFILE
EOF
}

[ $# == 1 ] || { usage; exit 1; }

config_file=$1

metadata=$(date +%F_%H%M%S.metadata)
last_metadata=$(ls *.metadata 2>/dev/null | tail -n1)

config include | while read dir
do
  find "$dir" -type f
done | exclude | sort | metadata > "$metadata"

if [ -n "$last_metadata" ]
then
  diff "$metadata" "$last_metadata" > "$last_metadata".diff && \
    rm "$last_metadata"
fi

echo Would send result to $(config target.host target.path), using $(config target.protocol)
