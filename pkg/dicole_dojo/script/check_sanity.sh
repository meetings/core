#find build/dicole/ -type f|xargs cat|perl -0 -n -e '($a) = $_ =~ /(.{0,100}\,\s*[\}\]])/s; die $a if $a'
#find build/dicole/ -type f|xargs cat|perl -0 -n -e '($a) = $_ =~ /(.{0,100}[\{| ](class|package|item|long|public|default)\s+\:)/s; die $a if $a'
