package Dicole::ContentGenerator::TT2Init;

sub custom_template_initialize {
    my ($class, $ttconfig, $init_params) = @_;
    $ttconfig->{RECURSION} = 1;
    return $tt_config;
}

1;
