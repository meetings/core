<?php

if(count($_SERVER['argv']) < 2){
    print "Usage: configure [command]\n";
    exit(1);
}
$command = $_SERVER['argv'][1];

switch ($command)
{
        case "install":
                execute( $command );
                break;
        case "remove":
                execute( $command );
                break;
        case "configure":
                execute( $command );
                break;
        case "enable":
                execute( $command );
                break;
        case "disable":
                execute( $command );
                break;
        case "upgrade":
                execute( $command );
                break;
        default:
                echo "Unknown function '$command'\n";
        exit(1);
}


exit(0);



function execute( $command ) {
        $provider_domain_url = getenv('SETTINGS_meetings_provider_domain_url');
        $provider_key = getenv('SETTINGS_meetings_provider_key');
        $user_email = getenv('SETTINGS_user_email');
        $user_language = getenv('SETTINGS_user_language');
        $sub_id = getenv('SETTINGS_context_subscription_id');
        $org = getenv('SETTINGS_context_organization_name');
        $sub_user_id = getenv('SETTINGS_subscription_user_id');
        $fn = getenv('SETTINGS_user_given_name');
        $ln = getenv('SETTINGS_user_surname');

        $provision_url = $provider_domain_url . "meetings_aps/configure_user/";
        $provision_url = $provision_url . "?email=" . urlencode($user_email) . '&provider_key=' . urlencode( $provider_key ) . '&command=' . urlencode( $command ) . '&sub_user_id=' . urlencode( $sub_user_id ) . '&sub_id=' . urlencode( $sub_id ) . '&user_first_name=' . urlencode( $fn ) . '&user_last_name=' . urlencode( $ln ) . '&user_language=' . urlencode( $user_language ) . '&organization_name=' . urlencode( $org );

        $json = file_get_contents( $provision_url );
        $data = json_decode( $json, true );

        if ( $data['result'] ) {
            echo $data['result'];
        }
        else {
            echo "Could not parse result from provider domain";
            exit(1);
        }
}

?>
