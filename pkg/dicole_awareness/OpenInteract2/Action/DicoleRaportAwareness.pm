package OpenInteract2::Action::DicoleRaportAwareness;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Widget::Listing;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Text;
use Dicole::Widget::Horizontal;
use Dicole::Generictool::Data;
use Dicole::Widget::Image;
use Dicole::Widget::Raw;
use URI::Escape;
use Time::Local;
use DateTime;
use Dicole::DateTime;

$OpenInteract2::Action::DicoleRaportAwareness::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);


sub _online_users_logged_actions {
    my ( $self ) = @_;

    my $time = time;
    $time -= CTX->server_config->{dicole}{admin_online_timeout} || 
        CTX->server_config->{dicole}{online_timeout} || 600;

    my $class = CTX->lookup_object('logged_action');

    my $objs = $class->fetch_group( {
            where  => 'time > ?',
            value  => [ $time ],
            order  => 'time DESC',
    }) || [];

    my %check = ();
    my @return = ();

    for my $o ( @$objs ) {
        next if $check{ $o->user_id };
        $check{ $o->user_id }++;
        push @return, $o if ! lc $o->action =~ /logout/;
    }

    return \@return;
}

sub list_users {
    my ( $self ) = @_;

    if( $self->param('target_type') eq 'group' ){
        return $self->_list_users($self->param('target_group_id'));
    }
    else {
        return $self->_list_users(0);
    }
}
# show user based usage 
sub _list_users {
    my ( $self, $group_id ) = @_;
    

    $self->init_tool( { cols => 2, rows => 1, tool_args => { no_tool_tabs => 1 } } );

    my $logins=CTX->request->param('logins_form');
    my $wiki_edits=CTX->request->param('wiki_edits_form');
    my $blogs=CTX->request->param('blogs_form'); 
    my $comments=CTX->request->param('comments_form');

    if(!$logins && !$wiki_edits && !$blogs && !$comments) {
        $logins = $wiki_edits = $blogs = $comments = 'checked';
    }
        # time adjusting
        my $end_year = CTX->request->param('end_date_year');
        my $start_year = CTX->request->param('start_date_year');
        my $end_month = CTX->request->param('end_date_month');
        my $start_month = CTX->request->param('start_date_month');
        my $end_day = CTX->request->param('end_date_day');
        my $start_day = CTX->request->param('start_date_day');
        
        if(!$start_year || !$start_month || !$start_day){
            my $date = DateTime->now->subtract( months=>3 );
            $start_year=$date->year;
            $start_month=$date->month;
            $start_day=1;
        }

        if(!$end_year){
            $end_year=DateTime->now->year;
        }
        if(!$end_month){
            $end_month=DateTime->now->month;
        }
        if(!$end_day){
            $end_day=DateTime->now->day;
        }

        my $dt = DateTime->new( year   => $start_year, 
                            month  => $start_month, 
                            day   => $start_day, 
                            );

        my $epoch_time  = $dt->epoch;

        my $dt2 = DateTime->new(    year   => $end_year, 
                            month  => $end_month, 
                            day    => $end_day, 
                            );
   
        my $epoch_time2  = $dt2->epoch;




    # create address to xml creation
    my $address=();
    if ($group_id==0) {
            $address = Dicole::URL->from_parts(
            action => 'domain_reports_xml',
            task => 'xml_query',
            params => { 
	        start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            }
        );
    }
    else {
            $address = Dicole::URL->from_parts(
            action => 'group_reports_xml',
            task => 'xml_query',
            target => $group_id,
            params => { 
                start_date => $epoch_time,
                end_date => $epoch_time2,	
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            }
        );
    }
    $address = uri_escape($address);
   

    # address to as text
    my $as_text_address=();
    if ($group_id==0) {
            $as_text_address = Dicole::URL->from_parts(
            action => 'domain_reports_xml',
            task => 'get_user_based_as_csv',
            params => { 
	        start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            },
            additional => ['data.txt'],
        );
    }
    else {
            $as_text_address = Dicole::URL->from_parts(
            action => 'group_reports_xml',
            task => 'get_user_based_as_csv',
            target => $group_id,
            params => { 
                start_date => $epoch_time,
                end_date => $epoch_time2,	
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            },
            additional => ['data.txt'],
        );
    }

    my $link_to_csv = Dicole::Widget::Hyperlink->new(link => $as_text_address, content=> 'as text');
    my $csvfile = Dicole::Widget::Vertical->new(
        class => 'get_data_as_csv',
        contents => [$link_to_csv]);

    my $user_count = eval { 
        CTX->lookup_action('statistics')->execute( 'get_user_count', {
        group_id => $self->param('target_group_id'),
        domain_id => CTX->lookup_action('dicole_domains')->get_current_domain->id,
        } ) 
    } || 0;


    my $height=$user_count*17;
    $height=$height+93;


    my $raw_content = Dicole::Widget::Raw->new(
        raw => '
                    <input type="checkbox" name="logins_form" '. ($logins ? 'checked=""' : '').' value="checked"> '.$self->_msg("Activity").'
                    <input type="checkbox" name="wiki_edits_form" '.($wiki_edits ? 'checked=""' : '').' value="checked"> '.$self->_msg("Wiki edits").'
                    <input type="checkbox" name="blogs_form" '.($blogs ? 'checked=""' : '').' value="checked"> '.$self->_msg("Blog posts").'
                    <input type="checkbox" name="comments_form" '.($comments ? 'checked=""' : '').' value="checked"> '.$self->_msg("Comments").'
                     <br />
                    <input type="text" name="start_date_day" size="2" value="'.$start_day.'" >.
                    <input type="text" name="start_date_month" size="2" value="'.$start_month.'" >.
                    <input type="text" name="start_date_year" size="4" value="'.$start_year.'" >
                    -
                    <input type="text" name="end_date_day" SIZE="2" VALUE="'.$end_day.'" >.
                    <input type="text" name="end_date_month" SIZE="2" VALUE="'.$end_month.'" >.
                    <input type="text" name="end_date_year" SIZE="4" VALUE="'.$end_year.'" >
                    <input type="submit" name="choose_time" value="View" class="submitButton" />
                    '. $csvfile->generate_content .'
                    <br />
        <OBJECT classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"
	codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0" 
	WIDTH="500" 
	HEIGHT='.$height.'"
	id="charts" 
	ALIGN="">
        <PARAM NAME=movie VALUE="/images/charts.swf?library_path=/images/charts_library&xml_source='.$address.'">
        <PARAM NAME=quality VALUE=high>
        <PARAM NAME=bgcolor VALUE=#FFFFFF>
        <PARAM NAME=wmode VALUE=transparent>

     <EMBED src="/images/charts.swf?library_path=/images/charts_library&xml_source='.$address.'" 
      quality=high 
       bgcolor=#FFFFFF 
       WIDTH="500" 
        wmode="transparent"
	HEIGHT='.$height.'" 
       NAME="charts" 
       ALIGN="" 
       swLiveConnect="true" 
       TYPE="application/x-shockwave-flash" 
       PLUGINSPAGE="http://www.macromedia.com/go/getflashplayer">
     </EMBED>'
    );

	$self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Report') );
	$self->tool->Container->box_at( 1, 0 )->add_content($raw_content);

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Choose view') );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ $self->tool->get_tablink_widgets ]
        );

    return $self->generate_tool_content;
}

