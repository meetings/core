#!/usr/bin/perl

my $processes = `ps axu`;
my @results = $processes =~ m!(perl\s+\S*run_nonparallel_processes)!g;
exit 0 if @results > 1;

my $domain_id = $ARGV[0];
die unless $domain_id =~ /^\d+$/;

my $swd = `/usr/local/bin/d swd`;
chomp $swd;
my $iwd = `/usr/local/bin/d iwd`;
chomp $iwd;

for my $script (
    '/pkg/dicole_meetings/script/send_pending_emails.script',
    '/pkg/dicole_meetings/script/check_pending_dropbox_syncs.script',
    '/pkg/dicole_meetings/script/move_mailgun_mails_to_folders.script',
) {
    system( '/usr/local/bin/oi2_manage', dicole_script => '--website_dir='.$iwd => '--script='.$swd.$script, => '--parameters='.$domain_id );
}

