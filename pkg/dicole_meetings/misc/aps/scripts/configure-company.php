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
        $sub_id = getenv('SETTINGS_subscription_id');
        $oname = getenv('SETTINGS_organization_name');

        $provision_url = $provider_domain_url . "meetings_aps/configure_company/";
        $provision_url = $provision_url . '?provider_key=' . urlencode( $provider_key ) . '&command=' . urlencode( $command ) . '&sub_id=' . urlencode( $sub_id ) . '&organization_name=' . urlencode( $oname );

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