sub list_daily {
    my ( $self ) = @_;

    if( $self->param('target_type') eq 'group' ){
        return $self->_list_daily($self->param('target_group_id'));
    }
    else {
        return $self->_list_daily(0);
    }
}
# usage daily basis
sub _list_daily {
    my ( $self, $group_id ) = @_;

    $self->init_tool( { cols => 2, rows => 1, tool_args => { no_tool_tabs => 1 } } );


        # time adjusting
        my $end_year = CTX->request->param('end_date_year');
        my $start_year = CTX->request->param('start_date_year');
        my $end_month = CTX->request->param('end_date_month');
        my $start_month = CTX->request->param('start_date_month');
        my $end_day = CTX->request->param('end_date_day');
        my $start_day = CTX->request->param('start_date_day');
        
        if(!$start_year || !$start_month || !$start_day){
            my $date = DateTime->now->subtract( days=>60 );
            $start_year=$date->year;
            $start_month=$date->month;
            $start_day=1;
        }

        if(!$end_year){
            $end_year=DateTime->now->year;
        }
        if(!$end_month){
            $end_month=DateTime->now->month;
        }
        if(!$end_day){
            $end_day=DateTime->now->day;
        }

        my $dt = DateTime->new( year   => $start_year, 
                            month  => $start_month, 
                            day   => $start_day, 
                            );

        my $epoch_time  = $dt->epoch;

        my $dt2 = DateTime->new(    year   => $end_year, 
                            month  => $end_month, 
                            day    => $end_day, 
                            );
   
        my $epoch_time2  = $dt2->epoch;


    my $logins=CTX->request->param('logins_form');
    my $wiki_edits=CTX->request->param('wiki_edits_form');
    my $blogs=CTX->request->param('blogs_form'); 
    my $comments=CTX->request->param('comments_form');

    if(!$logins && !$wiki_edits && !$blogs && !$comments) {
        $logins = $wiki_edits = $blogs = $comments = 'checked';
    }
    my $address2=();
    if ($group_id==0) {
           $address2 = Dicole::URL->from_parts(
            action => 'domain_reports_xml',
            task => 'xml_query_date',
            params => {
                start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins,
            }
        );
    }
    else {
            $address2 = Dicole::URL->from_parts(
            action => 'group_reports_xml',
            task => 'xml_query_date',
            target => $group_id,
            params => {
                start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins,
            }
        );
    }
    # my $address2 = "/reports_xml/xml_query_weekly/?start_date=1000000000&end_date=9999999999";
    $address2 = uri_escape($address2);

    # address to as text
    my $as_text_address=();
    if ($group_id==0) {
            $as_text_address = Dicole::URL->from_parts(
            action => 'domain_reports_xml',
            task => 'get_daily_as_csv',
            params => { 
	        start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            },
            additional => ['data.txt'],
        );
    }
    else {
            $as_text_address = Dicole::URL->from_parts(
            action => 'group_reports_xml',
            task => 'get_daily_as_csv',
            target => $group_id,
            params => { 
                start_date => $epoch_time,
                end_date => $epoch_time2,	
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            },
            additional => ['data.txt'],
        );
    }

    my $link_to_csv = Dicole::Widget::Hyperlink->new(link => $as_text_address, content=> 'as text');
    my $csvfile = Dicole::Widget::Vertical->new(
        class => 'get_data_as_csv',
        contents => [$link_to_csv]);



    my $raw_content = Dicole::Widget::Raw->new(
        raw => '
                    <input type="checkbox" name="logins_form" '. ($logins ? 'checked=""' : '').' value="checked"> '.$self->_msg("Activity").'
                    <input type="checkbox" name="wiki_edits_form" '.($wiki_edits ? 'checked=""' : '').' value="checked"> '.$self->_msg("Wiki edits").'
                    <input type="checkbox" name="blogs_form" '.($blogs ? 'checked=""' : '').' value="checked"> '.$self->_msg("Blog posts").'
                    <input type="checkbox" name="comments_form" '.($comments ? 'checked=""' : '').' value="checked"> '.$self->_msg("Comments").'
                    <br />
                    <input type="text" name="start_date_day" size="2" value="'.$start_day.'" >.
                    <input type="text" name="start_date_month" size="2" value="'.$start_month.'" >.
                    <input type="text" name="start_date_year" size="4" value="'.$start_year.'" >
                    -
                    <input type="text" name="end_date_day" SIZE="2" VALUE="'.$end_day.'" >.
                    <input type="text" name="end_date_month" SIZE="2" VALUE="'.$end_month.'" >.
                    <input type="text" name="end_date_year" SIZE="4" VALUE="'.$end_year.'" >
                    
                    <input type="submit" name="choose_time" value="View" class="submitButton" />
                 '. $csvfile->generate_content .'
                    <br/>

        <OBJECT classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"
	codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0" 
	WIDTH="500" 
	HEIGHT="425"
	id="charts" 
	ALIGN="">
        <PARAM NAME=movie VALUE="/images/charts.swf?library_path=/images/charts_library&xml_source='.$address2.'">
        <PARAM NAME=quality VALUE=high>
        <PARAM NAME=bgcolor VALUE=#FFFFFF>
        <PARAM NAME=wmode VALUE=transparent>

    <EMBED src="/images/charts.swf?library_path=/images/charts_library&xml_source='.$address2.'" 
      quality=high 
       bgcolor=#FFFFFF
       wmode="transparent"
       WIDTH="500" 
       HEIGHT="425"  
       NAME="charts" 
       ALIGN="" 
       swLiveConnect="true" 
       TYPE="application/x-shockwave-flash" 
       PLUGINSPAGE="http://www.macromedia.com/go/getflashplayer">
    </EMBED>'
    );


	$self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Daily usage') );
	$self->tool->Container->box_at( 1, 0 )->add_content(
         $raw_content
	);

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Choose view') );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ $self->tool->get_tablink_widgets ]
        );

    return $self->generate_tool_content;
}

sub list_weekly {
    my ( $self ) = @_;

    if( $self->param('target_type') eq 'group' ){
        return $self->_list_weekly($self->param('target_group_id'));
    }
    else {
        return $self->_list_weekly(0);
    }
}
# usage weekly basis
sub _list_weekly {
    my ( $self, $group_id ) = @_;

    $self->init_tool( { cols => 2, rows => 1, tool_args => { no_tool_tabs => 1 } } );
        
    my $end_year = CTX->request->param('end_date_year');
    my $start_year = CTX->request->param('start_date_year');
    my $end_week = CTX->request->param('end_date_week');
    my $start_week = CTX->request->param('start_date_week');
    
    if(!$start_year || !$start_week){
        my $date2 = DateTime->now->subtract( months=>12 );
        $start_year=$date2->year;
        $start_week=$date2->week;
    }

    if(!$end_year || !$end_week){
        $end_year=DateTime->now->year;
        $end_week=DateTime->now->week;
    }


    #starttime    
    my $dt = Dicole::DateTime->start_of_week($start_year, $start_week);
    my $epoch_time  = $dt->epoch;
    #endtime
    my $dt2 = Dicole::DateTime->start_of_week($end_year, $end_week);
    my $epoch_time2  = $dt2->epoch;


    my $logins=CTX->request->param('logins_form');
    my $wiki_edits=CTX->request->param('wiki_edits_form');
    my $blogs=CTX->request->param('blogs_form'); 
    my $comments=CTX->request->param('comments_form');

    if(!$logins && !$wiki_edits && !$blogs && !$comments) {
        $logins = $wiki_edits = $blogs = $comments = 'checked';
    }
    my $address2=();
    if ($group_id==0) {
            $address2 = Dicole::URL->from_parts(
            action => 'domain_reports_xml',
            task => 'xml_query_weekly',
            params => { 	
                start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins,
            }
        );
    }
    else{
            $address2 = Dicole::URL->from_parts(
            action => 'group_reports_xml',
            task => 'xml_query_weekly',
            target => $group_id,
            params => { 	
                start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins,
            }
        );
    }
    # my $address2 = "/reports_xml/xml_query_weekly/?start_date=1000000000&end_date=9999999999";
    $address2 = uri_escape($address2);
    #generating the content

    # address to as text
    my $as_text_address=();
    if ($group_id==0) {
            $as_text_address = Dicole::URL->from_parts(
            action => 'domain_reports_xml',
            task => 'get_weekly_as_csv',
            params => { 
	        start_date => $epoch_time,
                end_date => $epoch_time2,
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            },
            additional => ['data.txt'],
        );
    }
    else {
            $as_text_address = Dicole::URL->from_parts(
            action => 'group_reports_xml',
            task => 'get_weekly_as_csv',
            target => $group_id,
            params => { 
                start_date => $epoch_time,
                end_date => $epoch_time2,	
                wiki_edits_form => $wiki_edits,
                blogs_form => $blogs,
                comments_form => $comments,
                logins_form => $logins
            },
            additional => ['data.txt'],
        );
    }

    my $link_to_csv = Dicole::Widget::Hyperlink->new(link => $as_text_address, content=> 'as text');
    my $csvfile = Dicole::Widget::Vertical->new(
        class => 'get_data_as_csv',
        contents => [$link_to_csv]);



    my $raw_content = Dicole::Widget::Raw->new(
        raw => '
                    <input type="checkbox" name="logins_form" '. ($logins ? 'checked=""' : '').' value="checked"> '.$self->_msg("Activity").'
                    <input type="checkbox" name="wiki_edits_form" '.($wiki_edits ? 'checked=""' : '').' value="checked"> '.$self->_msg("Wiki edits").'
                    <input type="checkbox" name="blogs_form" '.($blogs ? 'checked=""' : '').' value="checked"> '.$self->_msg("Blog posts").'
                    <input type="checkbox" name="comments_form" '.($comments ? 'checked=""' : '').' value="checked"> '.$self->_msg("Comments").'
                    <br />
                    Year: <input type="text" name="start_date_year" size="4" value='.$start_year.' >
                    Week: <input type="text" name="start_date_week" size="2" value="'.$start_week.'" >
                    -
                   Year: <input type="text" name="end_date_year" SIZE="4" VALUE="'.$end_year.'" >
                   Week: <input type="text" name="end_date_week" SIZE="2" VALUE="'.$end_week.'" >
                    
                    <input type="submit" name="choose_time" value="View" class="submitButton" />
                     '. $csvfile->generate_content .'
        <br/>

        <OBJECT classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"
	codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0" 
	WIDTH="500" 
	HEIGHT="425"
	id="charts" 
	ALIGN="">
        <PARAM NAME=movie VALUE="/images/charts.swf?library_path=/images/charts_library&xml_source='.$address2.'">
        <PARAM NAME=quality VALUE=high>
        <PARAM NAME=bgcolor VALUE=#FFFFFF>
        <PARAM NAME=wmode VALUE=transparent>

    <EMBED src="/images/charts.swf?library_path=/images/charts_library&xml_source='.$address2.'" 
      quality=high 
       bgcolor=#FFFFFF
       wmode="transparent"  
       WIDTH="500" 
       HEIGHT="425"  
       NAME="charts" 
       ALIGN="" 
       swLiveConnect="true" 
       TYPE="application/x-shockwave-flash" 
       PLUGINSPAGE="http://www.macromedia.com/go/getflashplayer">
    </EMBED>'
    );

	$self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Weekly Usage') );
	$self->tool->Container->box_at( 1, 0 )->add_content(
            $raw_content
        );

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Choose view') );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ $self->tool->get_tablink_widgets ]
        );

    return $self->generate_tool_content;
}


1;

